// lib/pages/login/login-page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quadra_vendas/pages/admin/register-initial-admin.page.dart';
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
                        validator: (value) => value == null || !value.contains('@') ? 'E-mail inválido' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomInputField(
                        controller: _passwordController,
                        labelText: "Senha",
                        isPassword: true,
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
                const SizedBox(height: 24),
                // TextButton(
                //   child: const Text('Não tem uma conta? Cadastrar Admin'),
                //   onPressed: () {
                //     Navigator.push(
                //         context,
                //         MaterialPageRoute(
                //             builder: (context) => const RegisterInitialAdminPage()));
                //   },
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}