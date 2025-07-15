// lib/pages/info/info_page.dart
import 'package:flutter/material.dart';
import 'package:quadra_vendas/pages/terms/terms-of-use.page.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

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
            onTap: () {}, // Pode adicionar um link para um site futuro aqui
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
            subtitle: const Text('1.0.3'), // Pode atualizar conforme desenvolve
          ),
        ],
      ),
    );
  }
}
