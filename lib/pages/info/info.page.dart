// lib/pages/info/info_page.dart
import 'package:flutter/material.dart';
import 'package:quadra_vendas/pages/terms/terms-of-use.page.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  Future<void> _launchURL() async {
    final uri = Uri.parse('https://dequadraapps-b7439.web.app/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Opcional: Tratar o erro caso não consiga abrir o link
      throw 'Could not launch $uri';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informações'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Desenvolvido por'),
            subtitle: const Text('Dequadra Apps'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: _launchURL,
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Termos e Condições de Uso'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermsOfUsePage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versão'),
            subtitle: const Text('2.2.4'), // Pode atualizar conforme desenvolve
          ),
        ],
      ),
    );
  }
}
