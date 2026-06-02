import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/expense.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_service.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedCategory = 'FOOD';
  DateTime _selectedDate = DateTime.now();

  final List<String> _categories = [
    'FOOD', 'TRANSPORT', 'BILLS', 'SHOPPING', 'OTHER'
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // Earliest selectable = start of current salary cycle (1st of current month)
    final cycleStart = DateTime(now.year, now.month, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: cycleStart,
      lastDate: now,
      helpText: 'SELECT EXPENSE DATE',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveExpense() async {
    if (_amountController.text.isEmpty) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    final expense = Expense(
      amount: amount,
      category: _selectedCategory.toLowerCase(),
      date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day,
          DateTime.now().hour, DateTime.now().minute),
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );

    final box = ref.read(expensesBoxProvider);
    try {
      final docId = await FirestoreService.addExpense(expense);
      if (docId != null) {
        await box.put(docId, expense);
      } else {
        await box.add(expense);
      }
    } catch (_) {
      // Firestore unavailable — save locally so data is never lost
      await box.add(expense);
    }

    if (mounted) {
      ref.invalidate(expensesProvider);
      if (context.canPop()) context.pop(); else context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = ref.watch(currencySymbolProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('ADD EXPENSE')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Text(
              'Enter Amount',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'AMOUNT',
                prefixIcon: const Icon(Icons.payments_rounded, size: 20),
                prefixText: currencySymbol,
                prefixStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -1,
              ),
              autofocus: true,
            ),
            const SizedBox(height: 24),
            // Date picker
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EXPENSE DATE',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateUtils.isSameDay(_selectedDate, DateTime.now())
                                ? 'Today, ${DateFormat('d MMM yyyy').format(_selectedDate)}'
                                : DateFormat('EEEE, d MMM yyyy').format(_selectedDate),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_calendar_rounded,
                        color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                labelText: 'CATEGORY',
                prefixIcon: Icon(Icons.category_rounded, size: 20),
              ),
              items: _categories.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text(c.toUpperCase()),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _noteController,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: _selectedCategory == 'FOOD' ? 'WHAT DID YOU EAT? (e.g. fruits)' : 'NOTE (OPTIONAL)',
                prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                hintText: _selectedCategory == 'FOOD' ? 'e.g. fruits, grocery' : null,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 80),
            Container(
              height: 64,
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
                onPressed: _saveExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                ),
                child: const Text(
                  'SAVE EXPENSE',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
