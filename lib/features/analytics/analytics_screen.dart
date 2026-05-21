import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/expense.dart';
import '../../providers/app_providers.dart';

// ── Category meta ─────────────────────────────────────────────────────────────
const _catColors = {
  'food':          Color(0xFFFF6B6B),
  'transport':     Color(0xFF4ECDC4),
  'shopping':      Color(0xFFFFB347),
  'entertainment': Color(0xFFA855F7),
  'health':        Color(0xFF06D6A0),
  'bills':         Color(0xFFFF9500),
  'education':     Color(0xFF3B82F6),
  'other':         Color(0xFF6366F1),
};

const _catIcons = {
  'food':          Icons.restaurant_rounded,
  'transport':     Icons.directions_car_rounded,
  'shopping':      Icons.shopping_bag_rounded,
  'entertainment': Icons.movie_rounded,
  'health':        Icons.favorite_rounded,
  'bills':         Icons.receipt_long_rounded,
  'education':     Icons.school_rounded,
  'other':         Icons.category_rounded,
};

Color _colorFor(String cat) =>
    _catColors[cat.toLowerCase()] ?? const Color(0xFF6366F1);
IconData _iconFor(String cat) =>
    _catIcons[cat.toLowerCase()] ?? Icons.category_rounded;
String _labelFor(String cat) =>
    cat.isEmpty ? 'Other' : cat[0].toUpperCase() + cat.substring(1);

// ── Period enum ───────────────────────────────────────────────────────────────
enum _Period { thisMonth, lastMonth, allTime }

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  _Period _period = _Period.thisMonth;
  int? _touchedPieIndex;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  List<Expense> _filtered(List<Expense> all) {
    final now = DateTime.now();
    switch (_period) {
      case _Period.thisMonth:
        return all.where((e) =>
            e.date.year == now.year && e.date.month == now.month).toList();
      case _Period.lastMonth:
        final last = DateTime(now.year, now.month - 1);
        return all.where((e) =>
            e.date.year == last.year && e.date.month == last.month).toList();
      case _Period.allTime:
        return List.of(all);
    }
  }

  void _switchPeriod(_Period p) {
    setState(() { _period = p; _touchedPieIndex = null; });
    _animCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(expensesProvider);
    final format = ref.watch(formatCurrencyProvider);
    final stats = ref.watch(dailyStatsProvider);
    final expenses = _filtered(all);

    // ── Aggregations ──────────────────────────────────────────────────────────
    final total = expenses.fold(0.0, (s, e) => s + e.amount);

    // Category totals
    final Map<String, double> byCategory = {};
    for (final e in expenses) {
      final k = e.category.toLowerCase();
      byCategory[k] = (byCategory[k] ?? 0) + e.amount;
    }
    final sortedCats = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Daily totals for bar chart
    final Map<int, double> byDay = {};
    for (final e in expenses) {
      byDay[e.date.day] = (byDay[e.date.day] ?? 0) + e.amount;
    }

    // Summary stats
    final avgPerDay = expenses.isEmpty
        ? 0.0
        : total / (byDay.keys.toSet().length.clamp(1, 31));
    final biggestDay = byDay.isEmpty
        ? 0.0
        : byDay.values.reduce((a, b) => a > b ? a : b);
    final biggestCat = sortedCats.isEmpty ? '' : sortedCats.first.key;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ANALYTICS'),
        leading: const BackButton(),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── Period selector ─────────────────────────────────────────────
            _PeriodSelector(current: _period, onChanged: _switchPeriod),
            const SizedBox(height: 16),

            // ── Summary cards ───────────────────────────────────────────────
            if (expenses.isEmpty)
              _EmptyState(_period)
            else ...[
              _SummaryRow(
                total: total,
                avgPerDay: avgPerDay,
                biggestDay: biggestDay,
                biggestCat: biggestCat,
                format: format,
              ),
              const SizedBox(height: 16),

              // ── Pie chart ─────────────────────────────────────────────────
              _SectionCard(
                title: 'Spending by Category',
                icon: Icons.donut_large_rounded,
                child: _PieSection(
                  byCategory: byCategory,
                  total: total,
                  format: format,
                  touched: _touchedPieIndex,
                  onTouch: (i) => setState(() => _touchedPieIndex = i),
                ),
              ),
              const SizedBox(height: 16),

              // ── Bar chart ─────────────────────────────────────────────────
              _SectionCard(
                title: 'Daily Spending Trend',
                icon: Icons.bar_chart_rounded,
                child: _BarSection(byDay: byDay, format: format, period: _period),
              ),
              const SizedBox(height: 16),

              // ── Category breakdown list ────────────────────────────────────
              _SectionCard(
                title: 'Category Breakdown',
                icon: Icons.list_alt_rounded,
                child: _CategoryList(sortedCats: sortedCats, total: total, format: format),
              ),
              const SizedBox(height: 16),

              // ── Top 5 expenses ─────────────────────────────────────────────
              _SectionCard(
                title: 'Top Expenses',
                icon: Icons.trending_up_rounded,
                child: _TopExpenses(expenses: expenses, format: format),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Period selector ───────────────────────────────────────────────────────────
class _PeriodSelector extends StatelessWidget {
  final _Period current;
  final void Function(_Period) onChanged;
  const _PeriodSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _tab('This Month', _Period.thisMonth),
          _tab('Last Month', _Period.lastMonth),
          _tab('All Time', _Period.allTime),
        ],
      ),
    );
  }

  Widget _tab(String label, _Period p) {
    final active = current == p;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final double total, avgPerDay, biggestDay;
  final String biggestCat;
  final String Function(double) format;
  const _SummaryRow({
    required this.total, required this.avgPerDay,
    required this.biggestDay, required this.biggestCat, required this.format,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(label: 'Total Spent', value: format(total),
            icon: Icons.payments_rounded, color: const Color(0xFFEF4444)),
        const SizedBox(width: 10),
        _StatCard(label: 'Avg / Day', value: format(avgPerDay),
            icon: Icons.today_rounded, color: const Color(0xFF6366F1)),
        const SizedBox(width: 10),
        _StatCard(label: 'Biggest Day', value: format(biggestDay),
            icon: Icons.local_fire_department_rounded, color: const Color(0xFFFF9500)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Section card wrapper ──────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Pie chart section ─────────────────────────────────────────────────────────
class _PieSection extends StatelessWidget {
  final Map<String, double> byCategory;
  final double total;
  final String Function(double) format;
  final int? touched;
  final void Function(int?) onTouch;
  const _PieSection({required this.byCategory, required this.total,
      required this.format, required this.touched, required this.onTouch});

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions ||
                      response == null ||
                      response.touchedSection == null) {
                    onTouch(null);
                    return;
                  }
                  onTouch(response.touchedSection!.touchedSectionIndex);
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 3,
              centerSpaceRadius: 50,
              sections: entries.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final isTouched = i == touched;
                final pct = total > 0 ? (e.value / total * 100) : 0.0;
                return PieChartSectionData(
                  color: _colorFor(e.key),
                  value: e.value,
                  title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
                  radius: isTouched ? 70 : 58,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                  badgeWidget: isTouched
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _colorFor(e.key),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(format(e.value),
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
                        )
                      : null,
                  badgePositionPercentageOffset: 1.3,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: entries.map((e) {
            final pct = total > 0 ? (e.value / total * 100) : 0.0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: _colorFor(e.key), shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('${_labelFor(e.key)} ${pct.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Bar chart section ─────────────────────────────────────────────────────────
class _BarSection extends StatelessWidget {
  final Map<int, double> byDay;
  final String Function(double) format;
  final _Period period;
  const _BarSection({required this.byDay, required this.format, required this.period});

  @override
  Widget build(BuildContext context) {
    if (byDay.isEmpty) {
      return const SizedBox(height: 120, child: Center(
        child: Text('No data', style: TextStyle(color: AppColors.textSecondary)),
      ));
    }

    final days = byDay.keys.toList()..sort();
    final maxVal = byDay.values.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.3,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: AppColors.primary,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  format(rod.toY),
                  const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final day = val.toInt();
                  if (!days.contains(day)) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('$day', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                  );
                },
                reservedSize: 20,
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxVal / 3,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 0.8),
          ),
          borderData: FlBorderData(show: false),
          barGroups: days.map((day) {
            final val = byDay[day] ?? 0;
            final pct = maxVal > 0 ? val / maxVal : 0.0;
            return BarChartGroupData(
              x: day,
              barRods: [
                BarChartRodData(
                  toY: val,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(const Color(0xFF6366F1), const Color(0xFFEF4444), pct)!,
                      Color.lerp(const Color(0xFF818CF8), const Color(0xFFFF6B6B), pct)!,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Category breakdown list ───────────────────────────────────────────────────
class _CategoryList extends StatelessWidget {
  final List<MapEntry<String, double>> sortedCats;
  final double total;
  final String Function(double) format;
  const _CategoryList({required this.sortedCats, required this.total, required this.format});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: sortedCats.map((e) {
        final pct = total > 0 ? e.value / total : 0.0;
        final color = _colorFor(e.key);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Icon(_iconFor(e.key), color: color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_labelFor(e.key),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ),
                  Text(format(e.value),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                  const SizedBox(width: 8),
                  Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Top 5 expenses ────────────────────────────────────────────────────────────
class _TopExpenses extends StatelessWidget {
  final List<Expense> expenses;
  final String Function(double) format;
  const _TopExpenses({required this.expenses, required this.format});

  @override
  Widget build(BuildContext context) {
    final top = List.of(expenses)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final shown = top.take(5).toList();

    return Column(
      children: shown.asMap().entries.map((entry) {
        final i = entry.key;
        final e = entry.value;
        final color = _colorFor(e.category);
        final medals = ['🥇', '🥈', '🥉', '4.', '5.'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(medals[i],
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
                child: Icon(_iconFor(e.category), color: color, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.note != null && e.note!.isNotEmpty ? e.note! : _labelFor(e.category),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      DateFormat('d MMM yyyy').format(e.date),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(format(e.amount),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final _Period period;
  const _EmptyState(this.period);

  @override
  Widget build(BuildContext context) {
    final label = period == _Period.thisMonth
        ? 'this month'
        : period == _Period.lastMonth
            ? 'last month'
            : 'any period';
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 16),
          Text('No expenses $label',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Add expenses to see your analytics',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
