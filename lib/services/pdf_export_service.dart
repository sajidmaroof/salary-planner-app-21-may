import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../data/models/expense.dart';
import '../data/models/user_settings.dart';
import 'pdf_saver_stub.dart'
    if (dart.library.html) 'pdf_saver_web.dart'
    if (dart.library.io) 'pdf_saver_io.dart';

class PdfExportService {
  static const _purple = PdfColor.fromInt(0xFF7C3AED);
  static const _purpleLight = PdfColor.fromInt(0xFFF5F3FF);
  static const _red = PdfColor.fromInt(0xFFEF4444);
  static const _green = PdfColor.fromInt(0xFF22C55E);
  static const _orange = PdfColor.fromInt(0xFFF97316);
  static const _textDark = PdfColor.fromInt(0xFF1E1B4B);
  static const _textGrey = PdfColor.fromInt(0xFF6B7280);
  static const _rowAlt = PdfColor.fromInt(0xFFF8F7FF);

  static Future<void> export({
    required List<Expense> allExpenses,
    required UserSettings settings,
    required DateTime startDate,
    required DateTime endDate,
    required String currencySymbol,
  }) async {
    final filtered = allExpenses
        .where((e) =>
            !e.date.isBefore(DateTime(startDate.year, startDate.month, startDate.day)) &&
            !e.date.isAfter(DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59)))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final grandTotal = filtered.fold(0.0, (s, e) => s + e.amount);
    final available = settings.monthlyIncome - settings.fixedExpenses - settings.savingsGoal;
    final remaining = available - grandTotal;

    String fmt(double v) => '$currencySymbol ${NumberFormat('#,##0').format(v)}';

    // Fixed expense breakdown
    Map<String, double> breakdown = {};
    if (settings.expensesBreakdown != null && settings.expensesBreakdown!.isNotEmpty) {
      final decoded = jsonDecode(settings.expensesBreakdown!) as Map<String, dynamic>;
      breakdown = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => [
          _buildHeader(settings, startDate, endDate),
          pw.SizedBox(height: 0),
          _buildSummary(settings, available, fmt),
          if (breakdown.isNotEmpty) _buildBreakdown(breakdown, currencySymbol),
          pw.SizedBox(height: 16),
          _buildTableSection(filtered, fmt),
        ],
        footer: (ctx) => _buildFooter(filtered.length, grandTotal, remaining, fmt),
      ),
    );

    final bytes = await pdf.save();
    final dateTag = DateFormat('yyyy-MM').format(startDate);
    await savePdf(bytes, 'expense_report_$dateTag.pdf');
  }

  static pw.Widget _buildHeader(UserSettings settings, DateTime start, DateTime end) {
    final fmtDate = DateFormat('d MMM yyyy');
    return pw.Container(
      color: _purple,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('EXPENSE REPORT',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
              pw.SizedBox(height: 4),
              pw.Text('${fmtDate.format(start)}  to  ${fmtDate.format(end)}',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Generated', style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
              pw.Text(fmtDate.format(DateTime.now()),
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummary(UserSettings s, double available, String Function(double) fmt) {
    return pw.Container(
      color: _purpleLight,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      child: pw.Row(
        children: [
          _summaryCell('Monthly Income', fmt(s.monthlyIncome), _green),
          _summaryCell('Fixed Expenses', fmt(s.fixedExpenses), _red),
          _summaryCell('Savings Goal', fmt(s.savingsGoal), _orange),
          _summaryCell('Available', fmt(available), _purple),
        ],
      ),
    );
  }

  static pw.Widget _summaryCell(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _textGrey, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, color: color, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildBreakdown(Map<String, double> breakdown, String symbol) {
    return pw.Container(
      color: _purpleLight,
      padding: const pw.EdgeInsets.fromLTRB(28, 0, 28, 12),
      child: pw.Wrap(
        spacing: 8,
        runSpacing: 4,
        children: breakdown.entries.map((e) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: _purple, width: 0.5),
            ),
            child: pw.Text(
              '${e.key}: $symbol ${NumberFormat('#,##0').format(e.value)}',
              style: pw.TextStyle(fontSize: 8, color: _textDark),
            ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _buildTableSection(List<Expense> expenses, String Function(double) fmt) {
    final dateFormat = DateFormat('dd MMM');

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            color: _purple,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: pw.Row(
              children: [
                pw.Text('EXPENSE DETAILS',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
              ],
            ),
          ),
          // Table header
          pw.Container(
            color: const PdfColor.fromInt(0xFFEDE9FE),
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: pw.Row(
              children: [
                pw.SizedBox(width: 60, child: pw.Text('Date', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _textDark))),
                pw.SizedBox(width: 90, child: pw.Text('Category', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _textDark))),
                pw.Expanded(child: pw.Text('Note', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _textDark))),
                pw.SizedBox(width: 80, child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _textDark))),
              ],
            ),
          ),
          // Rows
          ...expenses.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final cat = e.category.isNotEmpty
                ? e.category[0].toUpperCase() + e.category.substring(1)
                : e.category;
            return pw.Container(
              color: i.isEven ? PdfColors.white : _rowAlt,
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: pw.Row(
                children: [
                  pw.SizedBox(width: 60, child: pw.Text(dateFormat.format(e.date), style: const pw.TextStyle(fontSize: 9, color: _textGrey))),
                  pw.SizedBox(width: 90, child: pw.Text(cat, style: const pw.TextStyle(fontSize: 9, color: _textDark))),
                  pw.Expanded(child: pw.Text(e.note ?? '', style: const pw.TextStyle(fontSize: 9, color: _textGrey))),
                  pw.SizedBox(
                    width: 80,
                    child: pw.Text(fmt(e.amount), textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 9, color: _red, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(int count, double total, double remaining, String Function(double) fmt) {
    return pw.Container(
      color: _purple,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$count transaction${count == 1 ? '' : 's'}',
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
          pw.Row(
            children: [
              pw.Text('Grand Total  ', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
              pw.Text(fmt(total), style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('   Remaining  ', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
              pw.Text(fmt(remaining < 0 ? 0 : remaining),
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
