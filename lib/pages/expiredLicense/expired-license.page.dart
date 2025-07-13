// lib/pages/expired_license_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';
import 'package:url_launcher/url_launcher.dart';

class ExpiredLicensePage extends StatefulWidget {
  const ExpiredLicensePage({super.key});

  @override
  State<ExpiredLicensePage> createState() => _ExpiredLicensePageState();
}

class _ExpiredLicensePageState extends State<ExpiredLicensePage> {
  bool _isLoading = true;
  String _institutionName = '';
  String _expirationDate = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchInstitutionData();
  }

  /// Busca os dados da instituição para exibir na tela.
  Future<void> _fetchInstitutionData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Usuário não encontrado.");
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final institutionId = userDoc.data()?['institutionId'];

      if (institutionId == null) {
        throw Exception("Instituição não vinculada.");
      }

      final institutionDoc = await FirebaseFirestore.instance.collection('institutions').doc(institutionId).get();
      if (institutionDoc.exists) {
        final data = institutionDoc.data()!;
        final timestamp = data['licenseExpiresAt'] as Timestamp;
        setState(() {
          _institutionName = data['name'] ?? 'Sua instituição';
          _expirationDate = DateFormat('dd \'de\' MMMM \'de\' yyyy', 'pt_BR').format(timestamp.toDate());
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Não foi possível carregar os dados da sua licença.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Abre uma URL (e-mail ou WhatsApp).
  Future<void> _launchURL(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        AppSnackBar.showError(context, message: 'Não foi possível abrir o link.');
      }
    }
  }

  void _contactByEmail() {
    // 1. Defina os parâmetros em um Map, como antes.
    final Map<String, String> emailParams = {
      'subject': 'Suporte para Licença Expirada - $_institutionName',
      'body': 'Olá,\n\nA licença da minha instituição ($_institutionName) expirou em $_expirationDate.\n\nGostaria de solicitar suporte para renovação.\n\nObrigado.',
    };

    // 2. Crie a string de query manualmente, codificando cada parte.
    //    Uri.encodeComponent vai transformar ' ' em '%20' e '\n' em '%0A'.
    final String queryString = emailParams.entries
        .map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
        .join('&');

    // 3. Crie a URI usando o parâmetro 'query' em vez de 'queryParameters'.
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'dequadraapps@gmail.com',
      query: queryString, // << A MUDANÇA CRÍTICA ESTÁ AQUI
    );

    _launchURL(emailLaunchUri);
  }

  void _contactByWhatsApp() {
    const String phone = '5546991384595';
    final String message = 'Olá, a licença da minha instituição ($_institutionName) expirou em $_expirationDate. Gostaria de solicitar suporte.';
    final Uri whatsappLaunchUri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    _launchURL(whatsappLaunchUri);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _errorMessage != null
            ? Text(_errorMessage!)
            : Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.gpp_bad_outlined, color: colorScheme.error, size: 80),
              const SizedBox(height: 24),
              Text(
                'Sua Licença Expirou',
                style: textTheme.headlineMedium?.copyWith(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: textTheme.bodyLarge,
                  children: [
                    const TextSpan(text: 'A licença da instituição '),
                    TextSpan(
                      text: _institutionName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' expirou em '),
                    TextSpan(
                      text: _expirationDate,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: '.\n\nPara continuar usando o sistema, por favor, entre em contato com nosso suporte.'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _contactByEmail,
                icon: const Icon(Icons.email_outlined),
                label: const Text('Enviar E-mail'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _contactByWhatsApp,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Contatar via WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // Cor do WhatsApp
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Fazer Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}