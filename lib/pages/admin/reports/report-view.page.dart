// lib/pages/admin/report_view_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Importante para a função `compute`
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/models/sale.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/services/pdf-report-service.dart';
import 'package:pdf/widgets.dart' as pw; // Importar para pw.Font

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
    final instDoc = await FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).get();
    _institutionName = instDoc.data()?['name'] ?? 'Relatório';

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
      ));
    }

    // Usamos setState aqui para garantir que o título e o total sejam atualizados na tela
    // antes de qualquer outra ação.
    if(mounted) {
      setState(() {
        _grandTotal = grandTotalTemp;
        // O título já é setado acima, mas garantimos aqui.
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
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return const Dialog(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(width: 20),
                                Text("Gerando PDF..."),
                              ],
                            ),
                          ),
                        );
                      },
                    );

                    try {
                      // =======================================================
                      // !! MUDANÇA PRINCIPAL AQUI !!
                      // Usamos `compute` para rodar a função `_generatePdfInBackground`
                      // em segundo plano, passando os dados necessários.
                      // =======================================================
                      final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
                      final boldFontData = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
                      final ttf = pw.Font.ttf(fontData);
                      final boldTtf = pw.Font.ttf(boldFontData);

                      final pdfService = PdfReportService(
                        reportDataList: snapshot.data!,
                        institutionName: _institutionName,
                        reportTitle: _reportTitle,
                        grandTotal: _grandTotal,
                        reportType: widget.reportType,
                        font: ttf,
                        boldFont: boldTtf,
                      );

                      final pdfBytes = await pdfService.generatePdf();

                      // 3. Fechamos o diálogo e mostramos o PDF
                      if (mounted) Navigator.of(context).pop();
                      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);

                    } catch (e) {
                      if (mounted) Navigator.of(context).pop();

                      if(mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Ocorreu um erro ao gerar o PDF: $e"), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                );
              }
              // Mostra um ícone de "carregando" enquanto os dados não chegam
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
            return const Center(child: Text("Nenhum dado encontrado para este relatório."));
          }

          final reportDataList = snapshot.data!;
          final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
          final bool showSales = widget.reportType == 'complete' || widget.reportType == 'sales_only';

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
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