// lib/pages/login/login-page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';
import 'package:quadra_vendas/widgets/elevated-button.widget.dart';
import 'package:quadra_vendas/widgets/text-form-field.widget.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForIosPwa();
    });
    super.initState();
  }

  void _checkForIosPwa() {
    if (kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => const IosInstallGuide(),
      );
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // +++ VERIFICAÇÃO DE STATUS APÓS O LOGIN +++
      if (userCredential.user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (userDoc.exists && userDoc.data()?['status'] == 'inactive') {
          // Se o utilizador estiver inativo, desloga-o imediatamente e mostra um erro.
          await FirebaseAuth.instance.signOut();
          if (mounted) AppSnackBar.showError(context, message: 'A sua conta foi desativada. Por favor, contacte o administrador.');
        }
        // Se estiver ativo, o AuthGate fará o resto.
      }

    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'invalid-credential') {
        message = 'E-mail ou senha inválidos.';
      } else {
        message = 'Ocorreu um erro. Tente novamente.';
      }
      if(mounted) AppSnackBar.showError(context, message: message);

    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Bem-vindo!', textAlign: TextAlign.center, style: textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text('Acesse sua conta Quadra Vendas', textAlign: TextAlign.center, style: textTheme.bodyMedium),
                const SizedBox(height: 48),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      CustomInputField(
                        controller: _emailController,
                        labelText: "E-mail",
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) => value == null || !value.contains('@') ? 'E-mail inválido' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomInputField(
                        controller: _passwordController,
                        labelText: "Senha",
                        isPassword: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        validator: (value) => value == null || value.length < 6 ? 'A senha deve ter no mínimo 6 caracteres' : null,
                      ),
                      const SizedBox(height: 32),
                      ShadowButton(
                        text: "Login",
                        onPressed: _login,
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class IosInstallGuide extends StatelessWidget {
  const IosInstallGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.download_rounded, color: Colors.blue),
              const SizedBox(width: 12),
              Text(
                'Instalar App',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          const Text('Para instalar o Quadra Vendas no seu iPhone:'),
          const SizedBox(height: 16),
          _buildStep(
              icon: Icons.ios_share,
              text: '1. Toque no botão "Compartilhar" do navegador.'
          ),
          const SizedBox(height: 12),
          _buildStep(
              icon: Icons.add_box_outlined,
              text: '2. Selecione "Adicionar à Tela de Início".'
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStep({required IconData icon, required String text}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24, color: Colors.blue),
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
      ],
    );
  }
}