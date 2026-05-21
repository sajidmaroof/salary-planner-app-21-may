import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_providers.dart';

class DailyBudgetCard extends ConsumerWidget {
  final double dailyLimit;
  final double spentToday;
  final double remainingToday;

  const DailyBudgetCard({
    Key? key,
    required this.dailyLimit,
    required this.spentToday,
    required this.remainingToday,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(formatCurrencyProvider);
    final double percentageSpent = dailyLimit > 0 ? (spentToday / dailyLimit).clamp(0.0, 1.0) : 1.0;
    final bool isOverBudget = remainingToday < 0 || spentToday > dailyLimit;

    // UI Requirements: Blue (#6366f1) under limit, Red (#ef4444) over limit
    final Color statusColor = isOverBudget ? const Color(0xFFEF4444) : const Color(0xFF6366F1);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.flash_on_rounded, color: statusColor, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'SAFE TO SPEND TODAY',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            format(isOverBudget && remainingToday < 0 ? 0 : (remainingToday > 0 ? remainingToday : 0)),
            style: const TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 36),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentageSpent,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                label: 'DAILY LIMIT',
                value: format(dailyLimit),
                icon: Icons.track_changes_rounded,
              ),
              _StatItem(
                label: 'SPENT',
                value: format(spentToday),
                icon: Icons.shopping_bag_rounded,
                valueColor: isOverOverLimit(spentToday, dailyLimit) ? const Color(0xFFEF4444) : AppColors.textPrimary,
                crossAxisAlignment: CrossAxisAlignment.end,
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool isOverOverLimit(double spent, double limit) => spent > limit;
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final CrossAxisAlignment crossAxisAlignment;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
