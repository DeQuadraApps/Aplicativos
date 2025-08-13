// lib/services/pdf_report_service.dart
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:quadra_vendas/models/client.model.dart';

// Estrutura de dados para o relatório
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

  PdfReportService({
    required this.reportDataList,
    required this.institutionName,
    required this.reportTitle,
    required this.grandTotal,
  });

  Future<Uint8List> generatePdf() async {
    final pdf = pw.Document();
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final ttf = pw.Font.ttf(fontData);
    final boldTtf = pw.Font.ttf(boldFontData);

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: ttf, bold: boldTtf),
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader(),
        build: (context) => [
          ..._buildSalespersonSections(currencyFormatter),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 20),
          _buildGrandTotal(currencyFormatter),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(institutionName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24)),
        pw.Text(reportTitle, style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
        pw.Text('Data de Emissão: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
        pw.Divider(thickness: 2),
        pw.SizedBox(height: 10),
      ],
    );
  }

  List<pw.Widget> _buildSalespersonSections(NumberFormat currencyFormatter) {
    List<pw.Widget> sections = [];
    for (var data in reportDataList) {
      sections.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(data.salespersonName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.Divider(),
              pw.SizedBox(height: 5),
              _buildInfoRow('Total de Vendas:', currencyFormatter.format(data.totalSales)),
              _buildInfoRow('Item Mais Vendido:', data.topSellingItem),
              pw.SizedBox(height: 10),
              pw.Text('Clientes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              ...data.clients.map((client) => pw.Text('- ${client.companyName} (${client.city})')).toList(),
              pw.SizedBox(height: 25),
            ],
          )
      );
    }
    return sections;
  }

  pw.Widget _buildGrandTotal(NumberFormat currencyFormatter) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('VALOR TOTAL DE VENDAS (GERAL):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(
            currencyFormatter.format(grandTotal),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 120, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Text(value),
        ],
      ),
    );
  }
}