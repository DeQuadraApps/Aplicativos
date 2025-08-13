// lib/widgets/goal_progress_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/models/goal.model.dart';

class GoalProgressCard extends StatelessWidget {
  final SalesGoal goal;
  final double totalSold;

  const GoalProgressCard({
    super.key,
    required this.goal,
    required this.totalSold,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final progress = goal.amount > 0 ? (totalSold / goal.amount).clamp(0.0, 1.0) : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meta de Vendas (Este Mês)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Vendido:'),
                Text(
                  currencyFormatter.format(totalSold),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.green.shade700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Meta:'),
                Text(
                  currencyFormatter.format(goal.amount),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.grey.shade300,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text('${(progress * 100).toStringAsFixed(1)}% Atingido'),
            )
          ],
        ),
      ),
    );
  }
}