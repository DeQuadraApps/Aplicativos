// lib/widgets/goal_progress_card.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/models/goal.model.dart';

class GoalProgressCard extends StatefulWidget {
  final SalesGoal goal;
  final String institutionId;

  const GoalProgressCard({
    super.key,
    required this.goal,
    required this.institutionId,
  });

  @override
  State<GoalProgressCard> createState() => _GoalProgressCardState();
}

class _GoalProgressCardState extends State<GoalProgressCard> {
  late Future<double> _totalSoldFuture;

  @override
  void initState() {
    super.initState();
    _totalSoldFuture = _fetchTotalSold();
  }

  Future<double> _fetchTotalSold() async {
    try {
      final salesSnapshot = await FirebaseFirestore.instance
          .collection('institutions').doc(widget.institutionId)
          .collection('sales')
          .where('userId', isEqualTo: widget.goal.salespersonId)
          .where('saleDate', isGreaterThanOrEqualTo: DateTime(widget.goal.year, widget.goal.month, 1))
          .where('saleDate', isLessThan: DateTime(widget.goal.year, widget.goal.month + 1, 1))
          .get();

      if (salesSnapshot.docs.isEmpty) {
        return 0.0;
      }
      return salesSnapshot.docs
          .map((doc) => (doc.data()['totalAmount'] as num? ?? 0).toDouble())
          .reduce((a, b) => a + b);

    } catch (e) {
      // +++ ESTA É A MUDANÇA IMPORTANTE +++
      // Imprime o erro detalhado no console para que possamos ver o link do índice.
      debugPrint("================================================================");
      debugPrint("ERRO AO BUSCAR VENDAS! COPIE O LINK DO ÍNDICE ABAIXO:");
      debugPrint("$e");
      debugPrint("================================================================");
      // Lança o erro novamente para que o FutureBuilder o possa apanhar.
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _totalSoldFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ListTile(title: Text("A carregar progresso..."), leading: CircularProgressIndicator()),
          );
        }
        // Exibe a barra vermelha com o erro
        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.red.shade50,
            child: const ListTile(
                title: Text("Falha ao carregar progresso"),
                subtitle: Text("Verifique o console de depuração para o link do índice."),
                leading: Icon(Icons.error, color: Colors.red)),
          );
        }

        final totalSold = snapshot.data ?? 0.0;
        final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
        final monthYearFormat = DateFormat('MMMM \'de\' yyyy', 'pt_BR');
        final progress = widget.goal.amount > 0 ? (totalSold / widget.goal.amount).clamp(0.0, 1.0) : 0.0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthYearFormat.format(DateTime(widget.goal.year, widget.goal.month)),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Vendido:'),
                    Text(currencyFormatter.format(totalSold), style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Meta:'),
                    Text(currencyFormatter.format(widget.goal.amount), style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
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
      },
    );
  }
}