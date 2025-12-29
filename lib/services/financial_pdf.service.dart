import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/models/transaction.model.dart';

class FinancialPdfService {
  // Adicionei institutionName nos parâmetros
  Future<void> generateAndPrint(List<FinTransaction> transactions, DateTime referenceDate, String institutionName) async {
    final pdf = pw.Document();
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Cores do Relatório
    const baseColor = PdfColors.blue800;
    const accentColor = PdfColors.blueGrey900;

    // Cálculos
    double totalIncome = 0;
    double totalExpense = 0;
    for (var t in transactions) {
      if (t.type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }
    double balance = totalIncome - totalExpense;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // --- CABEÇALHO ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(institutionName.toUpperCase(), style: pw.TextStyle(color: baseColor, fontWeight: pw.FontWeight.bold, fontSize: 20)),
                    pw.Text('Relatório Financeiro Mensal', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 12)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(DateFormat('MMMM yyyy', 'pt_BR').format(referenceDate).toUpperCase(), style: pw.TextStyle(color: accentColor, fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text('Gerado em: ${dateFormat.format(DateTime.now())}', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Divider(color: baseColor, thickness: 2),
            pw.SizedBox(height: 20),

            // --- RESUMO (CARDS) ---
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem('Entradas', totalIncome, PdfColors.green700),
                  pw.Container(width: 1, height: 30, color: PdfColors.grey400),
                  _buildSummaryItem('Saídas', totalExpense, PdfColors.red700),
                  pw.Container(width: 1, height: 30, color: PdfColors.grey400),
                  _buildSummaryItem('Saldo Final', balance, balance >= 0 ? PdfColors.blue700 : PdfColors.red700, isBold: true),
                ],
              ),
            ),
            pw.SizedBox(height: 25),

            // --- TABELA ---
            pw.Table.fromTextArray(
              context: context,
              border: null, // Remove bordas duras
              headerDecoration: const pw.BoxDecoration(
                color: baseColor,
                borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
              ),
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
              ),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,   // Data
                1: pw.Alignment.centerLeft,   // Descrição
                2: pw.Alignment.centerLeft,   // Categoria
                3: pw.Alignment.centerRight,  // Valor
              },
              headers: ['DATA', 'DESCRIÇÃO', 'CATEGORIA', 'VALOR'],
              data: transactions.map((t) {
                final isExpense = t.type == 'expense';
                final color = isExpense ? PdfColors.red700 : PdfColors.green700;

                return [
                  dateFormat.format(t.dueDate),
                  t.description,
                  t.category,
                  pw.Text(
                      (isExpense ? '- ' : '+ ') + currency.format(t.amount),
                      style: pw.TextStyle(color: color, fontWeight: pw.FontWeight.bold, fontSize: 10)
                  ),
                ];
              }).toList(),
            ),

            // Rodapé simples
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('QuadraVendas Sistema', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                pw.Text('Página 1 de 1', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
              ],
            )
          ];
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Relatorio_${DateFormat('MMM_yyyy').format(referenceDate)}.pdf'
    );
  }

  pw.Widget _buildSummaryItem(String label, double value, PdfColor color, {bool isBold = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(), style: pw.TextStyle(color: PdfColors.grey600, fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(
          NumberFormat.simpleCurrency(locale: 'pt_BR').format(value),
          style: pw.TextStyle(color: color, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 14),
        ),
      ],
    );
  }
}