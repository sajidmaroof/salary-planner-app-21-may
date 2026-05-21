import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import '../data/models/expense.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>>? _expensesCol() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('expenses');
  }

  // ── User setup ────────────────────────────────────────────────────────────
  static Future<void> saveUserSetup({
    required double monthlyIncome,
    required DateTime nextSalaryDate,
    required double fixedExpenses,
    required double savingsGoal,
    required String currencyCode,
    String? expensesBreakdown,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'monthlyIncome': monthlyIncome,
      'nextSalaryDate': Timestamp.fromDate(nextSalaryDate),
      'fixedExpenses': fixedExpenses,
      'savingsGoal': savingsGoal,
      'currencyCode': currencyCode,
      'expensesBreakdown': expensesBreakdown,
      'setupComplete': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  static Future<void> clearUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).delete();
  }

  // ── Expense CRUD ─────────────────────────────────────────────────────────

  /// Save a new expense to Firestore and return the document ID.
  static Future<String?> addExpense(Expense expense) async {
    final col = _expensesCol();
    if (col == null) return null;
    final doc = await col.add({
      'amount': expense.amount,
      'category': expense.category,
      'date': Timestamp.fromDate(expense.date),
      'note': expense.note,
    });
    return doc.id;
  }

  /// Update an existing expense in Firestore using its document ID (= Hive key).
  static Future<void> updateExpense(String docId, Expense expense) async {
    final col = _expensesCol();
    if (col == null) return;
    await col.doc(docId).set({
      'amount': expense.amount,
      'category': expense.category,
      'date': Timestamp.fromDate(expense.date),
      'note': expense.note,
    });
  }

  /// Delete an expense from Firestore by document ID (= Hive key).
  static Future<void> deleteExpense(String docId) async {
    final col = _expensesCol();
    if (col == null) return;
    await col.doc(docId).delete();
  }

  /// Sync expenses between Hive and Firestore:
  /// 1. Push any locally-saved (offline) Hive items to Firestore.
  /// 2. Repopulate Hive from Firestore so all devices stay consistent.
  static Future<void> syncExpensesToHive(Box<Expense> box) async {
    final col = _expensesCol();
    if (col == null) return;
    try {
      final snapshot = await col.get().timeout(const Duration(seconds: 10));
      final firestoreIds = {for (final d in snapshot.docs) d.id};

      // Upload locally-saved expenses whose key is not a Firestore doc ID
      for (final key in box.keys.toList()) {
        if (!firestoreIds.contains(key.toString())) {
          final expense = box.get(key);
          if (expense == null) continue;
          try {
            final docRef = await col.add({
              'amount': expense.amount,
              'category': expense.category,
              'date': Timestamp.fromDate(expense.date),
              'note': expense.note,
            });
            firestoreIds.add(docRef.id);
            await box.delete(key);
            await box.put(docRef.id, expense);
          } catch (_) {}
        }
      }

      // Repopulate Hive from Firestore (now contains all items)
      final fresh = await col.get().timeout(const Duration(seconds: 10));
      await box.clear();
      for (final doc in fresh.docs) {
        final data = doc.data();
        final expense = Expense(
          amount: (data['amount'] as num).toDouble(),
          category: (data['category'] as String? ?? 'other'),
          date: (data['date'] as Timestamp).toDate(),
          note: data['note'] as String?,
        );
        await box.put(doc.id, expense);
      }
    } catch (_) {
      // If sync fails, keep existing local data untouched
    }
  }
}
