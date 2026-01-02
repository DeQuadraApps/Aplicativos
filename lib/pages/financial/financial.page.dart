// MANTENHA SEUS IMPORTS
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/models/transaction.model.dart';
import 'package:quadra_vendas/services/financial_csv.service.dart';
import 'package:quadra_vendas/services/financial_pdf.service.dart';
import 'package:quadra_vendas/services/subscription.service.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';
import 'package:quadra_vendas/widgets/transaction-form-dialog.dart';
// ADICIONE ESTE IMPORT:

class FinancialPage extends StatefulWidget {
  final Map<String, dynamic> institutionData;

  const FinancialPage({super.key, required this.institutionData});

  @override
  State<FinancialPage> createState() => _FinancialPageState();
}

class _FinancialPageState extends State<FinancialPage> {
  late DateTime _selectedDate;
  String _selectedCategory = 'Todas';
  bool _showChart = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, 1);
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + monthsToAdd, 1);
      _selectedCategory = 'Todas';
    });
  }

  // Função auxiliar para chamar o PDF
  void _printReport(List<FinTransaction> transactions) {
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nada para imprimir.")));
      return;
    }

    // Pega o nome da instituição que vem no widget.institutionData
    // Se não tiver nome, usa um padrão.
    final String nomeEmpresa = widget.institutionData['name'] ?? 'Minha Empresa';

    FinancialPdfService().generateAndPrint(
        transactions,
        _selectedDate,
        nomeEmpresa // <--- Passando o nome aqui
    );
  }

  void _exportCsv(List<FinTransaction> transactions) {
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nada para exportar.")));
      return;
    }
    FinancialCsvService().generateAndExport(transactions);
  }

  Widget _buildLockedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
              child: Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            Text("Funcionalidade Premium", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text("O controle financeiro é exclusivo do plano Elite.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => AppSnackBar.showInfo(context, message: "Entre em contato com o suporte."),
              child: const Text("Fazer Upgrade Agora"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subService = SubscriptionService(widget.institutionData);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canAccess = subService.canAccessFinancialModule;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Gestão Financeira'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.background,
        // (Opcional) Poderia ter o botão aqui, mas vamos colocar perto do mês
      ),
      body: canAccess
          ? _buildFinancialContent(theme, colorScheme)
          : _buildLockedScreen(),
      floatingActionButton: canAccess
          ? FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => showDialog(
          context: context,
          builder: (c) => TransactionFormDialog(instId: widget.institutionData['id'] ?? ''),
        ),
      )
          : null,
    );
  }

  Widget _buildFinancialContent(ThemeData theme, ColorScheme colorScheme) {
    final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final endOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);

    final stream = FirebaseFirestore.instance
        .collection('institutions')
        .doc(widget.institutionData['id'])
        .collection('financial_transactions')
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .orderBy('dueDate', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        // Tratamento de loading/erro
        if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        final allTransactions = docs.map((doc) => FinTransaction.fromDoc(doc)).toList();

        // Lógica de cálculo (Repetida aqui para termos acesso aos dados para o PDF)
        double totalIncome = 0;
        double totalExpense = 0;
        final Map<String, double> categoryTotals = {};

        for (var t in allTransactions) {
          if (t.type == 'income') {
            totalIncome += t.amount;
          } else {
            totalExpense += t.amount;
            categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
          }
        }
        final balance = totalIncome - totalExpense;

        final filteredList = _selectedCategory == 'Todas'
            ? allTransactions
            : allTransactions.where((t) => t.category == _selectedCategory).toList();

        return Column(
          children: [
            // --- SELETOR DE MÊS + PDF ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 30, left: 16, right: 16, top: 10),
              decoration: BoxDecoration(
                color: colorScheme.background,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // Espalha os itens
                children: [
                  // Botão Esquerda (Mês Anterior)
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),

                  // Texto Central
                  Column(
                    children: [
                      Text(DateFormat('MMMM yyyy', 'pt_BR').format(_selectedDate).toUpperCase(), style: theme.textTheme.titleMedium),
                      // Botãozinho discreto de PDF logo abaixo do mês ou ao lado
                      Row(
                        children: [
                          // Botão PDF
                          InkWell(
                            onTap: () => _printReport(filteredList),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Row(children: [
                                Icon(Icons.print, size: 14, color: colorScheme.primary),
                                const SizedBox(width: 2),
                                Text("PDF", style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.bold)),
                              ]),
                            ),
                          ),

                          const SizedBox(width: 10), // Espaço entre botões

                          // Botão Excel (NOVO)
                          InkWell(
                            onTap: () => _exportCsv(filteredList),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Row(children: [
                                const Icon(Icons.table_view, size: 14, color: Colors.green), // Ícone verde para lembrar Excel
                                const SizedBox(width: 2),
                                const Text("Excel", style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                              ]),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),

                  // Botão Direita (Próximo Mês)
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
                ],
              ),
            ),

            // --- CONTEÚDO SCROLLÁVEL ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                children: [
                  // --- CARD SALDO GERAL ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Saldo: ', style: theme.textTheme.bodyMedium),
                            Text(
                              NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(balance),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                  color: balance >= 0 ? Colors.green[700] : colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _SummaryItem(label: 'Entradas', value: totalIncome, color: Colors.green, icon: Icons.arrow_upward, theme: theme),
                            Container(width: 1, height: 40, color: colorScheme.secondary.withOpacity(0.2)),
                            _SummaryItem(label: 'Saídas', value: totalExpense, color: colorScheme.error, icon: Icons.arrow_downward, theme: theme),
                          ],
                        )
                      ],
                    ),
                  ),

                  // --- GRÁFICO E FILTROS ---
                  if (categoryTotals.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Despesas por Categoria", style: theme.textTheme.titleSmall),
                        InkWell(
                          onTap: () => setState(() => _showChart = !_showChart),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Icon(_showChart ? Icons.list : Icons.pie_chart, size: 18, color: colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(_showChart ? "Ocultar" : "Gráfico", style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_showChart)
                      Container(
                        height: 200,
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: colorScheme.secondary.withOpacity(0.1))
                        ),
                        child: _ExpenseChart(dataMap: categoryTotals, total: totalExpense),
                      ),

                    SizedBox(
                      height: 85,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _CategoryCard(
                            label: 'Todas',
                            amount: null,
                            isSelected: _selectedCategory == 'Todas',
                            onTap: () => setState(() => _selectedCategory = 'Todas'),
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                          ...(categoryTotals.entries.toList()
                            ..sort((a, b) => b.value.compareTo(a.value)))
                              .map((entry) {
                            return _CategoryCard(
                              label: entry.key,
                              amount: entry.value,
                              isSelected: _selectedCategory == entry.key,
                              onTap: () => setState(() => _selectedCategory = entry.key),
                              colorScheme: colorScheme,
                              theme: theme,
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // --- LISTA ---
                  Text(
                    _selectedCategory == 'Todas' ? 'Últimos Lançamentos' : 'Lançamentos: $_selectedCategory',
                    style: theme.textTheme.titleSmall?.copyWith(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 10),

                  if (filteredList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Column(children: [
                        Icon(Icons.filter_list_off, size: 50, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 10),
                        Text('Nenhum lançamento encontrado.', style: theme.textTheme.bodyMedium),
                      ]),
                    )
                  else
                    ...filteredList.map((t) {
                      final isExpense = t.type == 'expense';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          elevation: 0,
                          color: colorScheme.surface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: colorScheme.secondary.withOpacity(0.1))
                          ),
                          child: ListTile(
                            onTap: () => showDialog(
                                context: context,
                                builder: (c) => TransactionFormDialog(instId: widget.institutionData['id'] ?? '', transaction: t)
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: isExpense ? colorScheme.error.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10)
                              ),
                              child: Icon(
                                  isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isExpense ? colorScheme.error : Colors.green, size: 20
                              ),
                            ),
                            title: Text(t.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            subtitle: Text(
                                '${DateFormat('dd/MM').format(t.dueDate)} • ${t.category}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600])
                            ),
                            trailing: Text(
                              '${isExpense ? '-' : '+'} ${NumberFormat.simpleCurrency(locale: 'pt_BR').format(t.amount)}',
                              style: TextStyle(
                                  color: isExpense ? colorScheme.error : Colors.green[700],
                                  fontWeight: FontWeight.bold, fontSize: 14
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ... (Mantenha _ExpenseChart, _SummaryItem, _CategoryCard iguais ao anterior) ...
// Para não estourar o limite de caracteres, não vou colar eles de novo se já estão no seu arquivo,
// mas se precisar eu colo. Eles não mudaram.
class _ExpenseChart extends StatelessWidget {
  final Map<String, double> dataMap;
  final double total;
  const _ExpenseChart({required this.dataMap, required this.total});
  @override
  Widget build(BuildContext context) {
    final colors = [Colors.blue, Colors.redAccent, Colors.orange, Colors.purpleAccent, Colors.teal, Colors.pinkAccent, Colors.amber, Colors.indigoAccent];
    int colorIndex = 0;
    List<PieChartSectionData> sections = dataMap.entries.map((entry) {
      final percentage = total == 0 ? 0 : (entry.value / total) * 100;
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      return PieChartSectionData(color: color, value: entry.value, title: '${percentage.toStringAsFixed(0)}%', radius: 45, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white));
    }).toList();
    return Row(children: [Expanded(flex: 2, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 35, sectionsSpace: 2, borderData: FlBorderData(show: false)))), Expanded(flex: 1, child: ListView.builder(padding: EdgeInsets.zero, itemCount: dataMap.length, itemBuilder: (context, index) { final key = dataMap.keys.elementAt(index); final color = colors[index % colors.length]; return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Expanded(child: Text(key, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))]));}))]);
  }
}

class _SummaryItem extends StatelessWidget {
  final String label; final double value; final Color color; final IconData icon; final ThemeData theme;
  const _SummaryItem({required this.label, required this.value, required this.color, required this.icon, required this.theme});
  @override Widget build(BuildContext context) { return Column(children: [Row(children: [Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, size: 14, color: color)), const SizedBox(width: 6), Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w500))]), const SizedBox(height: 8), Text(NumberFormat.compactSimpleCurrency(locale: 'pt_BR').format(value), style: theme.textTheme.titleLarge?.copyWith(color: color, fontSize: 18))]); }
}

class _CategoryCard extends StatelessWidget {
  final String label; final double? amount; final bool isSelected; final VoidCallback onTap; final ColorScheme colorScheme; final ThemeData theme;
  const _CategoryCard({required this.label, this.amount, required this.isSelected, required this.onTap, required this.colorScheme, required this.theme});
  @override Widget build(BuildContext context) { final color = isSelected ? colorScheme.primary : colorScheme.surface; final textColor = isSelected ? colorScheme.onPrimary : theme.textTheme.bodyMedium?.color ?? Colors.black87; final borderColor = isSelected ? Colors.transparent : colorScheme.secondary.withOpacity(0.2); return GestureDetector(onTap: onTap, child: Container(width: 120, margin: const EdgeInsets.only(right: 10, top: 5, bottom: 5), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor), boxShadow: isSelected ? [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isSelected ? textColor.withOpacity(0.9) : textColor.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4), if (amount != null) Text(NumberFormat.compactSimpleCurrency(locale: 'pt_BR').format(amount), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)) else Icon(Icons.filter_list, color: textColor, size: 20)]))); }
}