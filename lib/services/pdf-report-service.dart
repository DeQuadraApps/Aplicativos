// lib/services/pdf_report_service.dart
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:quadra_vendas/models/client.model.dart';

class ReportData {
  final String salespersonName;
  final List<Client> clients;
  final double totalSales;
  final String topSellingItem;

  ReportData({
    required this.salespersonName,
    required this.clients,
    required this.totalSales,
    required this.topSellingItem,
  });
}

class PdfReportService {
  final List<ReportData> reportDataList;
  final String institutionName;
  final String reportTitle;
  final double grandTotal;
  final String reportType;
  final pw.Font font;
  final pw.Font boldFont;

  PdfReportService({
    required this.reportDataList,
    required this.institutionName,
    required this.reportTitle,
    required this.grandTotal,
    required this.reportType,
    required this.font,
    required this.boldFont
  });

  Future<Uint8List> generatePdf() async {
    final pdf = pw.Document();
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final theme = pw.ThemeData.withFont(
      base: font,
      bold:boldFont,
    );

    final bool showSales = reportType == 'complete' || reportType == 'sales_only';
    final bool showClients = reportType == 'complete' || reportType == 'clients_only';

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader(context),
        footer: (context) => _buildFooter(context),
        build: (context) => _buildReportBody(currencyFormatter, showSales, showClients),
      ),
    );

    return pdf.save();
  }

  List<pw.Widget> _buildReportBody(NumberFormat currencyFormatter, bool showSales, bool showClients) {
    List<pw.Widget> widgets = [];

    for (var data in reportDataList) {
      widgets.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const pw.BoxDecoration(
            color: PdfColors.blueGrey800,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            data.salespersonName,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.white),
          ),
        ),
      );
      widgets.add(pw.SizedBox(height: 10));

      if (showSales) {
        widgets.add(_buildSalesInfo(data, currencyFormatter));
      }

      if (showClients) {
        if (data.clients.isNotEmpty) {
          widgets.add(_buildClientsTable(data));
        } else {
          widgets.add(pw.Text('Nenhum cliente associado.'));
        }
      }

      widgets.add(pw.SizedBox(height: 25));
    }

    if (showSales) {
      widgets.add(pw.SizedBox(height: 20));
      widgets.add(_buildGrandTotal(currencyFormatter));
    }

    return widgets;
  }

  pw.Widget _buildHeader(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(institutionName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 22)),
              pw.SizedBox(height: 4),
              pw.Text(reportTitle, style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text('Emitido em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Column(
            children: [
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(institutionName, style: const pw.TextStyle(color: PdfColors.grey)),
                  pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
                      style: const pw.TextStyle(color: PdfColors.grey)),
                ],
              ),
            ]
        )
    );
  }

  pw.Widget _buildSalesInfo(ReportData data, NumberFormat currencyFormatter) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Resumo de Vendas', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blueGrey600)),
        pw.SizedBox(height: 5),
        _buildInfoRow('Total de Vendas:', currencyFormatter.format(data.totalSales)),
        _buildInfoRow('Item Mais Vendido:', data.topSellingItem),
        pw.SizedBox(height: 15),
      ],
    );
  }

  // =====================================================================
  // !! VERSÃO FINAL E DEFINITIVA DA FUNÇÃO DE CLIENTES !!
  // =====================================================================
  pw.Widget _buildClientsTable(ReportData data) {
    final Map<String, List<Client>> clientsByCity = {};
    for (final client in data.clients) {
      final cityKey = client.city.isNotEmpty ? client.city : 'Sem Cidade';
      clientsByCity.putIfAbsent(cityKey, () => []).add(client);
    }

    final sortedCities = clientsByCity.keys.toList()..sort();

    // 1. Criamos uma lista "plana" de widgets.
    final List<pw.Widget> clientWidgets = [];

    // 2. Adicionamos o título principal da secção à lista.
    clientWidgets.add(pw.Text('Relação de Clientes (${data.clients.length})', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blueGrey600)));
    clientWidgets.add(pw.SizedBox(height: 8));

    // 3. Iteramos sobre as cidades para construir a lista.
    for (var city in sortedCities) {
      final clientsInCity = clientsByCity[city]!;

      // Adicionamos o CABEÇALHO DA CIDADE como um item da lista.
      clientWidgets.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(city.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
        ),
      );

      // Adicionamos CADA CLIENTE INDIVIDUALMENTE à lista.
      for (var client in clientsInCity) {
        clientWidgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
            child: pw.Text('- ${client.companyName}'),
          ),
        );
      }
    }

    // 4. Retornamos uma única Coluna com esta lista plana de widgets.
    // Agora, o PDF pode quebrar a página entre CADA um destes widgets.
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: clientWidgets,
    );
  }

  pw.Widget _buildGrandTotal(NumberFormat currencyFormatter) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 250,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey800),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('TOTAL GERAL DE VENDAS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
            pw.SizedBox(height: 5),
            pw.Text(
              currencyFormatter.format(grandTotal),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: pw.Text(value, textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }
}