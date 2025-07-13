// lib/pages/onboarding/create_institution_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';
import 'package:quadra_vendas/widgets/elevated-button.widget.dart';
import 'package:quadra_vendas/widgets/text-form-field.widget.dart';

class CreateInstitutionPage extends StatefulWidget {
  const CreateInstitutionPage({super.key});

  @override
  State<CreateInstitutionPage> createState() => _CreateInstitutionPageState();
}

class _CreateInstitutionPageState extends State<CreateInstitutionPage> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _createAndLinkInstitution() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Segurança: se por algum motivo não houver usuário, não faz nada.
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Cria o documento da instituição no Firestore
      final institutionDoc = await FirebaseFirestore.instance.collection('institutions').add({
        'name': _nameController.text.trim(),
        // A licença padrão será de 1 ano a partir de hoje
        'licenseExpiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'createdAt': Timestamp.now(),
        'status': 'active',
        'ownerId': currentUser.uid, // Guarda quem é o dono da instituição
      });

      // 2. Vincula o usuário a esta nova instituição
      // Este é o passo que completa o onboarding!
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'institutionId': institutionDoc.id,
        'role': 'admin', // O primeiro usuário é o admin
      });

      // Não precisamos navegar! O AuthGate vai detectar a mudança e redirecionar
      // automaticamente na próxima reconstrução do widget.

    } catch (e) {
      AppSnackBar.showError(context, message: "Erro ao criar instituição.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Configuração Inicial"),
          automaticallyImplyLeading: false, // Remove a seta de "voltar"
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
                    "Vamos cadastrar sua instituição",
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Este é o último passo antes de começar a usar o app.",
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  CustomInputField(
                    controller: _nameController,
                    labelText: "Nome da Instituição",
                    validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 32),
                  ShadowButton(
                    text: "Salvar e Continuar",
                    onPressed: _createAndLinkInstitution,
                    isLoading: _isLoading,
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}