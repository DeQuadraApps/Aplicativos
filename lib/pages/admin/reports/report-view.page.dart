// lib/pages/admin/report_view_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:quadra_vendas/enums/plan-type.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/models/sale.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/services/pdf-report-service.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportViewPage extends StatefulWidget {
  final String institutionId;
  final String salespersonId;
  final int selectedMonth;
  final int selectedYear;
  final String reportType;

  const ReportViewPage({
    super.key,
    required this.institutionId,
    required this.salespersonId,
    required this.selectedMonth,
    required this.selectedYear,
    required this.reportType,
  });

  @override
  State<ReportViewPage> createState() => _ReportViewPageState();
}

class _ReportViewPageState extends State<ReportViewPage> {
  late Future<List<ReportData>> _reportFuture;
  double _grandTotal = 0;
  String _institutionName = '';
  String _reportTitle = '';

  PlanType _activePlan = PlanType.start;

  @override
  void initState() {
    super.initState();
    _reportFuture = _fetchAndProcessReportData();
  }

  String _getMonthName(int month) {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return months[month - 1];
  }

  Future<List<ReportData>> _fetchAndProcessReportData() async {
    List<UserModel> salespeopleToProcess = [];

    // 1. Busca dados da Instituição (Incluindo o PLANO)
    final instDoc = await FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).get();
    final _institutionData = instDoc.data();

    _institutionName = _institutionData?['name'] ?? 'Relatório';

    _activePlan = PlanType.fromString(_institutionData?['plan']);
    final bool isStartPlan = _activePlan == PlanType.start;

    final monthName = _getMonthName(widget.selectedMonth);
    final year = widget.selectedYear;

    if (widget.salespersonId == 'all') {
      _reportTitle = 'Relatório Geral - $monthName/$year';
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('institutionId', isEqualTo: widget.institutionId)
          .where('role', isEqualTo: 'employee')
          .get();
      salespeopleToProcess = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } else {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.salespersonId).get();
      final user = UserModel.fromFirestore(userDoc);
      _reportTitle = 'Relatório de ${user.fullName} - $monthName/$year';
      salespeopleToProcess.add(user);
    }

    List<ReportData> processedData = [];
    double grandTotalTemp = 0;

    final startOfMonth = DateTime(widget.selectedYear, widget.selectedMonth, 1);
    final endOfMonth = DateTime(widget.selectedYear, widget.selectedMonth + 1, 0, 23, 59, 59);

    final bool fetchClients = widget.reportType == 'complete' || widget.reportType == 'clients_only';
    final bool fetchSales = widget.reportType == 'complete' || widget.reportType == 'sales_only';

    for (var salesperson in salespeopleToProcess) {

      List<Client> clients = [];
      if (fetchClients) {
        final clientsSnapshot = await FirebaseFirestore.instance
            .collection('institutions').doc(widget.institutionId)
            .collection('clients')
            .where('salespersonId', isEqualTo: salesperson.id)
            .get();
        clients = clientsSnapshot.docs.map((doc) => Client.fromFirestore(doc)).toList();
      }

      double totalSales = 0;
      String topSellingItem = 'N/A';

      // ✅ NOVO: Mapa para armazenar vendas por cliente
      Map<String, double> salesByClientMap = {};

      if (fetchSales) {
        final salesSnapshot = await FirebaseFirestore.instance
            .collection('institutions').doc(widget.institutionId)
            .collection('sales')
            .where('userId', isEqualTo: salesperson.id)
            .where('saleDate', isGreaterThanOrEqualTo: startOfMonth)
            .where('saleDate', isLessThanOrEqualTo: endOfMonth)
            .get();

        final sales = salesSnapshot.docs.map((doc) => Sale.fromFirestore(doc)).toList();
        totalSales = sales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
        grandTotalTemp += totalSales;

        Map<String, int> itemCounts = {};

        for (var sale in sales) {
          // ✅ NOVO: Soma valor para o cliente específico neste loop
          if (sale.clientId.isNotEmpty) {
            salesByClientMap[sale.clientId] = (salesByClientMap[sale.clientId] ?? 0) + sale.totalAmount;
          }

          // Contagem de itens mais vendidos
          for (var item in sale.items) {
            itemCounts[item.product.name] = (itemCounts[item.product.name] ?? 0) + item.quantity;
          }
        }

        if (itemCounts.isNotEmpty) {
          topSellingItem = itemCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        } else {
          topSellingItem = 'Nenhuma venda no mês';
        }
      }

      processedData.add(ReportData(
        salespersonName: salesperson.fullName,
        clients: clients,
        totalSales: totalSales,
        topSellingItem: topSellingItem,
        clientSalesTotals: salesByClientMap, // ✅ NOVO: Passando o mapa para o model
      ));
    }

    if(mounted) {
      setState(() {
        _grandTotal = grandTotalTemp;
        _reportTitle = _reportTitle;
      });
    }

    return processedData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_reportTitle),
        actions: [
          FutureBuilder<List<ReportData>>(
            future: _reportFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'Exportar para PDF',
                  onPressed: () async {
                    // Feedback visual
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Dialog(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 20),
                              Text("Gerando Relatório..."),
                            ],
                          ),
                        ),
                      ),
                    );

                    try {
                      // Carregamento de Fontes
                      final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
                      final boldFontData = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
                      final ttf = pw.Font.ttf(fontData);
                      final boldTtf = pw.Font.ttf(boldFontData);

                      // Chamada do Serviço com o Plano Ativo
                      final pdfService = PdfReportService(
                        reportDataList: snapshot.data!,
                        institutionName: _institutionName,
                        reportTitle: _reportTitle,
                        grandTotal: _grandTotal,
                        reportType: widget.reportType,
                        font: ttf,
                        boldFont: boldTtf,
                        activePlan: _activePlan.toString(), // <--- Aqui passamos a variável de decisão
                      );

                      final pdfBytes = await pdfService.generatePdf();

                      if (mounted) Navigator.of(context).pop(); // Fecha Dialog
                      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);

                    } catch (e) {
                      if (mounted) Navigator.of(context).pop();
                      if(mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Erro ao gerar PDF: $e"), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                );
              }
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              );
            },
          )
        ],
      ),
      body: FutureBuilder<List<ReportData>>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro ao carregar dados: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Nenhum dado encontrado."));
          }

          final reportDataList = snapshot.data!;
          final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
          final bool showSales = widget.reportType == 'complete' || widget.reportType == 'sales_only';

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Aviso visual na tela se for plano básico
              if (_activePlan == PlanType.start)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Dica: Faça upgrade para o plano Performance ou Elite para gerar relatórios em PDF com design profissional e sua logo.",
                          style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              ...reportDataList.map((data) => _buildReportSection(data, currencyFormatter)).toList(),
              if(showSales) ...[
                const Divider(thickness: 2),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("TOTAL GERAL DE VENDAS", style: Theme.of(context).textTheme.titleMedium),
                      Text(currencyFormatter.format(_grandTotal), style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ... (o método _buildReportSection continua igual ao seu original)
  Widget _buildReportSection(ReportData data, NumberFormat currencyFormatter) {
    final bool showClients = widget.reportType == 'complete' || widget.reportType == 'clients_only';
    final bool showSales = widget.reportType == 'complete' || widget.reportType == 'sales_only';

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.salespersonName, style: Theme.of(context).textTheme.headlineSmall),
          const Divider(),
          if (showSales) ...[
            ListTile(
              title: const Text("Valor Total de Vendas (mês)"),
              trailing: Text(currencyFormatter.format(data.totalSales), style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              title: const Text("Item Mais Vendido (mês)"),
              trailing: Text(data.topSellingItem, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.right,),
            ),
          ],
          if (showClients && data.clients.isNotEmpty)
            ExpansionTile(
              title: Text("Relação de Clientes (${data.clients.length})"),
              children: data.clients.map((client) => ListTile(
                title: Text(client.companyName),
                subtitle: Text(client.city),
              )).toList(),
            ),
        ],
      ),
    );
  }
}