// lib/services/pdf_sale_service.dart
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:quadra_vendas/models/sale.model.dart';

class PdfSaleService {
  final Sale sale;
  final String institutionName;

  PdfSaleService({required this.sale, required this.institutionName});

  Future<Uint8List> generatePdf() async {
    final pdf = pw.Document();
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    // Carregamento das fontes - isto só funciona se o pubspec.yaml estiver correto
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final ttf = pw.Font.ttf(fontData);
    final boldTtf = pw.Font.ttf(boldFontData);

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(
        base: ttf,
        bold: boldTtf,
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        build: (context) => [
          _buildHeader(context),
          _buildClientInfo(context),
          pw.SizedBox(height: 20),
          _buildItemsTable(context, currencyFormatter),
          pw.Divider(),
          _buildTotal(context, currencyFormatter),
          pw.SizedBox(height: 20),
          _buildFooter(context),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(institutionName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24)),
        pw.Text('Relatório de Venda', style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
        pw.SizedBox(height: 5),
        pw.Text('Data: ${DateFormat('dd/MM/yyyy HH:mm').format(sale.saleDate)}'),
        pw.Divider(thickness: 2),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildClientInfo(pw.Context context) {
    final client = sale.client;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('CLIENTE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text(client?.companyName ?? sale.clientName),
        if (client != null) ...[
          pw.Text('CNPJ: ${client.cnpj}'),
          pw.Text('Cidade: ${client.city}'),
          pw.Text('Bairro: ${client.district}'),
          pw.Text('Rua/Avenida: ${client.address}'),
          pw.Text('Número: ${client.houseNumber}'),
          pw.Text('Email: ${client.email}'),
          pw.Text('Telefone: ${client.phone}'),
        ]
      ],
    );
  }

  pw.Widget _buildItemsTable(pw.Context context, NumberFormat currencyFormatter) {
    final headers = ['Produto', 'Qtd.', 'Preço Unit.', 'Subtotal'];
    final data = sale.items.map((item) {
      String productName = item.product.name;
      if (item.product.otherPrices != null) {
        for (var priceEntry in item.product.otherPrices!.entries) {
          if ((priceEntry.value as num).toDouble() == item.product.salePrice) {
            final headerName = priceEntry.key.toUpperCase();
            if(!headerName.contains('UNIT') && !headerName.contains('VENDA')) {
              productName += ' (${priceEntry.key})';
            }
            break;
          }
        }
      }
      return [
        productName,
        item.quantity.toString(),
        currencyFormatter.format(item.unitPrice),
        currencyFormatter.format(item.totalPrice),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 10),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
      },
    );
  }

  pw.Widget _buildTotal(pw.Context context, NumberFormat currencyFormatter) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text('TOTAL: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
        pw.Text(currencyFormatter.format(sale.totalAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Forma de Pagamento:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(sale.paymentMethod),
          pw.SizedBox(height: 10),
          pw.Text('Emissão de Nota:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(sale.withInvoice ? 'Com emissão de nota fiscal.' : 'Sem emissão de nota fiscal.'),
          pw.SizedBox(height: 10),
          if(sale.observations != null && sale.observations!.isNotEmpty)
            pw.Text('Observações:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          if(sale.observations != null && sale.observations!.isNotEmpty)
            pw.Text(sale.observations!),
        ]
    );
  }
}