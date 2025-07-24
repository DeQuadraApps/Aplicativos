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
          // A nova secção de informações do cliente
          _buildClientSection(context),
          pw.SizedBox(height: 20),
          _buildItemsTable(context, currencyFormatter),
          pw.Divider(),
          _buildTotal(context, currencyFormatter),
          pw.SizedBox(height: 20),
        ],
      ),
    );

    return pdf.save();
  }

  // Função helper para criar uma linha de informação (label: valor)
  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
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
        pw.SizedBox(height: 10),
      ],
    );
  }

  /// =======================================================
  /// SECÇÃO DE CLIENTE REESTRUTURADA
  /// =======================================================
  pw.Widget _buildClientSection(pw.Context context) {
    final client = sale.client;

    // Só mostra os detalhes completos se o objeto client estiver disponível
    if (client == null) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('CLIENTE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(sale.clientName),
        ],
      );
    }

    return pw.Column(
      children: [
        pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Coluna da Esquerda: Dados do Cliente
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('DADOS DO CLIENTE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.Divider(),
                  _buildInfoRow('Nome:', client.companyName),
                  _buildInfoRow('CNPJ:', client.cnpj),
                  _buildInfoRow('Telefone:', client.phone),
                  // =======================================================
                  // AQUI ESTÁ A CORREÇÃO: Mostra o email apenas se ele existir
                  // =======================================================
                  if (client.email != null && client.email!.isNotEmpty)
                    _buildInfoRow('Email:', client.email!),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            // Coluna da Direita: Endereço
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('ENDEREÇO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.Divider(),
                  _buildInfoRow('Cidade:', client.city),
                  _buildInfoRow('Bairro:', client.district),
                  _buildInfoRow('Rua/Av.:', client.address),
                  _buildInfoRow('Número:', client.houseNumber),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('INFORMAÇÕES ADICIONAIS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            pw.Divider(),
            _buildInfoRow('Pagamento:', sale.paymentMethod),
            _buildInfoRow('Emitir NF:', sale.withInvoice ? 'Sim' : 'Não'),
            _buildInfoRow('Cliente Novo: ', sale.newClient ? 'Sim' : 'Não'),
            if(sale.observations != null && sale.observations!.isNotEmpty)
            _buildInfoRow('Observações:', sale.observations!),
          ]
        )
      ]
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
}
