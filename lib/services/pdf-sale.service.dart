// lib/services/pdf_sale_service.dart
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:quadra_vendas/enums/plan-type.dart';
import 'package:quadra_vendas/models/sale.model.dart';

class PdfSaleService {
  final Sale sale;
  final String institutionName;
  final PlanType activePlan;

  PdfSaleService({
    required this.sale,
    required this.institutionName,
    required this.activePlan,
  });

  Future<Uint8List> generatePdf() async {
    final pdf = pw.Document();
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final ttf = pw.Font.ttf(fontData);
    final boldTtf = pw.Font.ttf(boldFontData);

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: ttf, bold: boldTtf),
    );

    // SELETOR DE LAYOUT
    if (activePlan.isPro) {
      _buildPremiumLayout(pdf, pageTheme, currencyFormatter);
    } else {
      _buildBasicLayout(pdf, pageTheme, currencyFormatter);
    }

    return pdf.save();
  }

  // ===========================================================================
  // 💎 LAYOUT PREMIUM (Design Bonito + Mesmos Dados Completos)
  // ===========================================================================
  void _buildPremiumLayout(pw.Document pdf, pw.PageTheme pageTheme, NumberFormat currency) {
    const primaryColor = PdfColors.blueGrey900;
    const accentColor = PdfColors.blue800;
    const lightGrey = PdfColors.grey100;

    pdf.addPage(
        pw.MultiPage(
            pageTheme: pageTheme,
            build: (context) => [
              // 1. TOPO ESTILIZADO
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: const pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(institutionName.toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 18)),
                        pw.Text("PEDIDO #${sale.id?.substring(0, 6).toUpperCase()}", style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("DATA EMISSÃO", style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8)),
                        pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(sale.saleDate), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // 2. DADOS DO CLIENTE E DETALHES (Lado a Lado)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // COLUNA ESQUERDA: CLIENTE
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("DADOS DO CLIENTE", style: pw.TextStyle(color: accentColor, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Divider(color: accentColor, thickness: 1),
                          pw.Text(sale.clientName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                          if (sale.client != null) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(sale.client!.cnpj.isNotEmpty ? "CPF/CNPJ: ${sale.client!.cnpj}" : "CPF/CNPJ: Não informado", style: const pw.TextStyle(fontSize: 9)),
                            pw.Text("Tel: ${sale.client!.phone}", style: const pw.TextStyle(fontSize: 9)),
                            pw.SizedBox(height: 4),
                            pw.Text("ENDEREÇO:", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.Text("${sale.client!.address}, ${sale.client!.houseNumber}", style: const pw.TextStyle(fontSize: 9)),
                            pw.Text("${sale.client!.district} - ${sale.client!.city}", style: const pw.TextStyle(fontSize: 9)),
                          ]
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 15),
                  // COLUNA DIREITA: DETALHES DA VENDA
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: const pw.BoxDecoration(color: lightGrey, borderRadius: pw.BorderRadius.all(pw.Radius.circular(4))),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("DETALHES DA OPERAÇÃO", style: pw.TextStyle(color: primaryColor, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Divider(),
                          _buildInfoRowCompact("Vendedor", sale.salespersonName ?? "-"),
                          _buildInfoRowCompact("Pagamento", sale.paymentMethod),
                          _buildInfoRowCompact("Documento", sale.withInvoice ? "Nota Fiscal" : "Recibo"),
                          _buildInfoRowCompact("Cliente Novo", sale.newClient ? "Sim" : "Não"),
                          if (sale.observations?.isNotEmpty ?? false) ...[
                            pw.Divider(),
                            pw.Text("OBSERVAÇÕES:", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.Text(sale.observations!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          ]
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 25),

              // 3. TABELA ITENS (Premium)
              pw.Table(
                  border: null,
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(0.8),
                    2: const pw.FlexColumnWidth(1.2),
                    3: const pw.FlexColumnWidth(1.2),
                  },
                  children: [
                    pw.TableRow(
                        decoration: const pw.BoxDecoration(color: accentColor),
                        children: [
                          _th("PRODUTO"), _th("QTD", align: pw.TextAlign.center), _th("UNIT", align: pw.TextAlign.right), _th("TOTAL", align: pw.TextAlign.right)
                        ]
                    ),
                    ...sale.items.map((item) {
                      final index = sale.items.indexOf(item);
                      final isEven = index % 2 == 0;
                      return pw.TableRow(
                          decoration: pw.BoxDecoration(color: isEven ? PdfColors.white : lightGrey),
                          children: [
                            _td(item.product.name),
                            _td(item.quantity.toString(), align: pw.TextAlign.center),
                            _td(currency.format(item.unitPrice), align: pw.TextAlign.right),
                            _td(currency.format(item.totalPrice), align: pw.TextAlign.right, bold: true),
                          ]
                      );
                    }).toList(),
                  ]
              ),

              pw.SizedBox(height: 20),

              // 4. TOTAL
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: const pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.all(pw.Radius.circular(4))),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("TOTAL A PAGAR", style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                      pw.Text(currency.format(sale.totalAmount), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
              ),

              pw.Spacer(),
              pw.Center(child: pw.Text("Obrigado pela preferência!", style: pw.TextStyle(color: primaryColor, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 20),
            ]
        )
    );
  }

  // Helpers Premium
  pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(text, textAlign: align, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)));
  pw.Widget _td(String text, {pw.TextAlign align = pw.TextAlign.left, bool bold = false}) => pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(text, textAlign: align, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)));
  pw.Widget _buildInfoRowCompact(String label, String value) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)), pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))]));


  // ===========================================================================
  // 📄 LAYOUT START - ESTRUTURA ORIGINAL COMPLETA
  // ===========================================================================
  void _buildBasicLayout(pw.Document pdf, pw.PageTheme pageTheme, NumberFormat currency) {
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        build: (context) => [
          _buildHeaderStart(context),
          // AQUI ESTÁ A SECÇÃO COMPLETA QUE FALTAVA
          _buildClientSectionStart(context),
          pw.SizedBox(height: 20),
          _buildItemsTableStart(context, currency),
          pw.Divider(),
          _buildTotalStart(context, currency),
          pw.Spacer(),
          pw.Center(child: pw.Text("Documento gerado na versão Start.", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey))),
        ],
      ),
    );
  }

  // --- MÉTODOS ORIGINAIS DO START (RESTAURADOS INTEGRALMENTE) ---

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 80, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  pw.Widget _buildHeaderStart(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(institutionName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24)),
        pw.Text('Relatório de Venda', style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
        pw.SizedBox(height: 5),
        pw.Text('Data: ${DateFormat('dd/MM/yyyy HH:mm').format(sale.saleDate)}'),
        pw.SizedBox(height: 10),
        if (sale.salespersonName != null && sale.salespersonName!.isNotEmpty)
          _buildInfoRow('Vendedor:', sale.salespersonName!),
        pw.Divider(thickness: 2, height: 20),
        pw.SizedBox(height: 10),
      ],
    );
  }

  // ESTA É A FUNÇÃO QUE FALTAVA ESTAR COMPLETA
  pw.Widget _buildClientSectionStart(pw.Context context) {
    final client = sale.client;

    // Se não tiver objeto cliente completo, mostra só o nome
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
          // Linha com 2 Colunas (Dados Pessoais | Endereço)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('DADOS DO CLIENTE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.Divider(),
                    _buildInfoRow('Nome:', client.companyName),
                    _buildInfoRow('CNPJ:', client.cnpj),
                    _buildInfoRow('Telefone:', client.phone),
                    if (client.email != null && client.email!.isNotEmpty)
                      _buildInfoRow('Email:', client.email!),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
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
          // Bloco Inferior (Informações Adicionais)
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

  pw.Widget _buildItemsTableStart(pw.Context context, NumberFormat currencyFormatter) {
    final headers = ['Produto', 'Qtd.', 'Preço Unit.', 'Subtotal'];
    final data = sale.items.map((item) {
      String productName = item.product.name;
      // Lógica de variação de preço (mantida original)
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

  pw.Widget _buildTotalStart(pw.Context context, NumberFormat currencyFormatter) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text('TOTAL: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
        pw.Text(currencyFormatter.format(sale.totalAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}