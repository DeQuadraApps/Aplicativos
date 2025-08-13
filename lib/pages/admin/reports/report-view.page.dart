// lib/pages/admin/report_view_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/models/sale.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/services/pdf-report-service.dart';

class ReportViewPage extends StatefulWidget {
  final String institutionId;
  final String salespersonId;

  const ReportViewPage({
    super.key,
    required this.institutionId,
    required this.salespersonId,
  });

  @override
  State<ReportViewPage> createState() => _ReportViewPageState();
}

class _ReportViewPageState extends State<ReportViewPage> {
  late Future<List<ReportData>> _reportFuture;
  double _grandTotal = 0;
  String _institutionName = '';
  String _reportTitle = '';

  @override
  void initState() {
    super.initState();
    _reportFuture = _fetchAndProcessReportData();
  }

  Future<List<ReportData>> _fetchAndProcessReportData() async {
    List<UserModel> salespeopleToProcess = [];

    // Busca o nome da instituição
    final instDoc = await FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).get();
    _institutionName = instDoc.data()?['name'] ?? 'Relatório';

    if (widget.salespersonId == 'all') {
      _reportTitle = 'Relatório Geral de Vendas';
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('institutionId', isEqualTo: widget.institutionId)
          .where('role', isEqualTo: 'employee')
          .get();
      salespeopleToProcess = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } else {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.salespersonId).get();
      final user = UserModel.fromFirestore(userDoc);
      _reportTitle = 'Relatório de Vendas - ${user.fullName}';
      salespeopleToProcess.add(user);
    }

    List<ReportData> processedData = [];
    double grandTotalTemp = 0;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    for (var salesperson in salespeopleToProcess) {
      // 1. Busca Clientes
      final clientsSnapshot = await FirebaseFirestore.instance
          .collection('institutions').doc(widget.institutionId)
          .collection('clients')
          .where('salespersonId', isEqualTo: salesperson.id)
          .get();
      final clients = clientsSnapshot.docs.map((doc) => Client.fromFirestore(doc)).toList();

      // 2. Busca Vendas do Mês
      final salesSnapshot = await FirebaseFirestore.instance
          .collection('institutions').doc(widget.institutionId)
          .collection('sales')
          .where('userId', isEqualTo: salesperson.id)
          .where('saleDate', isGreaterThanOrEqualTo: startOfMonth)
          .where('saleDate', isLessThanOrEqualTo: endOfMonth)
          .get();

      final sales = salesSnapshot.docs.map((doc) => Sale.fromFirestore(doc)).toList();
      final totalSales = sales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
      grandTotalTemp += totalSales;

      // 3. Calcula Item Mais Vendido
      Map<String, int> itemCounts = {};
      for (var sale in sales) {
        for (var item in sale.items) {
          itemCounts[item.product.name] = (itemCounts[item.product.name] ?? 0) + item.quantity;
        }
      }
      String topSellingItem = 'Nenhuma venda no mês';
      if (itemCounts.isNotEmpty) {
        topSellingItem = itemCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }

      processedData.add(ReportData(
        salespersonName: salesperson.fullName,
        clients: clients,
        totalSales: totalSales,
        topSellingItem: topSellingItem,
      ));
    }

    _grandTotal = grandTotalTemp;
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
                    final pdfService = PdfReportService(
                      reportDataList: snapshot.data!,
                      institutionName: _institutionName,
                      reportTitle: _reportTitle,
                      grandTotal: _grandTotal,
                    );
                    final pdfBytes = await pdfService.generatePdf();
                    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
                  },
                );
              }
              return const SizedBox.shrink();
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
            return Center(child: Text("Erro ao gerar relatório: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Nenhum dado encontrado para este relatório."));
          }

          final reportDataList = snapshot.data!;
          final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              ...reportDataList.map((data) => _buildReportSection(data, currencyFormatter)).toList(),
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
          );
        },
      ),
    );
  }

  Widget _buildReportSection(ReportData data, NumberFormat currencyFormatter) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.salespersonName, style: Theme.of(context).textTheme.headlineSmall),
          const Divider(),
          ListTile(
            title: const Text("Valor Total de Vendas (mês)"),
            trailing: Text(currencyFormatter.format(data.totalSales), style: Theme.of(context).textTheme.titleMedium),
          ),
          ListTile(
            title: const Text("Item Mais Vendido (mês)"),
            trailing: Text(data.topSellingItem, style: Theme.of(context).textTheme.titleMedium),
          ),
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