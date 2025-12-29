import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:quadra_vendas/models/product-category.model.dart';
import 'package:quadra_vendas/models/product.model.dart';

class CatalogPdfService {
  final String institutionName;
  final List<ProductCategory> categories;
  final Map<String, List<Product>> productsMap;

  CatalogPdfService({
    required this.institutionName,
    required this.categories,
    required this.productsMap,
  });

  Future<void> generateAndPrint() async {
    final pdf = pw.Document();
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final now = DateFormat('dd/MM/yyyy').format(DateTime.now());

    // Cores (Estilo Profissional)
    const baseColor = PdfColors.blueGrey900;
    const accentColor = PdfColors.blue800;
    const lightGrey = PdfColors.grey100;

    // --- CAPA (CORRIGIDA) ---
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          // ✨ AQUI ESTÁ A CORREÇÃO: pw.Center envolve tudo
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  institutionName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 40,
                    fontWeight: pw.FontWeight.bold,
                    color: baseColor,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 20),
                pw.Container(height: 5, width: 150, color: accentColor),
                pw.SizedBox(height: 40),
                pw.Text(
                  "CATÁLOGO DE PRODUTOS",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.normal, // fontWeight normal costuma ficar mais elegante no pdf default font
                    letterSpacing: 5,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  "TABELA DE PREÇOS ATUALIZADA",
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 100), // Espaço fixo ao invés de Spacer dentro de Center pode funcionar melhor visualmente
                pw.Text(
                  "Gerado em: $now",
                  style: const pw.TextStyle(color: PdfColors.grey500),
                ),
              ],
            ),
          );
        },
      ),
    );

    // --- LISTAGEM DE PRODUTOS (MANTIDA IGUAL) ---
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text(
            institutionName.toUpperCase(),
            style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 10),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 20),
          child: pw.Text(
            "Página ${context.pageNumber} de ${context.pagesCount}",
            style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10),
          ),
        ),
        build: (context) {
          final List<pw.Widget> widgets = [];

          for (var category in categories) {
            final products = productsMap[category.id] ?? [];
            if (products.isEmpty) continue;

            // Título da Categoria
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 20, bottom: 10),
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: const pw.BoxDecoration(
                  color: baseColor,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                width: double.infinity,
                child: pw.Text(
                  category.name.toUpperCase(),
                  style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14),
                ),
              ),
            );

            // Tabela de Produtos
            widgets.add(
              pw.Table(
                border: null,
                columnWidths: {
                  0: const pw.FlexColumnWidth(3), // Nome
                  1: const pw.FlexColumnWidth(1), // Preço
                },
                children: products.map((product) {
                  final index = products.indexOf(product);
                  final isEven = index % 2 == 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: isEven ? lightGrey : PdfColors.white),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        child: pw.Text(product.name, style: const pw.TextStyle(fontSize: 12)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        child: pw.Text(
                          currency.format(product.salePrice),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: baseColor),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            );

            widgets.add(pw.SizedBox(height: 10));
          }

          return widgets;
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Catalogo_${institutionName.replaceAll(' ', '_')}.pdf',
    );
  }
}