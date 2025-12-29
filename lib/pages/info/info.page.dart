// lib/pages/info/info_page.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:quadra_vendas/pages/terms/privacy-policy.page.dart';
import 'package:quadra_vendas/pages/terms/terms-of-use.page.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sobre o App')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            // 1. CABEÇALHO COM LOGO E NOME
            Center(
              child: Column(
                children: [
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.storefront, size: 60, color: colorScheme.onPrimaryContainer),
                    // Dica: Substitua o Icon acima por: Image.asset('assets/logo.png')
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Quadra Vendas',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const Text('Gestão de vendas simplificada'),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 2. SEÇÃO DE SUPORTE
            _buildSectionHeader(context, 'Suporte & Contato'),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text('Falar no WhatsApp'),
              subtitle: const Text('Tire suas dúvidas agora'),
              onTap: () => _launchUrl('https://wa.me/5546991384595'), // Coloque seu número
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Enviar E-mail'),
              subtitle: const Text('dequadraapps@gmail.com'),
              onTap: () => _launchUrl('mailto:dequadraapps@gmail.com'),
            ),

            const Divider(),

            // 3. SEÇÃO LEGAL E TÉCNICA
            _buildSectionHeader(context, 'Informações Legais'),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Termos de Uso'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfUsePage())),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Política de Privacidade'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
            ),

            // Versão do App
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.hasData ? snapshot.data!.version : '...';
                return ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Versão Instalada'),
                  trailing: Text(version, style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),

            const SizedBox(height: 30),

            // 4. RODAPÉ
            Text(
              '© ${DateTime.now().year} Dequadra Soluções Digitais',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}