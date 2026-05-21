import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/auth/app_auth_notifier.dart';
import '../../data/models/user_settings.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_service.dart';

import '../../data/models/currency.dart';

class SetupWizardScreen extends ConsumerStatefulWidget {
  final bool editMode;
  const SetupWizardScreen({Key? key, this.editMode = false}) : super(key: key);

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _salaryController = TextEditingController();
  final _savingsController = TextEditingController();
  String _selectedCurrency = 'PKR';
  final Map<String, TextEditingController> _expenseControllers = {
    'Rent/Mortgage': TextEditingController(),
    'Utilities & Bills': TextEditingController(),
    'Food & Groceries': TextEditingController(),
    'Transport/Fuel': TextEditingController(),
    'Other Fixed': TextEditingController(),
  };
  DateTime? _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(userSettingsProvider);
      if (settings != null) {
        setState(() {
          _salaryController.text = settings.monthlyIncome.toString();
          _savingsController.text = settings.savingsGoal.toString();
          _selectedCurrency = settings.currencyCode;
          _selectedDate = settings.nextSalaryDate;
          if (settings.expensesBreakdown != null) {
            final saved = (jsonDecode(settings.expensesBreakdown!) as Map)
                .map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
            for (final entry in _expenseControllers.entries) {
              final v = saved[entry.key] ?? 0.0;
              entry.value.text = v > 0 ? v.toStringAsFixed(0) : '';
            }
          } else {
            _expenseControllers['Other Fixed']!.text =
                settings.fixedExpenses.toStringAsFixed(0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _salaryController.dispose();
    for (var controller in _expenseControllers.values) {
      controller.dispose();
    }
    _savingsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 15)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveSettings() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your next salary date')),
      );
      return;
    }

    setState(() => _isSaving = true);

    double totalFixed = 0.0;
    final breakdown = <String, double>{};

    final existing = ref.read(userSettingsProvider)?.expensesBreakdown;
    if (existing != null) {
      final savedMap = (jsonDecode(existing) as Map)
          .map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      for (final entry in savedMap.entries) {
        if (!_expenseControllers.containsKey(entry.key)) {
          breakdown[entry.key] = entry.value;
          totalFixed += entry.value;
        }
      }
    }

    for (final entry in _expenseControllers.entries) {
      final val = double.tryParse(entry.value.text) ?? 0.0;
      if (val > 0) {
        breakdown[entry.key] = val;
        totalFixed += val;
      }
    }

    final monthlyIncome = double.parse(_salaryController.text);
    final savingsGoal = _savingsController.text.isEmpty
        ? 5000.0
        : double.parse(_savingsController.text);
    final breakdownJson = breakdown.isNotEmpty ? jsonEncode(breakdown) : null;

    final settings = UserSettings(
      monthlyIncome: monthlyIncome,
      nextSalaryDate: _selectedDate!,
      fixedExpenses: totalFixed,
      savingsGoal: savingsGoal,
      currencyCode: _selectedCurrency,
      expensesBreakdown: breakdownJson,
    );

    // Save locally first.
    final box = ref.read(userSettingsBoxProvider);
    await box.put('settings', settings);
    ref.read(userSettingsProvider.notifier).state = settings;
    ref.read(currencyCodeProvider.notifier).state = _selectedCurrency;
    ref.invalidate(expensesProvider);
    ref.invalidate(todaysExpensesProvider);
    ref.invalidate(dailyStatsProvider);

    // Save to Firestore in the background (non-blocking).
    FirestoreService.saveUserSetup(
      monthlyIncome: monthlyIncome,
      nextSalaryDate: _selectedDate!,
      fixedExpenses: totalFixed,
      savingsGoal: savingsGoal,
      currencyCode: _selectedCurrency,
      expensesBreakdown: breakdownJson,
    ).catchError((_) {});

    if (widget.editMode) {
      // Return to settings — setup was already complete, no redirect needed.
      if (mounted) context.pop();
    } else {
      // First-time setup — trigger router redirect to /dashboard.
      appAuthNotifier.markSetupComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.editMode ? 'EDIT BUDGET' : 'SETUP BUDGET')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Income Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _salaryController,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'MONTHLY INCOME',
                  prefixIcon: Icon(Icons.account_balance_rounded, size: 20),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Please enter your salary' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedCurrency,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'SELECT CURRENCY',
                  prefixIcon: Icon(Icons.payments_rounded, size: 20),
                ),
                items: AppCurrency.supportedCurrencies.map((currency) {
                  return DropdownMenuItem(
                    value: currency.code,
                    child: Text(currency.name),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCurrency = value);
                  }
                },
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _selectedDate == null
                              ? 'NEXT SALARY DATE'
                              : 'PAYDAY: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                          style: TextStyle(
                            color: _selectedDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary, size: 28),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Text(
                'Fixed Monthly Expenses',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bills and costs deducted automatically.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              ..._expenseControllers.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: TextFormField(
                    controller: entry.value,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: entry.key.toUpperCase(),
                      prefixIcon: const Icon(Icons.receipt_long_rounded, size: 20),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                );
              }).toList(),
              const SizedBox(height: 4),
              TextFormField(
                controller: _savingsController,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'SAVINGS GOAL (OPTIONAL)',
                  prefixIcon: Icon(Icons.savings_rounded, size: 20),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 60),
              Container(
                height: 64,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'COMPLETE SETUP',
                          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
