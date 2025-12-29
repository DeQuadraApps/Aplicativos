import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:quadra_vendas/models/transaction.model.dart';
import 'package:universal_html/html.dart' as html; // Import seguro para Web

class FinancialCsvService {
  Future<void> generateAndExport(List<FinTransaction> transactions) async {
    final dateFormat = DateFormat('dd/MM/yyyy');

    // 1. GERAR CONTEÚDO CSV
    List<List<dynamic>> rows = [
      ['Data', 'Descricaoo', 'Categoria', 'Tipo', 'Valor', 'Status']
    ];

    for (var t in transactions) {
      rows.add([
        dateFormat.format(t.dueDate),
        t.description,
        t.category,
        t.type == 'income' ? 'Entrada' : 'Saida',
        t.amount.toStringAsFixed(2).replaceAll('.', ','),
        t.status == 'paid' ? 'Pago' : 'Pendente',
      ]);
    }

    String csvContent = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);

    // Adiciona o BOM para o Excel reconhecer acentos (UTF-8)
    final List<int> bytes = [0xEF, 0xBB, 0xBF, ...csvContent.codeUnits];
    final Uint8List data = Uint8List.fromList(bytes);
    final String fileName = 'relatorio_financeiro_${DateFormat('dd-MM').format(DateTime.now())}.csv';

    // 2. VERIFICAR PLATAFORMA E AGIR

    if (kIsWeb) {
      // --- LÓGICA WEB (DOWNLOAD) ---
      final blob = html.Blob([data], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // --- LÓGICA DESKTOP (SALVAR COMO) ---
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar Relatório CSV',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (outputFile != null) {
        // O FilePicker às vezes não coloca a extensão se o usuário apagar
        if (!outputFile.endsWith('.csv')) outputFile += '.csv';

        final file = File(outputFile);
        await file.writeAsBytes(data);
      }

    } else {
      // --- LÓGICA MOBILE (COMPARTILHAR) ---
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(data);

      await Share.shareXFiles(
        [XFile(path)],
        text: 'Segue anexo o relatório financeiro.',
      );
    }
  }
}