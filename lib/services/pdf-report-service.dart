// lib/services/pdf_report_service.dart
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:quadra_vendas/models/client.model.dart';

// Enum para controlar o nível do usuário
// Se ainda não tiver esse arquivo separado, pode deixar aqui mesmo
// import 'package:quadra_vendas/enums/plan_type.enum.dart';

class ReportData {
  final String salespersonName;
  final List<Client> clients;
  final double totalSales;
  final String topSellingItem;
  final Map<String, double> clientSalesTotals;

  ReportData({
    required this.salespersonName,
    required this.clients,
    required this.totalSales,
    required this.topSellingItem,
    required this.clientSalesTotals,
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
  final String activePlan; // 'start', 'performance', 'elite'

  PdfReportService({
    required this.reportDataList,
    required this.institutionName,
    required this.reportTitle,
    required this.grandTotal,
    required this.reportType,
    required this.font,
    required this.boldFont,
    required this.activePlan,
  });

  // Helper para verificar se é PRO
  bool get isPro => activePlan != 'start';

  Future<Uint8List> generatePdf() async {
    final pdf = pw.Document();
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final now = DateFormat('dd/MM/yyyy').format(DateTime.now());

    if (isPro) {
      // 💎 DESIGN PREMIUM (Colorido, Agrupado e Lindo)
      _buildPremiumLayout(pdf, currencyFormatter, now);
    } else {
      // 😐 DESIGN BÁSICO (Plano Start - Preto e Branco)
      _buildBasicLayout(pdf, currencyFormatter, now);
    }

    return pdf.save();
  }

  // ===========================================================================
  // 💎 LAYOUT PREMIUM - CORES DO CATÁLOGO + CIDADES AGRUPADAS
  // ===========================================================================
  // ===========================================================================
  // 💎 LAYOUT PREMIUM - COM VALOR GASTO POR CLIENTE
  // ===========================================================================
  void _buildPremiumLayout(pw.Document pdf, NumberFormat currency, String now) {
    const baseColor = PdfColors.blueGrey900;
    const accentColor = PdfColors.blue800;
    const lightGrey = PdfColors.grey100;

    // Cor para destacar o dinheiro
    const moneyColor = PdfColors.green800;

    final bool showSales = reportType == 'complete' || reportType == 'sales_only';
    final bool showClients = reportType == 'complete' || reportType == 'clients_only';

    // --- 1. CAPA (Mantida igual) ---
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(institutionName.toUpperCase(), style: pw.TextStyle(fontSize: 40, fontWeight: pw.FontWeight.bold, color: baseColor), textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 20),
                pw.Container(height: 5, width: 150, color: accentColor),
                pw.SizedBox(height: 40),
                pw.Text(reportTitle.toUpperCase(), style: const pw.TextStyle(fontSize: 24, letterSpacing: 3), textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 10),
                pw.Text("DOCUMENTO ADMINISTRATIVO CONFIDENCIAL", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600), textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 100),
                pw.Text("Gerado em: $now", style: const pw.TextStyle(color: PdfColors.grey500)),
              ],
            ),
          );
        },
      ),
    );

    // --- 2. CONTEÚDO ---
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text(institutionName.toUpperCase(), style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 10)),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 20),
          child: pw.Text("Página ${context.pageNumber} de ${context.pagesCount}", style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10)),
        ),
        build: (context) {
          final List<pw.Widget> widgets = [];

          for (var data in reportDataList) {

            // CABEÇALHO DO VENDEDOR
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 25, bottom: 10),
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: const pw.BoxDecoration(
                  color: baseColor,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                width: double.infinity,
                child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(data.salespersonName.toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      if (showSales)
                        pw.Text(currency.format(data.totalSales), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    ]
                ),
              ),
            );

            if (showSales) {
              widgets.add(
                  pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 15),
                      padding: const pw.EdgeInsets.all(10),
                      color: lightGrey,
                      child: pw.Row(children: [
                        pw.Text("Item Destaque: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: baseColor)),
                        pw.Text(data.topSellingItem),
                      ])
                  )
              );
            }

            // TABELA DE CLIENTES COM VALORES
            if (showClients && data.clients.isNotEmpty) {

              final Map<String, List<Client>> clientsByCity = {};
              for (final client in data.clients) {
                final cityKey = client.city.isNotEmpty ? client.city : 'Cidade Não Informada';
                clientsByCity.putIfAbsent(cityKey, () => []).add(client);
              }
              final sortedCities = clientsByCity.keys.toList()..sort();

              for (var city in sortedCities) {
                final clientsInCity = clientsByCity[city]!;

                // Header da Cidade
                widgets.add(
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const pw.EdgeInsets.only(top: 8, bottom: 0),
                    decoration: const pw.BoxDecoration(color: accentColor, borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(4))),
                    child: pw.Text(city.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10)),
                  ),
                );

                // Tabela Zebrada com 3 Colunas
                widgets.add(
                  pw.Table(
                    border: null,
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3), // Nome
                      1: const pw.FlexColumnWidth(1.5), // Valor (NOVO)
                    },
                    children: clientsInCity.map((client) {
                      final index = clientsInCity.indexOf(client);
                      final isEven = index % 2 == 0;

                      // Recupera o valor comprado por este cliente
                      // Se não tiver comprado nada no mês, mostra zero
                      final double valorComprado = data.clientSalesTotals[client.id] ?? 0.0;
                      final bool comprouAlgo = valorComprado > 0;

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                            color: isEven ? PdfColors.white : lightGrey,
                            border: const pw.Border(
                              bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                              left: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                              right: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                            )
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                            child: pw.Text(client.companyName, style: const pw.TextStyle(fontSize: 11)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                            child: pw.Text(
                              comprouAlgo ? currency.format(valorComprado) : "-",
                              style: pw.TextStyle(
                                  fontSize: 11,
                                  // Se comprou, destaca em verde escuro, senão cinza
                                  color: comprouAlgo ? moneyColor : PdfColors.grey400,
                                  fontWeight: comprouAlgo ? pw.FontWeight.bold : pw.FontWeight.normal
                              ),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              }
            } else if (showClients) {
              widgets.add(pw.Text("- Nenhum cliente vinculado -", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)));
            }
          }

          // TOTAL GERAL
          if (showSales) {
            widgets.add(pw.SizedBox(height: 30));
            widgets.add(pw.Divider(color: baseColor, thickness: 2));
            widgets.add(
              pw.Container(
                alignment: pw.Alignment.centerRight,
                padding: const pw.EdgeInsets.only(top: 10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("TOTAL GERAL DE VENDAS", style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                    pw.Text(
                      currency.format(grandTotal),
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: baseColor),
                    ),
                  ],
                ),
              ),
            );
          }

          return widgets;
        },
      ),
    );
  }

  // ===========================================================================
  // 😐 LAYOUT BÁSICO (Start) - SEM CORES, SEM CAPA
  // ===========================================================================
  void _buildBasicLayout(pw.Document pdf, NumberFormat currency, String now) {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),

        // Header Simples (Sem logo, sem cores)
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(institutionName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(reportTitle, style: const pw.TextStyle(fontSize: 10)),
                  pw.Text("Emissão: $now", style: const pw.TextStyle(fontSize: 10)),
                ]
            ),
            pw.Divider(thickness: 1),
          ],
        ),

        // Footer discreto
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            "Página ${context.pageNumber} - Quadra Vendas (Plano Start)",
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
          ),
        ),

        build: (context) {
          final List<pw.Widget> widgets = [];
          final bool showSales = reportType == 'complete' || reportType == 'sales_only';
          final bool showClients = reportType == 'complete' || reportType == 'clients_only';

          for (var data in reportDataList) {

            // 1. Nome do Vendedor (Destaque em Negrito apenas, sem tarja)
            widgets.add(pw.SizedBox(height: 15));
            widgets.add(
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 0.5)) // Linha fina
                  ),
                  child: pw.Text(
                    "Vendedor: ${data.salespersonName.toUpperCase()}",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                  ),
                )
            );
            widgets.add(pw.SizedBox(height: 5));

            // 2. Info de Vendas
            if (showSales) {
              widgets.add(
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Item Destaque: ${data.topSellingItem}", style: const pw.TextStyle(fontSize: 10)),
                        pw.Text("Total: ${currency.format(data.totalSales)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ]
                  )
              );
              widgets.add(pw.SizedBox(height: 10));
            }

            // 3. Clientes (AGRUPADOS POR CIDADE - Restaurado)
            if (showClients && data.clients.isNotEmpty) {

              // Lógica de Agrupamento
              final Map<String, List<Client>> clientsByCity = {};
              for (final client in data.clients) {
                final cityKey = client.city.isNotEmpty ? client.city : 'Cidade Não Informada';
                clientsByCity.putIfAbsent(cityKey, () => []).add(client);
              }
              final sortedCities = clientsByCity.keys.toList()..sort();

              for (var city in sortedCities) {
                // Nome da Cidade (Negrito simples)
                widgets.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
                      child: pw.Text(
                        city.toUpperCase(),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, decoration: pw.TextDecoration.underline),
                      ),
                    )
                );

                // Lista de Clientes (Compacta)
                for (var client in clientsByCity[city]!) {
                  widgets.add(
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 10),
                        child: pw.Text("- ${client.companyName}", style: const pw.TextStyle(fontSize: 9)),
                      )
                  );
                }
              }
            } else if (showClients) {
              widgets.add(pw.Text("- Nenhum cliente -", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)));
            }
          }

          // Total Geral
          if (showSales) {
            widgets.add(pw.SizedBox(height: 20));
            widgets.add(pw.Divider());
            widgets.add(
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    "TOTAL GERAL: ${currency.format(grandTotal)}",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                  ),
                )
            );
          }

          return widgets;
        },
      ),
    );
  }
}