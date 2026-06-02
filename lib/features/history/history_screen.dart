import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/expense.dart';
import '../../data/models/monthly_report.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_service.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

const _kCategories = [
  'food', 'transport', 'shopping', 'entertainment',
  'health', 'bills', 'education', 'other'
];

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late DateTime _focusedMonth;
  DateTime? _selectedDate;
  bool _showReports = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _prevMonth() => setState(() {
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
        _selectedDate = null;
      });

  void _nextMonth() => setState(() {
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
        _selectedDate = null;
      });

  // Returns Map<day, total> for the focused month
  Map<int, double> _buildDayTotals(List<Expense> expenses) {
    final totals = <int, double>{};
    for (final e in expenses) {
      if (e.date.year == _focusedMonth.year &&
          e.date.month == _focusedMonth.month) {
        totals[e.date.day] = (totals[e.date.day] ?? 0) + e.amount;
      }
    }
    return totals;
  }

  List<Expense> _expensesForDay(List<Expense> all, DateTime day) {
    return all
        .where((e) =>
            e.date.year == day.year &&
            e.date.month == day.month &&
            e.date.day == day.day)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void _showAddExpenseDialog(BuildContext sheetCtx, DateTime day, StateSetter setSheetState) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedCategory = 'food';

    showModalBottomSheet(
      context: sheetCtx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Add Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        Text(DateFormat('EEEE, d MMMM yyyy').format(day), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'AMOUNT',
                    prefixIcon: const Icon(Icons.payments_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'CATEGORY',
                    prefixIcon: const Icon(Icons.category_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                  items: _kCategories.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c[0].toUpperCase() + c.substring(1)),
                  )).toList(),
                  onChanged: (v) { if (v != null) setDialogState(() => selectedCategory = v); },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'NOTE (OPTIONAL)',
                    prefixIcon: const Icon(Icons.notes_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text.trim());
                      if (amount == null || amount <= 0) return;
                      final now = DateTime.now();
                      final expense = Expense(
                        amount: amount,
                        category: selectedCategory,
                        date: DateTime(day.year, day.month, day.day, now.hour, now.minute),
                        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                      );
                      final box = ref.read(expensesBoxProvider);
                      await box.add(expense);
                      ref.invalidate(expensesProvider);
                      if (ctx.mounted) Navigator.pop(ctx);
                      setSheetState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text('SAVE EXPENSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditExpenseDialog(BuildContext sheetCtx, Expense expense, StateSetter setSheetState) {
    final amountCtrl = TextEditingController(text: expense.amount.toStringAsFixed(expense.amount.truncateToDouble() == expense.amount ? 0 : 2));
    final noteCtrl = TextEditingController(text: expense.note ?? '');
    String selectedCategory = _kCategories.contains(expense.category.toLowerCase()) ? expense.category.toLowerCase() : 'other';

    showModalBottomSheet(
      context: sheetCtx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Edit Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        Text(DateFormat('EEEE, d MMMM yyyy').format(expense.date), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'AMOUNT',
                    prefixIcon: const Icon(Icons.payments_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'CATEGORY',
                    prefixIcon: const Icon(Icons.category_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                  items: _kCategories.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c[0].toUpperCase() + c.substring(1)),
                  )).toList(),
                  onChanged: (v) { if (v != null) setDialogState(() => selectedCategory = v); },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'NOTE (OPTIONAL)',
                    prefixIcon: const Icon(Icons.notes_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text.trim());
                      if (amount == null || amount <= 0) return;
                      expense.amount = amount;
                      expense.category = selectedCategory;
                      expense.note = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();
                      await expense.save();
                      // Sync edit to Firestore
                      final key = expense.key?.toString();
                      if (key != null) await FirestoreService.updateExpense(key, expense);
                      ref.invalidate(expensesProvider);
                      if (ctx.mounted) Navigator.pop(ctx);
                      setSheetState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteExpenseFromSheet(BuildContext ctx, Expense expense, StateSetter setSheetState) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Expense?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('This expense will be permanently removed.'),
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
    final key = expense.key?.toString();
    await expense.delete();
    if (key != null) await FirestoreService.deleteExpense(key);
    ref.invalidate(expensesProvider);
    setSheetState(() {});
  }

  void _showDaySheet(BuildContext context, DateTime day, List<Expense> all) {
    final format = ref.read(formatCurrencyProvider);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final dayDate = DateTime(day.year, day.month, day.day);
    final canAdd = !dayDate.isAfter(today);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final items = _expensesForDay(ref.read(expensesProvider), day);
          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.9,
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('EEEE, d MMMM yyyy').format(day),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                            Text('${items.length} expense${items.length != 1 ? 's' : ''}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                        const Spacer(),
                        if (items.isNotEmpty)
                          Text(format(items.fold(0.0, (s, e) => s + e.amount)),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.danger)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textSecondary.withOpacity(0.3)),
                                const SizedBox(height: 12),
                                const Text('No expenses on this day', style: TextStyle(color: AppColors.textSecondary)),
                                if (canAdd) ...[
                                  const SizedBox(height: 6),
                                  const Text('Tap below to add one', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final exp = items[i];
                              final capturedExp = exp;
                              final cat = exp.category.isNotEmpty
                                  ? exp.category[0].toUpperCase() + exp.category.substring(1).toLowerCase()
                                  : 'Other';
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.receipt_rounded, color: AppColors.primary, size: 18),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(cat, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                                          if (exp.note != null && exp.note!.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(exp.note!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Text(format(exp.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.danger)),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTapDown: (TapDownDetails details) async {
                                        final RenderBox overlay = Overlay.of(ctx).context.findRenderObject()! as RenderBox;
                                        final result = await showMenu<String>(
                                          context: ctx,
                                          position: RelativeRect.fromRect(
                                            details.globalPosition & const Size(1, 1),
                                            Offset.zero & overlay.size,
                                          ),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          items: [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Row(children: [
                                                const Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                                                const SizedBox(width: 10),
                                                const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
                                              ]),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Row(children: [
                                                const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                                                const SizedBox(width: 10),
                                                Text('Delete', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                                              ]),
                                            ),
                                          ],
                                        );
                                        if (result == 'edit') _showEditExpenseDialog(ctx, capturedExp, setSheetState);
                                        if (result == 'delete') _deleteExpenseFromSheet(ctx, capturedExp, setSheetState);
                                      },
                                      child: Container(
                                        width: 32, height: 32,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(9),
                                        ),
                                        child: const Icon(Icons.more_vert_rounded, color: AppColors.primary, size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  if (canAdd)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddExpenseDialog(ctx, day, setSheetState),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary, elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.add_rounded, color: Colors.white),
                          label: const Text('ADD EXPENSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        ),
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

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider);
    final format = ref.watch(formatCurrencyProvider);
    final settings = ref.watch(userSettingsProvider);
    final reports = ref.watch(monthlyReportsProvider);

    final dayTotals = _buildDayTotals(expenses);

    // Monthly summary
    final monthlySpent = dayTotals.values.fold(0.0, (a, b) => a + b);
    final monthlyIncome = settings?.monthlyIncome ?? 0.0;
    final monthlyBalance = monthlyIncome - monthlySpent;

    // Calendar math
    final daysInMonth =
        DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstWeekday =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7;
    final totalCells = firstWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    const weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('HISTORY')),
      body: Column(
        children: [
          // Tab toggle: Calendar / Reports
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showReports = false),
                    child: Container(
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !_showReports
                            ? AppColors.primary
                            : AppColors.background,
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(10)),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month_rounded,
                              size: 15,
                              color: !_showReports
                                  ? Colors.white
                                  : AppColors.primary),
                          const SizedBox(width: 6),
                          Text('CALENDAR',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: !_showReports
                                      ? Colors.white
                                      : AppColors.primary,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showReports = true),
                    child: Container(
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _showReports
                            ? AppColors.primary
                            : AppColors.background,
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(10)),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bar_chart_rounded,
                              size: 15,
                              color: _showReports
                                  ? Colors.white
                                  : AppColors.primary),
                          const SizedBox(width: 6),
                          Text('REPORTS',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _showReports
                                      ? Colors.white
                                      : AppColors.primary,
                                  letterSpacing: 0.5)),
                          if (reports.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _showReports
                                    ? Colors.white.withOpacity(0.3)
                                    : AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${reports.length}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: _showReports
                                          ? Colors.white
                                          : AppColors.primary)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_showReports)
            Expanded(child: _buildReportsView(reports, format))
          else ...[
          // Month navigation header
          Container(
            color: AppColors.surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _prevMonth,
                  icon: const Icon(Icons.chevron_left_rounded,
                      color: AppColors.primary, size: 28),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.primary, size: 28),
                ),
              ],
            ),
          ),

          // Weekday labels
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: weekdays
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: (d == 'SUN' || d == 'SAT')
                                  ? AppColors.danger
                                  : AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Calendar grid
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                border: TableBorder.all(
                    color: AppColors.border.withOpacity(0.6), width: 0.5),
                children: List.generate(rowCount, (row) {
                  return TableRow(
                    children: List.generate(7, (col) {
                      final cellIndex = row * 7 + col;
                      final dayNumber = cellIndex - firstWeekday + 1;
                      final isValid =
                          dayNumber >= 1 && dayNumber <= daysInMonth;

                      if (!isValid) {
                        return Container(
                          height: 72,
                          color: const Color(0xFFF5F5F5),
                        );
                      }

                      final cellDate = DateTime(
                          _focusedMonth.year, _focusedMonth.month, dayNumber);
                      final isToday = DateUtils.isSameDay(
                          cellDate, DateTime.now());
                      final isSelected =
                          _selectedDate != null &&
                              DateUtils.isSameDay(cellDate, _selectedDate!);
                      final total = dayTotals[dayNumber];
                      final isSunday = col == 0;
                      final isSaturday = col == 6;

                      return GestureDetector(
                        onTap: () {
                          setState(
                              () => _selectedDate = cellDate);
                          _showDaySheet(context, cellDate, expenses);
                        },
                        child: Container(
                          height: 72,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.08)
                                : AppColors.surface,
                            border: isSelected
                                ? Border.all(
                                    color: AppColors.primary, width: 2)
                                : null,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Day number
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: isToday
                                    ? BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      )
                                    : null,
                                child: Text(
                                  '$dayNumber',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isToday
                                        ? Colors.white
                                        : (isSunday || isSaturday)
                                            ? AppColors.danger
                                            : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Daily total
                              if (total != null && total > 0)
                                Center(
                                  child: Text(
                                    format(total),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.danger,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              const SizedBox(height: 2),
                            ],
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
          ),

          // Bottom summary bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                _SummaryChip(
                  label: 'BALANCE',
                  value: format(monthlyBalance),
                  color: monthlyBalance >= 0
                      ? AppColors.success
                      : AppColors.danger,
                ),
                _Divider(),
                _SummaryChip(
                  label: 'INCOME',
                  value: format(monthlyIncome),
                  color: AppColors.success,
                ),
                _Divider(),
                _SummaryChip(
                  label: 'EXPENSE',
                  value: format(monthlySpent),
                  color: AppColors.danger,
                ),
              ],
            ),
          ),
          ], // end of calendar section
        ],
      ),
    );
  }

  Widget _buildReportsView(
      List<MonthlyReport> reports, String Function(double) format) {
    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('No monthly reports yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            const Text('Reports are generated automatically\nat the start of each new salary cycle.',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      itemBuilder: (_, i) {
        final r = reports[i];
        final monthName =
            DateFormat('MMMM yyyy').format(DateTime(r.year, r.month));
        final spent = r.totalSpent;
        final budget = r.effectiveBudget - r.fixedExpenses - r.savingsGoal;
        final remaining = r.remainingBalance;
        final spentPct = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
        final isOver = remaining < 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.08),
                      AppColors.primary.withOpacity(0.03),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(17)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.calendar_month_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(monthName,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary)),
                          Text(
                            '${DateFormat('d MMM').format(r.cycleStart)} – ${DateFormat('d MMM yyyy').format(r.cycleEnd)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (r.carriedForward)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+ ${format(r.carryForwardAmount)} carried',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success),
                        ),
                      ),
                  ],
                ),
              ),

              // Stats row
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Row(
                  children: [
                    _ReportStat(
                        label: 'BUDGET',
                        value: format(budget),
                        color: AppColors.primary),
                    _ReportStat(
                        label: 'SPENT',
                        value: format(spent),
                        color: AppColors.danger),
                    _ReportStat(
                        label: 'SAVED',
                        value: format(remaining.abs()),
                        color: isOver ? AppColors.danger : AppColors.success,
                        prefix: isOver ? '-' : '+'),
                  ],
                ),
              ),

              // Spend progress bar
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isOver
                              ? 'Over budget by ${format(remaining.abs())}'
                              : '${(spentPct * 100).toStringAsFixed(0)}% of budget used',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isOver
                                  ? AppColors.danger
                                  : AppColors.textSecondary),
                        ),
                        if (r.carryForwardAmount > 0 && !r.carriedForward)
                          Text('Balance not carried forward',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary
                                      .withOpacity(0.7))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: spentPct,
                        minHeight: 6,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation(
                            isOver ? AppColors.danger : AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color)),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 32, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 8));
  }
}

class _ReportStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String prefix;

  const _ReportStat(
      {required this.label,
      required this.value,
      required this.color,
      this.prefix = ''});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('$prefix$value',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color)),
          ),
        ],
      ),
    );
  }
}
