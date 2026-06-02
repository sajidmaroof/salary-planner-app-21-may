import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../../core/auth/app_auth_notifier.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/expense.dart';
import '../../data/models/monthly_report.dart';
import '../../data/models/user_settings.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_service.dart';
import '../../services/pdf_export_service.dart';
import 'widgets/daily_budget_card.dart';

// All categories stored and displayed in lowercase to avoid mismatch
const _kCategories = [
  'food', 'transport', 'shopping', 'entertainment',
  'health', 'bills', 'education', 'other'
];

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  double? _lastViewedSpentToday;
  bool _cycleChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _syncOnLoad();
      if (mounted && !_cycleChecked) {
        _cycleChecked = true;
        await _checkPaydayCycle();
      }
    });
  }

  // ── Payday cycle detection ─────────────────────────────────────────────────
  Future<void> _checkPaydayCycle() async {
    final settings = ref.read(userSettingsProvider);
    if (settings == null || !mounted) return;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    var nextPayStart = DateTime(
        settings.nextSalaryDate.year,
        settings.nextSalaryDate.month,
        settings.nextSalaryDate.day);

    if (todayStart.isBefore(nextPayStart)) return; // Not yet payday

    // Process all missed cycles (e.g. 2+ months without opening app)
    var currentSettings = settings;
    while (!todayStart.isBefore(nextPayStart)) {
      currentSettings = await _processCycleEnd(currentSettings, nextPayStart, todayStart);
      if (!mounted) return;
      nextPayStart = DateTime(
          currentSettings.nextSalaryDate.year,
          currentSettings.nextSalaryDate.month,
          currentSettings.nextSalaryDate.day);
    }
  }

  Future<UserSettings> _processCycleEnd(
      UserSettings settings, DateTime cycleEnd, DateTime today) async {
    final cycleStart = settings.lastSalaryDate ??
        DateTime(cycleEnd.year, cycleEnd.month - 1, cycleEnd.day);

    // Calculate remaining balance for the ending cycle
    final allExpenses = ref.read(expensesProvider);
    final cycleExpenses =
        allExpenses.where((e) => !e.date.isBefore(cycleStart)).toList();
    final totalSpent = cycleExpenses.fold(0.0, (s, e) => s + e.amount);
    final effectiveBudget =
        settings.monthlyIncome + settings.carryForwardAmount;
    final availableSpending =
        effectiveBudget - settings.fixedExpenses - settings.savingsGoal;
    final remainingBalance = availableSpending - totalSpent;

    // Show carry-forward dialog only for the most recent completed cycle
    bool carriedForward = false;
    double carryAmount = 0;
    if (remainingBalance > 0 && mounted) {
      final format = ref.read(formatCurrencyProvider);
      final result = await _showCarryForwardDialog(remainingBalance, format);
      if (result == true) {
        carriedForward = true;
        carryAmount = remainingBalance;
      }
    }

    // Save MonthlyReport to Hive
    final report = MonthlyReport(
      year: cycleStart.year,
      month: cycleStart.month,
      monthlyIncome: settings.monthlyIncome,
      fixedExpenses: settings.fixedExpenses,
      savingsGoal: settings.savingsGoal,
      effectiveBudget: effectiveBudget,
      totalSpent: totalSpent,
      remainingBalance: remainingBalance,
      carriedForward: carriedForward,
      carryForwardAmount: carryAmount,
      currencyCode: settings.currencyCode,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
    );
    await Hive.box<MonthlyReport>('monthly_reports').add(report);
    ref.invalidate(monthlyReportsProvider);

    // Advance nextSalaryDate by 1 month
    final newNextSalary = DateTime(
      settings.nextSalaryDate.year,
      settings.nextSalaryDate.month + 1,
      settings.nextSalaryDate.day,
    );

    final updatedSettings = UserSettings(
      monthlyIncome: settings.monthlyIncome,
      nextSalaryDate: newNextSalary,
      fixedExpenses: settings.fixedExpenses,
      savingsGoal: settings.savingsGoal,
      currencyCode: settings.currencyCode,
      expensesBreakdown: settings.expensesBreakdown,
      lastSalaryDate: cycleEnd,
      carryForwardAmount: carryAmount,
    );

    final box = ref.read(userSettingsBoxProvider);
    await box.put('settings', updatedSettings);
    if (mounted) {
      ref.read(userSettingsProvider.notifier).state = updatedSettings;
      ref.invalidate(currentCycleExpensesProvider);
      ref.invalidate(dailyStatsProvider);
    }

    // Push updated settings to Firestore in background
    _pushNewCycleToFirestore(updatedSettings);

    return updatedSettings;
  }

  Future<bool?> _showCarryForwardDialog(
      double remaining, String Function(double) format) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.background,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.celebration_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              const Text('New Month, New Budget!',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'Your salary has arrived! You have ${format(remaining)} remaining from last month.',
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Would you like to carry forward this balance?',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('No',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Yes, carry forward',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pushNewCycleToFirestore(UserSettings settings) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'nextSalaryDate':
            Timestamp.fromDate(settings.nextSalaryDate),
        'lastSalaryDate': settings.lastSalaryDate != null
            ? Timestamp.fromDate(settings.lastSalaryDate!)
            : null,
        'carryForwardAmount': settings.carryForwardAmount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _syncOnLoad() async {
    await _syncSettings();
    await _syncExpenses();
  }

  Future<void> _syncSettings() async {
    if (ref.read(userSettingsProvider) != null) return;
    try {
      final data = await FirestoreService.getUserData();
      if (data == null || !mounted) return;
      final settings = UserSettings(
        monthlyIncome: (data['monthlyIncome'] as num).toDouble(),
        nextSalaryDate: (data['nextSalaryDate'] as Timestamp).toDate(),
        fixedExpenses: (data['fixedExpenses'] as num).toDouble(),
        savingsGoal: (data['savingsGoal'] as num).toDouble(),
        currencyCode: data['currencyCode'] as String? ?? 'PKR',
        expensesBreakdown: data['expensesBreakdown'] as String?,
      );
      final box = ref.read(userSettingsBoxProvider);
      await box.put('settings', settings);
      if (mounted) {
        ref.read(userSettingsProvider.notifier).state = settings;
        ref.read(currencyCodeProvider.notifier).state = settings.currencyCode;
      }
    } catch (_) {}
  }

  Future<void> _syncExpenses() async {
    try {
      final box = ref.read(expensesBoxProvider);
      await FirestoreService.syncExpensesToHive(box);
      if (!mounted) return;
      // Refresh all expense-derived providers so UI reflects synced data
      ref.invalidate(expensesProvider);
      ref.invalidate(todaysExpensesProvider);
      ref.invalidate(dailyStatsProvider);
    } catch (_) {}
  }

  // ── Delete expense ────────────────────────────────────────────────────────
  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Expense?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Delete from Hive
    await expense.delete();

    // Delete from Firestore
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users').doc(uid).collection('expenses')
            .where('amount', isEqualTo: expense.amount)
            .where('category', isEqualTo: expense.category)
            .limit(1).get();
        for (final doc in snapshot.docs) { await doc.reference.delete(); }
      }
    } catch (_) {}

    ref.invalidate(expensesProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted'), backgroundColor: AppColors.danger, duration: Duration(seconds: 2)),
      );
    }
  }

  // ── Edit expense ──────────────────────────────────────────────────────────
  void _editExpense(Expense expense) {
    final amountCtrl = TextEditingController(text: expense.amount.toStringAsFixed(0));
    final noteCtrl = TextEditingController(text: expense.note ?? '');

    // Normalize category to lowercase and ensure it exists in list
    final rawCat = expense.category.toLowerCase().trim();
    String selectedCategory = _kCategories.contains(rawCat) ? rawCat : 'other';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text('Edit Expense', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 20),
                // Amount
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDeco('Amount', Icons.payments_rounded),
                ),
                const SizedBox(height: 16),
                // Category dropdown — all lowercase, no duplicates
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: _inputDeco('Category', Icons.category_rounded),
                  items: _kCategories.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c[0].toUpperCase() + c.substring(1)),
                  )).toList(),
                  onChanged: (val) { if (val != null) setBS(() => selectedCategory = val); },
                ),
                const SizedBox(height: 16),
                // Note
                TextField(
                  controller: noteCtrl,
                  decoration: _inputDeco('Note (optional)', Icons.note_rounded),
                ),
                const SizedBox(height: 24),
                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      final newAmount = double.tryParse(amountCtrl.text.trim());
                      if (newAmount == null || newAmount <= 0) return;

                      // Update Hive
                      expense.amount = newAmount;
                      expense.category = selectedCategory;
                      expense.note = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();
                      await expense.save();

                      // Update Firestore
                      try {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          final snapshot = await FirebaseFirestore.instance
                              .collection('users').doc(uid).collection('expenses')
                              .orderBy('date', descending: true).limit(50).get();
                          for (final doc in snapshot.docs) {
                            final data = doc.data();
                            if ((data['category'] as String? ?? '').toLowerCase() == selectedCategory.toLowerCase()) {
                              await doc.reference.update({
                                'amount': newAmount,
                                'category': selectedCategory,
                                'note': expense.note ?? '',
                              });
                              break;
                            }
                          }
                        }
                      } catch (_) {}

                      ref.invalidate(expensesProvider);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Expense updated!'), backgroundColor: AppColors.success, duration: Duration(seconds: 2)),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
  );

  String _getInitials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }

  void _comingSoon(String feature) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming soon!'), duration: const Duration(seconds: 2)),
    );
  }

  void _showExportDialog(BuildContext context) {
    final now = DateTime.now();

    Future<void> doExport(DateTime start, DateTime end) async {
      final settings = ref.read(userSettingsProvider);
      if (settings == null) return;
      final allExpenses = ref.read(expensesProvider);
      final currencySymbol = ref.read(currencySymbolProvider);

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black26,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }
      try {
        await PdfExportService.export(
          allExpenses: allExpenses,
          settings: settings,
          startDate: start,
          endDate: end,
          currencySymbol: currencySymbol,
        );
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $e')),
          );
        }
      }
    }

    Future<void> pickCustomRange() async {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: now,
        initialDateRange: DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        ),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        ),
      );
      if (picked != null) {
        await doExport(picked.start, picked.end);
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Text('Export PDF Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Choose the date range for your expense report.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            _exportOption(
              icon: Icons.today_rounded,
              label: 'This Month',
              subtitle: DateFormat('MMMM yyyy').format(now),
              onTap: () {
                Navigator.pop(context);
                doExport(DateTime(now.year, now.month, 1), now);
              },
            ),
            const SizedBox(height: 10),
            _exportOption(
              icon: Icons.chevron_left_rounded,
              label: 'Last Month',
              subtitle: DateFormat('MMMM yyyy').format(DateTime(now.year, now.month - 1)),
              onTap: () {
                Navigator.pop(context);
                final first = DateTime(now.year, now.month - 1, 1);
                final last = DateTime(now.year, now.month, 0);
                doExport(first, last);
              },
            ),
            const SizedBox(height: 10),
            _exportOption(
              icon: Icons.calendar_today_rounded,
              label: 'This Year',
              subtitle: '1 Jan – ${DateFormat('d MMM yyyy').format(now)}',
              onTap: () {
                Navigator.pop(context);
                doExport(DateTime(now.year, 1, 1), now);
              },
            ),
            const SizedBox(height: 10),
            _exportOption(
              icon: Icons.date_range_rounded,
              label: 'Custom Range',
              subtitle: 'Pick start and end date',
              onTap: () {
                Navigator.pop(context);
                pickCustomRange();
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context, DailyStats stats) {
    final format = ref.read(formatCurrencyProvider);
    final todaysExpenses = ref.read(todaysExpensesProvider);
    final isOverBudget = stats.spentToday > stats.dailyLimit && stats.dailyLimit > 0;
    final isNearLimit = !isOverBudget && stats.dailyLimit > 0 && stats.spentToday >= stats.dailyLimit * 0.8;
    final isLowBalance = stats.remainingBalance < stats.dailyLimit * 2 && stats.remainingBalance >= 0;

    final List<_NotifItem> notifications = [];

    if (isOverBudget) {
      notifications.add(_NotifItem(
        icon: Icons.warning_rounded,
        color: const Color(0xFFEF4444),
        title: 'Over Daily Budget',
        body: 'You\'ve spent ${format(stats.spentToday)} today — ${format(stats.spentToday - stats.dailyLimit)} over your ${format(stats.dailyLimit)} limit.',
      ));
    } else if (isNearLimit) {
      notifications.add(_NotifItem(
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFFF9500),
        title: 'Approaching Daily Limit',
        body: 'You\'ve used ${(stats.spentToday / stats.dailyLimit * 100).toStringAsFixed(0)}% of your daily budget. Only ${format(stats.remainingToday)} left.',
      ));
    } else {
      notifications.add(_NotifItem(
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF22C55E),
        title: 'Within Daily Budget',
        body: 'Great! You have ${format(stats.remainingToday)} left to spend today.',
      ));
    }

    if (todaysExpenses.isNotEmpty) {
      notifications.add(_NotifItem(
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF6366F1),
        title: 'Today\'s Expenses',
        body: '${todaysExpenses.length} expense${todaysExpenses.length == 1 ? '' : 's'} recorded today totalling ${format(stats.spentToday)}.',
      ));
    } else {
      notifications.add(_NotifItem(
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF94A3B8),
        title: 'No Expenses Today',
        body: 'You haven\'t recorded any expenses today yet.',
      ));
    }

    if (isLowBalance) {
      notifications.add(_NotifItem(
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFFFF9500),
        title: 'Low Monthly Balance',
        body: 'Your remaining balance is ${format(stats.remainingBalance)} with ${stats.daysLeft} day${stats.daysLeft == 1 ? '' : 's'} until payday.',
      ));
    }

    notifications.add(_NotifItem(
      icon: Icons.calendar_today_rounded,
      color: const Color(0xFFA855F7),
      title: '${stats.daysLeft} Day${stats.daysLeft == 1 ? '' : 's'} Until Payday',
      body: 'Monthly income: ${format(stats.monthlyIncome)}. Remaining balance: ${format(stats.remainingBalance)}.',
    ));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const Spacer(),
                Text('${notifications.length} alerts', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 16),
            ...notifications.map((n) => GestureDetector(
              onTap: () => showDialog(
                context: sheetCtx,
                builder: (dialogCtx) => Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  backgroundColor: AppColors.background,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: n.color.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(n.icon, color: n.color, size: 30),
                        ),
                        const SizedBox(height: 16),
                        Text(n.title,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: n.color),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(n.body,
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: n.color,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Got it', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: n.color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: n.color.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: n.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(n.icon, color: n.color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: n.color)),
                          const SizedBox(height: 2),
                          Text(n.body, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: n.color.withOpacity(0.6), size: 18),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetCtx),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'User';
    final email = user?.email ?? '';
    final photoURL = user?.photoURL;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            // Avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 3),
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
                child: photoURL == null
                    ? Text(_getInitials(displayName), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary))
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            Text(email, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            // Info fields
            _profileField(icon: Icons.person_rounded, label: 'Full Name', value: displayName),
            const SizedBox(height: 10),
            _profileField(icon: Icons.email_rounded, label: 'Email', value: email),
            const SizedBox(height: 24),
            // Log Out button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.w800)),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Sign Out', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    ref.read(userSettingsProvider.notifier).state = null;
                    await appAuthNotifier.signOut();
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            // Clear All Data button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: const Text('Clear All Data', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Delete All Data?', style: TextStyle(fontWeight: FontWeight.w800)),
                      content: const Text('This will permanently delete all your expenses and budget setup. This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Delete All', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    // Show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      barrierColor: Colors.black26,
                      builder: (_) => const Center(child: CircularProgressIndicator()),
                    );
                    try {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid != null) {
                        final db = FirebaseFirestore.instance;
                        final snap = await db.collection('users').doc(uid).collection('expenses').get();
                        for (final doc in snap.docs) await doc.reference.delete();
                        await db.collection('users').doc(uid).delete();
                      }
                      await ref.read(userSettingsBoxProvider).clear();
                      await ref.read(expensesBoxProvider).clear();
                      ref.read(userSettingsProvider.notifier).state = null;
                      ref.invalidate(expensesProvider);
                      ref.invalidate(todaysExpensesProvider);
                      ref.invalidate(dailyStatsProvider);
                      appAuthNotifier.markSetupIncomplete();
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            // Close button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileField({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  void _showDailyExpensesSheet() {
    final allExpenses = ref.read(expensesProvider);
    final format = ref.read(formatCurrencyProvider);

    // Group by calendar date descending
    final Map<String, List<Expense>> grouped = {};
    for (final e in allExpenses) {
      final key = DateFormat('yyyy-MM-dd').format(e.date);
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final total = allExpenses.fold(0.0, (s, e) => s + e.amount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DailyExpensesSheet(
        grouped: grouped,
        sortedKeys: sortedKeys,
        total: total,
        format: format,
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, String displayName) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final initials = _getInitials(displayName.isNotEmpty ? displayName : 'User');

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Color(0xFF94A3B8))),
    );

    Widget drawerItem({required IconData icon, required String label, required VoidCallback onTap, bool active = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: active ? AppColors.primary.withOpacity(0.12) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: active ? AppColors.primary : const Color(0xFF64748B)),
          ),
          title: Text(label, style: TextStyle(fontSize: 15, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? AppColors.primary : const Color(0xFF1E293B))),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          tileColor: active ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
          onTap: onTap,
        ),
      );
    }

    return Drawer(
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.6), width: 2.5),
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName.isNotEmpty ? displayName : 'User', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      if (email.isNotEmpty)
                        Text(email, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Menu items ───────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                const SizedBox(height: 8),
                drawerItem(icon: Icons.dashboard_rounded, label: 'Dashboard', active: true, onTap: () => Navigator.pop(context)),
                sectionLabel('FINANCE'),
                drawerItem(icon: Icons.receipt_long_rounded, label: 'Transactions', onTap: () { Navigator.pop(context); context.push('/history'); }),
                drawerItem(icon: Icons.upload_rounded, label: 'Export Report', onTap: () { Navigator.pop(context); _showExportDialog(context); }),
                drawerItem(icon: Icons.donut_large_rounded, label: 'Analytics', onTap: () { Navigator.pop(context); context.push('/analytics'); }),
                drawerItem(icon: Icons.savings_rounded, label: 'Savings Goals', onTap: () => _comingSoon('Savings Goals')),
                drawerItem(icon: Icons.account_balance_wallet_rounded, label: 'Budget Planner', onTap: () => _comingSoon('Budget Planner')),
                sectionLabel('ACCOUNT'),
                drawerItem(icon: Icons.notifications_rounded, label: 'Notifications', onTap: () => _comingSoon('Notifications')),
                drawerItem(icon: Icons.settings_rounded, label: 'Settings', onTap: () { Navigator.pop(context); context.push('/settings'); }),
                drawerItem(icon: Icons.help_outline_rounded, label: 'Help & Support', onTap: () => _comingSoon('Help & Support')),
              ],
            ),
          ),
          // ── Footer ───────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text('Salary Planner v1.0.0', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dailyStatsProvider);
    final settings = ref.watch(userSettingsProvider);
    final todaysExpenses = ref.watch(todaysExpensesProvider);
    final allExpenses = ref.watch(expensesProvider);
    final format = ref.watch(formatCurrencyProvider);
    final totalAllExpenses = allExpenses.fold(0.0, (s, e) => s + e.amount);

    if (stats == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary))),
      );
    }

    final displayName = FirebaseAuth.instance.currentUser?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('DASHBOARD'),
            if (displayName.isNotEmpty)
              Text('Hello, $displayName!', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_rounded),
                onPressed: () {
                  setState(() => _lastViewedSpentToday = stats.spentToday);
                  _showNotificationsSheet(context, stats);
                },
              ),
              if (stats.spentToday > stats.dailyLimit &&
                  stats.dailyLimit > 0 &&
                  (_lastViewedSpentToday == null ||
                      stats.spentToday > _lastViewedSpentToday! + 0.01))
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _showProfileSheet(context),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  _getInitials(displayName.isNotEmpty ? displayName : 'User'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, displayName),
      body: Stack(
        children: [
          Positioned(
            top: -100, right: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.primary.withOpacity(0.15), Colors.transparent]),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Days until payday
                Center(
                  child: GestureDetector(
                    onTap: () => _showPaydayDetailsSheet(stats, format),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                      decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(30), border: Border.all(color: AppColors.border)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text('${stats.daysLeft} DAYS UNTIL PAYDAY', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 1)),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Summary Cards
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.4,
                  children: [
                    _SummaryCard(label: 'MONTHLY INCOME', formattedValue: format(stats.monthlyIncome), icon: Icons.account_balance_wallet_rounded, color: const Color(0xFF64748B), iconTint: const Color(0xFF64748B), onTap: () => _showIncomeDialog(stats.monthlyIncome, format)),
                    _SummaryCard(label: 'FIXED EXPENSES', formattedValue: format(stats.fixedExpenses), icon: Icons.receipt_long_rounded, color: const Color(0xFF3B82F6), iconTint: const Color(0xFF3B82F6), onTap: () => _showFixedExpensesSheet(context, settings?.expensesBreakdown, format)),
                    _SummaryCard(label: 'SAVINGS GOAL', formattedValue: format(stats.savingsGoal), icon: Icons.savings_rounded, color: const Color(0xFF8B5CF6), iconTint: const Color(0xFF8B5CF6), onTap: () => _showSavingsGoalSheet(stats, format)),
                    _SummaryCard(label: 'REMAINING', formattedValue: format(stats.remainingBalance), icon: Icons.account_balance_rounded, isHighlighted: true, color: _getRemainingBalanceColor(stats.remainingBalance, stats.availableSpending), iconTint: const Color(0xFF10B981), onTap: () => _showSpendingBreakdownSheet(format)),
                  ],
                ),
                const SizedBox(height: 14),

                // Total Daily Expenses row — between cards and Safe to Spend
                GestureDetector(
                  onTap: () => _showDailyExpensesSheet(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.compare_arrows_rounded, color: Color(0xFFEF4444), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('TOTAL DAILY EXPENSES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: AppColors.textSecondary)),
                        ),
                        Text(format(totalAllExpenses), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFEF4444))),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFEF4444)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Safe to Spend Card
                GestureDetector(
                  onTap: () => _showDailyBudgetSheet(stats, format),
                  child: DailyBudgetCard(dailyLimit: stats.dailyLimit, spentToday: stats.spentToday, remainingToday: stats.remainingToday),
                ),
                const SizedBox(height: 24),

                // Today's Expenses
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Today's Expenses", style: Theme.of(context).textTheme.titleLarge),
                    TextButton(
                      onPressed: () => context.push('/history'),
                      child: Text('View All', style: TextStyle(color: AppColors.primary.withOpacity(0.8), fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),

                if (todaysExpenses.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(Icons.swipe_left_rounded, size: 16, color: AppColors.textSecondary.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Text('Swipe left to edit or delete', style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.6))),
                      ],
                    ),
                  ),

                if (todaysExpenses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 54, color: AppColors.textSecondary.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text('No expenses today!', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  )
                else
                  ...todaysExpenses.take(5).map((expense) => _SwipeableExpenseItem(
                    key: ValueKey(expense.key),
                    expense: expense,
                    format: format,
                    onEdit: () => _editExpense(expense),
                    onDelete: () => _deleteExpense(expense),
                  )),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFF22D3EE)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: const Color(0xFF818CF8).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/add-expense'),
          backgroundColor: Colors.transparent, elevation: 0, highlightElevation: 0, foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded, size: 28),
          label: const Text('ADD EXPENSE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ── 1. Monthly Income dialog ──────────────────────────────────────────────
  void _showIncomeDialog(double current, String Function(double) format) {
    final ctrl = TextEditingController(text: current.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF64748B).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF64748B), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Monthly Income', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Income amount',
            prefixIcon: const Icon(Icons.payments_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim());
              if (val == null || val <= 0) return;
              final s = ref.read(userSettingsProvider);
              if (s == null) return;
              s.monthlyIncome = val;
              s.save();
              ref.read(userSettingsProvider.notifier).state = s;
              ref.invalidate(dailyStatsProvider);
              FirestoreService.saveUserSetup(
                monthlyIncome: val,
                nextSalaryDate: s.nextSalaryDate,
                fixedExpenses: s.fixedExpenses,
                savingsGoal: s.savingsGoal,
                currencyCode: s.currencyCode,
                expensesBreakdown: s.expensesBreakdown,
              ).catchError((_) {});
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── 2. Savings Goal sheet ──────────────────────────────────────────────────
  void _showSavingsGoalSheet(DailyStats stats, String Function(double) format) {
    final goalCtrl = TextEditingController(text: stats.savingsGoal.toStringAsFixed(0));
    // Savings secured = how much of the goal is protected (eaten into if overspent)
    final secured = (stats.savingsGoal + stats.remainingBalance).clamp(0.0, stats.savingsGoal);
    final pct = stats.savingsGoal > 0 ? secured / stats.savingsGoal : 1.0;
    final onTrack = stats.remainingBalance >= 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.savings_rounded, color: Color(0xFF8B5CF6), size: 22)),
                    const SizedBox(width: 14),
                    const Expanded(child: Text('Savings Goal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: onTrack ? AppColors.success.withOpacity(0.12) : AppColors.danger.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          Icon(onTrack ? Icons.check_circle_rounded : Icons.warning_rounded, size: 14, color: onTrack ? AppColors.success : AppColors.danger),
                          const SizedBox(width: 4),
                          Text(onTrack ? 'ON TRACK' : 'AT RISK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: onTrack ? AppColors.success : AppColors.danger)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Goal amount row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Monthly Goal', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(format(stats.savingsGoal), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF8B5CF6))),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('Currently Secured', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(format(secured), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: onTrack ? AppColors.success : AppColors.danger)),
                    ]),
                  ],
                ),
                const SizedBox(height: 20),

                // Progress bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Progress', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: onTrack ? AppColors.success : AppColors.danger)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 14,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(onTrack ? AppColors.success : AppColors.danger),
                  ),
                ),
                const SizedBox(height: 20),

                // Info row
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          onTrack
                              ? 'Great! Your savings goal of ${format(stats.savingsGoal)} is fully protected this month.'
                              : 'You\'ve overspent by ${format(-stats.remainingBalance)}. ${format(-stats.remainingBalance < stats.savingsGoal ? stats.savingsGoal - (-stats.remainingBalance) : 0)} of your savings is still secured.',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Edit goal
                const Text('EDIT GOAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: goalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'New savings goal',
                          prefixIcon: const Icon(Icons.savings_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6), elevation: 0,
                        minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        final val = double.tryParse(goalCtrl.text.trim());
                        if (val == null || val < 0) return;
                        final s = ref.read(userSettingsProvider);
                        if (s == null) return;
                        s.savingsGoal = val;
                        s.save();
                        ref.read(userSettingsProvider.notifier).state = s;
                        ref.invalidate(dailyStatsProvider);
                        FirestoreService.saveUserSetup(
                          monthlyIncome: s.monthlyIncome,
                          nextSalaryDate: s.nextSalaryDate,
                          fixedExpenses: s.fixedExpenses,
                          savingsGoal: val,
                          currencyCode: s.currencyCode,
                          expensesBreakdown: s.expensesBreakdown,
                        ).catchError((_) {});
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 3. Spending Breakdown sheet (Remaining card) ───────────────────────────
  void _showSpendingBreakdownSheet(String Function(double) format) {
    final allExpenses = ref.read(expensesProvider);
    final totalSpent = allExpenses.fold(0.0, (s, e) => s + e.amount);
    final Map<String, double> byCategory = {};
    for (final e in allExpenses) {
      final key = e.category.isNotEmpty ? (e.category[0].toUpperCase() + e.category.substring(1).toLowerCase()) : 'Other';
      byCategory[key] = (byCategory[key] ?? 0) + e.amount;
    }
    final sorted = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    const categoryColors = [
      Color(0xFF7B2FF7), Color(0xFF3B82F6), Color(0xFF10B981),
      Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF8B5CF6),
      Color(0xFF06B6D4), Color(0xFFEC4899),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.pie_chart_rounded, color: AppColors.success, size: 22)),
                const SizedBox(width: 14),
                const Expanded(child: Text('Spending Breakdown', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              ],
            ),
            const SizedBox(height: 20),

            // Total spent banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Spent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(format(totalSpent), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (sorted.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No expenses recorded yet.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500))),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.45),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final entry = sorted[i];
                    final pct = totalSpent > 0 ? entry.value / totalSpent : 0.0;
                    final color = categoryColors[i % categoryColors.length];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                            Text(format(entry.value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                            const SizedBox(width: 8),
                            SizedBox(width: 40, child: Text('${(pct * 100).toStringAsFixed(0)}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct, minHeight: 7,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 4. Daily Budget sheet (Safe to Spend card) ────────────────────────────
  void _showDailyBudgetSheet(DailyStats stats, String Function(double) format) {
    final todaysExpenses = ref.read(todaysExpensesProvider);
    final isOverBudget = stats.remainingToday < 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: (isOverBudget ? AppColors.danger : const Color(0xFF6366F1)).withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.flash_on_rounded, color: isOverBudget ? AppColors.danger : const Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(child: Text('Today\'s Budget', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              ],
            ),
            const SizedBox(height: 20),

            // 3-stat row
            Row(
              children: [
                Expanded(child: _StatChip(label: 'DAILY LIMIT', value: format(stats.dailyLimit), color: const Color(0xFF6366F1))),
                const SizedBox(width: 10),
                Expanded(child: _StatChip(label: 'SPENT', value: format(stats.spentToday), color: isOverBudget ? AppColors.danger : AppColors.textPrimary)),
                const SizedBox(width: 10),
                Expanded(child: _StatChip(label: 'REMAINING', value: format(stats.remainingToday < 0 ? 0 : stats.remainingToday), color: isOverBudget ? AppColors.danger : AppColors.success)),
              ],
            ),
            const SizedBox(height: 20),

            // Today's expenses list
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TODAY'S EXPENSES", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 1.2)),
                Text('${todaysExpenses.length} items', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),

            if (todaysExpenses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 8),
                      const Text('No expenses today', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.3),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: todaysExpenses.length,
                  itemBuilder: (_, i) {
                    final e = todaysExpenses[i];
                    final cat = e.category.isNotEmpty ? (e.category[0].toUpperCase() + e.category.substring(1).toLowerCase()) : 'Other';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                      child: Row(
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.receipt_rounded, color: AppColors.primary, size: 16)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(cat, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              if (e.note != null && e.note!.isNotEmpty)
                                Text(e.note!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ]),
                          ),
                          Text(format(e.amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.danger)),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // Add Expense button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/add-expense');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text('ADD EXPENSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFixedExpensesSheet(BuildContext context, String? breakdownJson, String Function(double) format) {
    final icons = <String, IconData>{'Rent/Mortgage': Icons.home_rounded, 'Utilities & Bills': Icons.bolt_rounded, 'Food & Groceries': Icons.shopping_basket_rounded, 'Transport/Fuel': Icons.directions_car_rounded, 'Other Fixed': Icons.more_horiz_rounded};

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final Map<String, double> items = ref.read(userSettingsProvider)?.expensesBreakdown != null
              ? Map<String, double>.from(jsonDecode(ref.read(userSettingsProvider)!.expensesBreakdown!) as Map)
              : (breakdownJson != null ? Map<String, double>.from(jsonDecode(breakdownJson) as Map) : {});

          Future<void> saveBreakdown(Map<String, double> updated) async {
            final s = ref.read(userSettingsProvider);
            if (s == null) return;
            final newTotal = updated.values.fold(0.0, (a, b) => a + b);
            final encoded = jsonEncode(updated);
            s.expensesBreakdown = encoded;
            s.fixedExpenses = newTotal;
            await s.save();
            ref.read(userSettingsProvider.notifier).state = s;
            FirestoreService.saveUserSetup(
              monthlyIncome: s.monthlyIncome,
              nextSalaryDate: s.nextSalaryDate,
              fixedExpenses: newTotal,
              savingsGoal: s.savingsGoal,
              currencyCode: s.currencyCode,
              expensesBreakdown: encoded,
            ).catchError((_) {});
            ref.invalidate(dailyStatsProvider);
            setSheetState(() {});
          }

          void editEntry(String key, double value) {
            final nameCtrl = TextEditingController(text: key);
            final amountCtrl = TextEditingController(text: value.toStringAsFixed(0));
            showDialog(
              context: ctx,
              builder: (dCtx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Edit Fixed Expense', style: TextStyle(fontWeight: FontWeight.w800)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        prefixIcon: const Icon(Icons.label_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: const Icon(Icons.payments_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      final newAmount = double.tryParse(amountCtrl.text.trim());
                      if (newAmount == null || newAmount < 0) return;
                      final newName = nameCtrl.text.trim();
                      if (newName.isEmpty) return;
                      final updated = Map<String, double>.from(items);
                      if (newName != key) updated.remove(key);
                      updated[newName] = newAmount;
                      Navigator.pop(dCtx);
                      await saveBreakdown(updated);
                    },
                    child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          }

          void deleteEntry(String key) async {
            final confirmed = await showDialog<bool>(
              context: ctx,
              builder: (dCtx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Delete this expense?', style: TextStyle(fontWeight: FontWeight.w800)),
                content: Text('Remove "$key" from fixed expenses?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dCtx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Delete', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
            if (confirmed != true) return;
            final updated = Map<String, double>.from(items)..remove(key);
            await saveBreakdown(updated);
          }

          return Container(
            decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                const Text('Fixed Expenses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 24),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No fixed expenses.', style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  ...items.entries.map((entry) {
                    final capturedKey = entry.key;
                    final capturedValue = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.only(left: 18, top: 10, bottom: 10, right: 12),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                      child: Row(
                        children: [
                          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icons[capturedKey] ?? Icons.receipt_rounded, color: AppColors.primary, size: 20)),
                          const SizedBox(width: 14),
                          Expanded(child: Text(capturedKey, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary))),
                          Text(format(capturedValue), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF3B82F6))),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTapDown: (TapDownDetails d) async {
                              final RenderBox overlay = Overlay.of(ctx).context.findRenderObject()! as RenderBox;
                              final result = await showMenu<String>(
                                context: ctx,
                                position: RelativeRect.fromRect(
                                  d.globalPosition & const Size(1, 1),
                                  Offset.zero & overlay.size,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                items: [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: const [
                                      Icon(Icons.edit_rounded, size: 18, color: Color(0xFF3B82F6)),
                                      SizedBox(width: 10),
                                      Text('Edit', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
                                    ]),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: const [
                                      Icon(Icons.delete_rounded, size: 18, color: AppColors.danger),
                                      SizedBox(width: 10),
                                      Text('Delete', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger)),
                                    ]),
                                  ),
                                ],
                              );
                              if (result == 'edit') editEntry(capturedKey, capturedValue);
                              if (result == 'delete') deleteEntry(capturedKey);
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.more_vert_rounded, color: AppColors.primary, size: 20),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const Divider(color: AppColors.border, height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(format(items.values.fold(0.0, (a, b) => a + b)), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Payday Details Sheet ──────────────────────────────────────────────────
  void _showPaydayDetailsSheet(DailyStats initialStats, String Function(double) format) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final stats = ref.read(dailyStatsProvider) ?? initialStats;
          final s = ref.read(userSettingsProvider);
          if (s == null) return const SizedBox();

          return DraggableScrollableSheet(
            initialChildSize: 0.88,
            minChildSize: 0.5,
            maxChildSize: 0.96,
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),

                  // Gradient header
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Payday Details', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                              Text('${stats.daysLeft} day${stats.daysLeft != 1 ? 's' : ''} remaining', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                          child: Text(DateFormat('d MMM').format(s.nextSalaryDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      children: [
                        // ── Payday info ──────────────────────────────
                        const _SheetSectionLabel(label: 'PAYDAY INFO'),
                        const SizedBox(height: 12),
                        _PaydayDetailRow(icon: Icons.event_rounded, iconColor: AppColors.primary, label: 'Next Payday Date', value: DateFormat('EEEE, d MMMM yyyy').format(s.nextSalaryDate)),
                        _PaydayDetailRow(icon: Icons.hourglass_bottom_rounded, iconColor: AppColors.warning, label: 'Days Remaining', value: '${stats.daysLeft} day${stats.daysLeft != 1 ? 's' : ''}'),
                        _PaydayDetailRow(icon: Icons.account_balance_rounded, iconColor: stats.remainingBalance >= 0 ? AppColors.success : AppColors.danger, label: 'Remaining Budget', value: format(stats.remainingBalance), valueColor: stats.remainingBalance >= 0 ? AppColors.success : AppColors.danger),
                        _PaydayDetailRow(icon: Icons.today_rounded, iconColor: AppColors.primary, label: 'Safe to Spend / Day', value: format(stats.dailyLimit), valueColor: AppColors.primary),

                        const SizedBox(height: 24),

                        // ── Monthly breakdown ────────────────────────
                        const _SheetSectionLabel(label: 'MONTHLY BREAKDOWN'),
                        const SizedBox(height: 12),
                        _PaydayDetailRow(icon: Icons.payments_rounded, iconColor: AppColors.success, label: 'Total Monthly Income', value: format(stats.monthlyIncome)),
                        _PaydayDetailRow(icon: Icons.receipt_long_rounded, iconColor: const Color(0xFF3B82F6), label: 'Fixed Expenses', value: format(stats.fixedExpenses)),
                        _PaydayDetailRow(icon: Icons.savings_rounded, iconColor: const Color(0xFF8B5CF6), label: 'Savings Goal', value: format(stats.savingsGoal)),

                        const SizedBox(height: 24),

                        // ── Budget calculation ───────────────────────
                        const _SheetSectionLabel(label: 'BUDGET SUMMARY'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              _CalcRow(label: 'Monthly Income', value: format(stats.monthlyIncome)),
                              const SizedBox(height: 10),
                              _CalcRow(label: '− Fixed Expenses', value: format(stats.fixedExpenses), valueColor: AppColors.danger),
                              const SizedBox(height: 10),
                              _CalcRow(label: '− Savings Goal', value: format(stats.savingsGoal), valueColor: const Color(0xFF8B5CF6)),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1, color: AppColors.border),
                              ),
                              _CalcRow(label: '= Available Budget', value: format(stats.availableSpending), valueColor: AppColors.success, bold: true),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.08), AppColors.secondary.withOpacity(0.06)]),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(child: Text(format(stats.availableSpending), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Text('÷', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textSecondary)),
                                    ),
                                    Text('${stats.daysLeft}d', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 13)),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Text('=', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textSecondary)),
                                    ),
                                    Flexible(child: Text(format(stats.dailyLimit), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.success, fontSize: 14), overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Actions ──────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: s.nextSalaryDate.isAfter(DateTime.now()) ? s.nextSalaryDate : DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                builder: (context, child) => Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked == null || !ctx.mounted) return;
                              s.nextSalaryDate = picked;
                              await s.save();
                              ref.read(userSettingsProvider.notifier).state = s;
                              ref.invalidate(dailyStatsProvider);
                              FirestoreService.saveUserSetup(
                                monthlyIncome: s.monthlyIncome,
                                nextSalaryDate: picked,
                                fixedExpenses: s.fixedExpenses,
                                savingsGoal: s.savingsGoal,
                                currencyCode: s.currencyCode,
                                expensesBreakdown: s.expensesBreakdown,
                              ).catchError((_) {});
                              setSheetState(() {});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary, elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.edit_calendar_rounded, color: Colors.white, size: 20),
                            label: const Text('EDIT PAYDAY DATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('CLOSE', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getRemainingBalanceColor(double remaining, double income) {
    if (remaining <= 0) return AppColors.danger;
    final ratio = remaining / (income > 0 ? income : 1);
    if (ratio < 0.1) return AppColors.danger;
    if (ratio < 0.25) return AppColors.warning;
    return AppColors.success;
  }
}

// ── Swipeable Expense Item ────────────────────────────────────────────────────
class _SwipeableExpenseItem extends StatefulWidget {
  final Expense expense;
  final String Function(double) format;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SwipeableExpenseItem({super.key, required this.expense, required this.format, required this.onEdit, required this.onDelete});

  @override
  State<_SwipeableExpenseItem> createState() => _SwipeableExpenseItemState();
}

class _SwipeableExpenseItemState extends State<_SwipeableExpenseItem> {
  double _offset = 0;
  static const double _revealWidth = 152.0; // 76 edit + 76 delete

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() => _offset = (_offset + d.delta.dx).clamp(-_revealWidth, 0.0));
  }

  void _onDragEnd(DragEndDetails d) {
    final snap = _offset < -_revealWidth / 2 ? -_revealWidth : 0.0;
    setState(() => _offset = snap);
  }

  void _close() => setState(() => _offset = 0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Container(
        height: 76,
        margin: const EdgeInsets.only(bottom: 12),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // ── Action buttons behind the card ─────────────────────
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // EDIT
                  GestureDetector(
                    onTap: () { _close(); widget.onEdit(); },
                    child: Container(
                      width: 76,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24)),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                          SizedBox(height: 4),
                          Text('EDIT', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                  // DELETE
                  GestureDetector(
                    onTap: () { _close(); widget.onDelete(); },
                    child: Container(
                      width: 76,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.only(topRight: Radius.circular(24), bottomRight: Radius.circular(24)),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_rounded, color: Colors.white, size: 22),
                          SizedBox(height: 4),
                          Text('DELETE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Sliding card ───────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(_offset, 0, 0),
              child: GestureDetector(
                onTap: _offset != 0 ? _close : null,
                child: Container(
                  height: 76,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.receipt_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(widget.expense.category.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
                            if (widget.expense.note != null && widget.expense.note!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(widget.expense.note!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                      Text(widget.format(widget.expense.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.danger, letterSpacing: -0.5)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat Chip (used in Daily Budget sheet) ────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color))),
        ],
      ),
    );
  }
}

// ── Payday Sheet Helpers ──────────────────────────────────────────────────────
class _SheetSectionLabel extends StatelessWidget {
  final String label;
  const _SheetSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 1.4));
  }
}

class _PaydayDetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  const _PaydayDetailRow({required this.icon, required this.iconColor, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
          Flexible(child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: valueColor ?? AppColors.textPrimary), textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _CalcRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _CalcRow({required this.label, required this.value, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: bold ? AppColors.textPrimary : AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: valueColor ?? (bold ? AppColors.success : AppColors.textPrimary))),
      ],
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String label;
  final String formattedValue;
  final IconData icon;
  final Color color;
  final Color iconTint;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const _SummaryCard({required this.label, required this.formattedValue, required this.icon, required this.color, required this.iconTint, this.isHighlighted = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isHighlighted ? color.withOpacity(0.5) : AppColors.border, width: isHighlighted ? 2 : 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconTint.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconTint, size: 22)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                FittedBox(fit: BoxFit.scaleDown, child: Text(formattedValue, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isHighlighted ? color : AppColors.textPrimary, letterSpacing: -0.5))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifItem {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _NotifItem({required this.icon, required this.color, required this.title, required this.body});
}

// ── Daily Expenses Bottom Sheet ───────────────────────────────────────────────
class _DailyExpensesSheet extends StatefulWidget {
  final Map<String, List<Expense>> grouped;
  final List<String> sortedKeys;
  final double total;
  final String Function(double) format;

  const _DailyExpensesSheet({
    required this.grouped,
    required this.sortedKeys,
    required this.total,
    required this.format,
  });

  @override
  State<_DailyExpensesSheet> createState() => _DailyExpensesSheetState();
}

class _DailyExpensesSheetState extends State<_DailyExpensesSheet> {
  final Set<String> _expanded = {};

  String _formatDateKey(String key) {
    final dt = DateTime.parse(key);
    return DateFormat('EEEE, d MMM yyyy').format(dt);
  }

  IconData _categoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'food': return Icons.restaurant_rounded;
      case 'transport': return Icons.directions_car_rounded;
      case 'shopping': return Icons.shopping_bag_rounded;
      case 'entertainment': return Icons.movie_rounded;
      case 'health': return Icons.favorite_rounded;
      case 'bills': return Icons.receipt_long_rounded;
      case 'education': return Icons.school_rounded;
      default: return Icons.category_rounded;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'food': return const Color(0xFFFF6B6B);
      case 'transport': return const Color(0xFF4ECDC4);
      case 'shopping': return const Color(0xFFFFE66D);
      case 'entertainment': return const Color(0xFFA855F7);
      case 'health': return const Color(0xFF06D6A0);
      case 'bills': return const Color(0xFFFF9500);
      case 'education': return const Color(0xFF3B82F6);
      default: return const Color(0xFF6366F1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalTransactions = widget.grouped.values.fold(0, (s, l) => s + l.length);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Red gradient header
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.compare_arrows_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Expenses',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '$totalTransactions transactions',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      widget.format(widget.total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Date-grouped list
              Expanded(
                child: widget.sortedKeys.isEmpty
                    ? const Center(
                        child: Text('No expenses yet', style: TextStyle(color: AppColors.textSecondary)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: widget.sortedKeys.length,
                        itemBuilder: (context, index) {
                          final key = widget.sortedKeys[index];
                          final items = widget.grouped[key]!;
                          final dayTotal = items.fold(0.0, (s, e) => s + e.amount);
                          final isExpanded = _expanded.contains(key);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                // Date header row
                                InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => setState(() {
                                    if (isExpanded) {
                                      _expanded.remove(key);
                                    } else {
                                      _expanded.add(key);
                                    }
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFA855F7).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.calendar_today_rounded, color: Color(0xFFA855F7), size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _formatDateKey(key),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                '${items.length} expense${items.length == 1 ? '' : 's'}',
                                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          widget.format(dayTotal),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: Color(0xFFEF4444),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          isExpanded ? Icons.expand_less_rounded : Icons.chevron_right_rounded,
                                          color: AppColors.textSecondary,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Expanded expense list
                                if (isExpanded)
                                  Column(
                                    children: items.map((expense) {
                                      final color = _categoryColor(expense.category);
                                      return Container(
                                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                                        decoration: BoxDecoration(
                                          border: Border(top: BorderSide(color: AppColors.border)),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(_categoryIcon(expense.category), color: color, size: 16),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    expense.note != null && expense.note!.isNotEmpty
                                                        ? expense.note!
                                                        : expense.category[0].toUpperCase() + expense.category.substring(1),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    expense.category[0].toUpperCase() + expense.category.substring(1),
                                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              widget.format(expense.amount),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
