// lib/widgets/institution-form.dialog.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart'; // Seu widget

class InstitutionFormDialog extends StatefulWidget {
  final String? instId;
  final Map<String, dynamic>? data;

  const InstitutionFormDialog({super.key, this.instId, this.data});

  @override
  State<InstitutionFormDialog> createState() => _InstitutionFormDialogState();
}

class _InstitutionFormDialogState extends State<InstitutionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController(); // Apenas para criar novo
  final _passController = TextEditingController();  // Apenas para criar novo

  DateTime _licenseDate = DateTime.now().add(const Duration(days: 365));
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _nameController.text = widget.data!['name'];
      _isActive = widget.data!['status'] == 'active';
      if (widget.data!['licenseExpiresAt'] != null) {
        _licenseDate = (widget.data!['licenseExpiresAt'] as Timestamp).toDate();
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (widget.instId == null) {
        // === CRIAÇÃO DE NOVA INSTITUIÇÃO ===
        // 1. Criar usuário secundário sem deslogar o atual
        FirebaseApp secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryApp',
          options: Firebase.app().options,
        );

        UserCredential userCred = await FirebaseAuth.instanceFor(app: secondaryApp)
            .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passController.text.trim()
        );

        String newOwnerId = userCred.user!.uid;

        // 2. Criar Documento da Instituição
        DocumentReference instRef = await FirebaseFirestore.instance.collection('institutions').add({
          'name': _nameController.text.trim(),
          'ownerId': newOwnerId,
          'status': _isActive ? 'active' : 'inactive',
          'licenseExpiresAt': Timestamp.fromDate(_licenseDate),
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 3. Criar Documento do User (Admin da Instituição)
        await FirebaseFirestore.instance.collection('users').doc(newOwnerId).set({
          'uid': newOwnerId,
          'email': _emailController.text.trim(),
          'fullName': 'Admin ${_nameController.text}',
          'role': 'admin', // Role de admin da empresa
          'institutionId': instRef.id,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Limpeza do app secundário
        await secondaryApp.delete();

      } else {
        // === EDIÇÃO ===
        await FirebaseFirestore.instance.collection('institutions').doc(widget.instId).update({
          'name': _nameController.text.trim(),
          'status': _isActive ? 'active' : 'inactive',
          'licenseExpiresAt': Timestamp.fromDate(_licenseDate),
        });
      }

      if(mounted) {
        Navigator.pop(context);
        AppSnackBar.showSuccess(context, message: 'Salvo com sucesso!'); // Adapte para success se tiver
      }

    } catch (e) {
      if(mounted) AppSnackBar.showError(context, message: 'Erro: $e');
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.instId != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Instituição' : 'Nova Instituição'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome da Empresa'),
                validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
              ),
              SizedBox(height: 10,),
              if (!isEditing) ...[
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'E-mail do Admin'),
                  validator: (v) => !v!.contains('@') ? 'E-mail inválido' : null,
                ),
                SizedBox(height: 10,),
                TextFormField(
                  controller: _passController,
                  decoration: const InputDecoration(labelText: 'Senha Inicial'),
                  obscureText: true,
                  validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                ),
              ],
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Ativo?'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              ListTile(
                title: const Text('Expiração da Licença'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_licenseDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: _licenseDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2050)
                  );
                  if (d != null) setState(() => _licenseDate = d);
                },
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading ? const CircularProgressIndicator() : const Text('Salvar')
        ),
      ],
    );
  }
}