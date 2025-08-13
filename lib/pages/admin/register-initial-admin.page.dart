// lib/pages/admin/register_initial_admin_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';
import 'package:quadra_vendas/widgets/elevated-button.widget.dart';
import 'package:quadra_vendas/widgets/text-form-field.widget.dart';

class RegisterInitialAdminPage extends StatefulWidget {
  const RegisterInitialAdminPage({super.key});

  @override
  State<RegisterInitialAdminPage> createState() =>
      _RegisterInitialAdminPageState();
}

class _RegisterInitialAdminPageState extends State<RegisterInitialAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _institutionNameController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _institutionNameController.dispose();
    _adminNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Cria o usuário Admin e a Instituição vinculada a ele.
  Future<void> _createInitialAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // 1. Cria o usuário no Firebase Authentication
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim());

      final adminUser = userCredential.user;
      if (adminUser == null) {
        throw Exception("Falha ao criar o usuário.");
      }

      // 2. Cria o documento da instituição
      final institutionDoc =
      FirebaseFirestore.instance.collection('institutions').doc();
      await institutionDoc.set({
        'name': _institutionNameController.text.trim(),
        'licenseExpiresAt':
        Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))),
        'createdAt': Timestamp.now(),
        'status': 'active',
        'ownerId': adminUser.uid,
      });

      // 3. Cria o documento do usuário (Admin) e o vincula à instituição
      await FirebaseFirestore.instance.collection('users').doc(adminUser.uid).set({
        'uid': adminUser.uid,
        'fullName': _adminNameController.text.trim(),
        'email': _emailController.text.trim(),
        'institutionId': institutionDoc.id,
        'role': 'admin', // Define o papel como 'admin'
        'createdAt': Timestamp.now(),
      });

      if(mounted) {
        AppSnackBar.showSuccess(context, message: 'Administrador e Instituição criados com sucesso!');
        // O AuthGate irá redirecionar para a HomePage automaticamente
        Navigator.of(context).pop();
      }

    } on FirebaseAuthException catch (e) {
      String message = 'Ocorreu um erro no cadastro.';
      if (e.code == 'weak-password') {
        message = 'A senha fornecida é muito fraca.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Este e-mail já está em uso.';
      }
      if (mounted) AppSnackBar.showError(context, message: message);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: "Ocorreu um erro inesperado.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registrar Admin Inicial"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Cadastro do Administrador",
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Use esta tela apenas uma vez para criar a conta principal.",
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                CustomInputField(
                  controller: _institutionNameController,
                  labelText: "Nome da Instituição/Empresa",
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),
                CustomInputField(
                  controller: _adminNameController,
                  labelText: "Seu Nome Completo (Admin)",
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),
                CustomInputField(
                  controller: _emailController,
                  labelText: "Seu E-mail (Admin)",
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty || !v.contains('@') ? 'E-mail inválido' : null,
                ),
                const SizedBox(height: 16),
                CustomInputField(
                  controller: _passwordController,
                  labelText: "Sua Senha (Admin)",
                  isPassword: true,
                  validator: (v) => v!.isEmpty || v.length < 6 ? 'A senha deve ter no mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 32),
                ShadowButton(
                  text: "Criar Conta Admin",
                  onPressed: _createInitialAdmin,
                  isLoading: _isLoading,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}