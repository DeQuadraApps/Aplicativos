// lib/pages/auth/signup_page.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:quadra_vendas/pages/terms/terms-of-use.page.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';
import 'package:quadra_vendas/widgets/elevated-button.widget.dart';
import 'package:quadra_vendas/widgets/text-form-field.widget.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _cpfController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedBirthDate;
  final _cpfMask = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final _dateMask = MaskTextInputFormatter(mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});

  bool _isLoading = false;
  // O estado do checkbox ainda é necessário
  bool _termsAccepted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _cpfController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedBirthDate ?? DateTime(2000), firstDate: DateTime(1900), lastDate: DateTime.now());
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  /// =======================================================
  /// FUNÇÃO DE CADASTRO ATUALIZADA
  /// A verificação dos termos agora é feita pelo formulário
  /// =======================================================
  Future<void> _signUp() async {
    // Agora esta única linha valida TODOS os campos, incluindo o checkbox.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());
      if (userCredential.user != null) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid, 'fullName': _nameController.text.trim(), 'cpf': _cpfController.text.trim(),
          'birthDate': _selectedBirthDate != null ? Timestamp.fromDate(_selectedBirthDate!) : null,
          'email': _emailController.text.trim(), 'createdAt': Timestamp.now(), 'institutionId': null,
        });
        if(mounted) AppSnackBar.showSuccess(context, message: "Cadastro realizado! Configure sua instituição.");
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') { message = 'A senha fornecida é muito fraca.'; }
      else if (e.code == 'email-already-in-use') { message = 'Este e-mail já está em uso.'; }
      else { message = 'Ocorreu um erro no cadastro.'; }
      if(mounted) AppSnackBar.showError(context, message: message);
    } catch (e) {
      if(mounted) AppSnackBar.showError(context, message: "Ocorreu um erro inesperado.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("Criar Conta")),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ... Seus TextFormFields (sem alterações) ...
                CustomInputField(controller: _nameController, labelText: "Nome Completo", validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _cpfController, decoration: const InputDecoration(labelText: "CPF"), keyboardType: TextInputType.number, inputFormatters: [_cpfMask], validator: (value) => value == null || value.length < 14 ? 'CPF inválido' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _birthDateController, decoration: const InputDecoration(labelText: "Data de Aniversário", suffixIcon: Icon(Icons.calendar_today)), readOnly: true, onTap: () => _selectDate(context), validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null),
                const SizedBox(height: 16),
                CustomInputField(controller: _emailController, labelText: "E-mail", keyboardType: TextInputType.emailAddress, validator: (value) => value == null || !value.contains('@') ? 'E-mail inválido' : null),
                const SizedBox(height: 16),
                CustomInputField(controller: _passwordController, labelText: "Senha", isPassword: true, validator: (value) => value == null || value.length < 6 ? 'A senha deve ter no mínimo 6 caracteres' : null),
                const SizedBox(height: 16),

                /// =======================================================
                /// CHECKBOX COM VALIDAÇÃO FORMAL
                /// =======================================================
                FormField<bool>(
                  builder: (state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          value: _termsAccepted,
                          onChanged: (bool? value) {
                            setState(() {
                              _termsAccepted = value ?? false;
                              // Informa o FormField sobre a mudança
                              state.didChange(_termsAccepted);
                            });
                          },
                          title: Text.rich(
                            TextSpan(
                              text: 'Eu li e aceito os ',
                              style: Theme.of(context).textTheme.bodySmall,
                              children: [
                                TextSpan(
                                  text: 'Termos e Condições de Uso',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsOfUsePage()));
                                    },
                                ),
                              ],
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          // Muda a cor da borda do checkbox para vermelho se houver um erro
                          activeColor: state.hasError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                        ),
                        // Mostra a mensagem de erro se a validação falhar
                        if (state.hasError)
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Text(
                              state.errorText!,
                              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                            ),
                          ),
                      ],
                    );
                  },
                  // A REGRA DE VALIDAÇÃO
                  validator: (value) {
                    if (!_termsAccepted) {
                      return 'Você deve aceitar os termos para continuar.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),
                ShadowButton(
                  text: "Cadastrar",
                  onPressed: _signUp,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}