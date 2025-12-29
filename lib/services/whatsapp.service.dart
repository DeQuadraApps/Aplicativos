import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/models/sale.model.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static Future<void> sendSaleText({
    required BuildContext context,
    required Sale sale,
    required String institutionName,
  }) async {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final date = DateFormat('dd/MM/yyyy HH:mm').format(sale.saleDate);

    // 1. Monta o Texto Formatado
    final buffer = StringBuffer();
    buffer.writeln("*COMPROVANTE DE PEDIDO*");
    buffer.writeln("$institutionName\n");

    // Lista de Itens
    for (var item in sale.items) {
      final qtd = item.quantity;
      final name = item.product.name;
      final totalItem = item.totalPrice;

      // Ex: 2x Coca Cola - R$ 10,00
      buffer.writeln("${qtd}x $name - ${currency.format(totalItem)}");
    }

    buffer.writeln("");
    buffer.writeln("--------------------------------");
    buffer.writeln("*TOTAL: ${currency.format(sale.totalAmount)}*");
    buffer.writeln("--------------------------------");
    buffer.writeln("$date");
    buffer.writeln("Cliente: ${sale.clientName}");
    buffer.writeln("\nObrigado pela preferência!");

    // 2. Cria a URL do WhatsApp
    // EncodeComponent transforma quebras de linha e acentos em código de URL
    final String text = Uri.encodeComponent(buffer.toString());
    final Uri url = Uri.parse("https://wa.me/?text=$text");

    // 3. Abre o App
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if(context.mounted) AppSnackBar.showError(context, message: "Não foi possível abrir o WhatsApp.");
      }
    } catch (e) {
      if(context.mounted) AppSnackBar.showError(context, message: "Erro: $e");
    }
  }
}