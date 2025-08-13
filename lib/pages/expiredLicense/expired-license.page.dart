// lib/pages/expiredLicense/expired-license.page.dart
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
  String? _userRole; // Para guardar o papel do utilizador

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  /// Busca os dados do utilizador e da instituição para exibir na tela.
  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Utilizador não encontrado.");
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final institutionId = userData?['institutionId'];
      final role = userData?['role'];

      if (institutionId == null) {
        throw Exception("Instituição não vinculada.");
      }

      final institutionDoc = await FirebaseFirestore.instance.collection('institutions').doc(institutionId).get();
      if (institutionDoc.exists) {
        final data = institutionDoc.data()!;
        final timestamp = data['licenseExpiresAt'] as Timestamp;
        setState(() {
          _userRole = role; // Guarda o papel do utilizador
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
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'dequadraapps@gmail.com',
      query: 'subject=Suporte para Licença Expirada - $_institutionName&body=Olá,\n\nA licença da minha instituição ($_institutionName) expirou em $_expirationDate.\n\nGostaria de solicitar suporte para renovação.\n\nObrigado.',
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
    final bool isAdmin = _userRole == 'admin';

    return Scaffold(
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _errorMessage != null
            ? Text(_errorMessage!)
            : isAdmin
            ? _buildAdminView() // Mostra a vista de admin
            : _buildSalespersonView(), // Mostra a vista de vendedor
      ),
    );
  }

  /// Constrói a UI para o Administrador.
  Widget _buildAdminView() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
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
                TextSpan(text: _institutionName, style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: ' expirou em '),
                TextSpan(text: _expirationDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: '.\n\nPara continuar a usar o sistema, por favor, entre em contacto com o nosso suporte para renovar.'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _contactByEmail,
            icon: const Icon(Icons.email_outlined),
            label: const Text('Enviar E-mail'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _contactByWhatsApp,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Contatar via WhatsApp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
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
    );
  }

  /// Constrói a UI para o Vendedor.
  Widget _buildSalespersonView() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.lock_clock, color: colorScheme.secondary, size: 80),
          const SizedBox(height: 24),
          Text(
            'Licença da Instituição Expirada',
            style: textTheme.headlineMedium?.copyWith(color: colorScheme.secondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: textTheme.bodyLarge,
              children: [
                const TextSpan(text: 'O acesso ao sistema foi suspenso porque a licença da instituição '),
                TextSpan(text: _institutionName, style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: ' expirou em '),
                TextSpan(text: _expirationDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: '.\n\nPor favor, entre em contacto com o administrador da sua instituição para solicitar a renovação.'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: const Text('Fazer Logout'),
          ),
        ],
      ),
    );
  }
}