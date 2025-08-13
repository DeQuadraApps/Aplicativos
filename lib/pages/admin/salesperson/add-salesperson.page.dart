import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';
import 'package:quadra_vendas/widgets/elevated-button.widget.dart';
import 'package:quadra_vendas/widgets/text-form-field.widget.dart';

class AddSalespersonPage extends StatefulWidget {
  final String institutionId;

  const AddSalespersonPage({super.key, required this.institutionId});

  @override
  State<AddSalespersonPage> createState() => _AddSalespersonPageState();
}

class _AddSalespersonPageState extends State<AddSalespersonPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createSalesperson() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Cria uma instância temporária do Firebase App para não deslogar o admin
      final tempApp = await Firebase.initializeApp(
        name: 'temp_signup',
        options: Firebase.app().options,
      );
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      UserCredential userCredential = await tempAuth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim());

      if (userCredential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'uid': userCredential.user!.uid,
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': 'employee', // Define o papel como vendedor
          'institutionId': widget.institutionId, // Vincula à instituição do Admin
          'createdAt': Timestamp.now(),
          'status': 'active'
        });
        if (mounted) {
          AppSnackBar.showSuccess(context, message: "Vendedor cadastrado com sucesso!");
          Navigator.pop(context);
        }
      }
      await tempApp.delete();
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'A senha fornecida é muito fraca.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Este e-mail já está em uso.';
      } else {
        message = 'Ocorreu um erro no cadastro.';
      }
      if (mounted) AppSnackBar.showError(context, message: message);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: "Ocorreu um erro inesperado: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Novo Vendedor")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomInputField(
                  controller: _nameController,
                  labelText: "Nome Completo",
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Campo obrigatório' : null),
              const SizedBox(height: 16),
              CustomInputField(
                  controller: _emailController,
                  labelText: "E-mail",
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                  value == null || !value.contains('@') ? 'E-mail inválido' : null),
              const SizedBox(height: 16),
              CustomInputField(
                  controller: _passwordController,
                  labelText: "Senha Provisória",
                  isPassword: true,
                  validator: (value) => value == null || value.length < 6
                      ? 'A senha deve ter no mínimo 6 caracteres'
                      : null),
              const SizedBox(height: 24),
              ShadowButton(
                text: "Cadastrar Vendedor",
                onPressed: _createSalesperson,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}