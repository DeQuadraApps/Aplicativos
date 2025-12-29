// lib/widgets/institution-form-dialog.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';

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
  final _emailController = TextEditingController();
  final _passController = TextEditingController();

  DateTime _licenseDate = DateTime.now().add(const Duration(days: 365));
  bool _isActive = true;
  bool _isLoading = false;

  // --- NOVO: Controle do Plano ---
  String _selectedPlan = 'START';
  final List<String> _planOptions = ['START', 'CONTROL', 'PERFORMANCE', 'ELITE'];

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _nameController.text = widget.data!['name'];
      _isActive = widget.data!['status'] == 'active';

      // Carrega o plano existente ou define START como fallback
      if (widget.data!['plan'] != null) {
        _selectedPlan = widget.data!['plan'].toString().toUpperCase();
        // Segurança: se o plano salvo não existir na lista (ex: plano antigo), adiciona na lista visualmente
        if (!_planOptions.contains(_selectedPlan)) {
          _planOptions.add(_selectedPlan);
        }
      }

      if (widget.data!['licenseExpiresAt'] != null) {
        _licenseDate = (widget.data!['licenseExpiresAt'] as Timestamp).toDate();
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Dados básicos de contadores para inicializar
      final initialFeatures = {
        'nfs_emitted': 0,
        'whatsapp_sent': 0,
        'users_extra': 0,
      };

      if (widget.instId == null) {
        // === CRIAÇÃO DE NOVA INSTITUIÇÃO ===
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

        // Cria doc com tudo inicializado
        DocumentReference instRef = await FirebaseFirestore.instance.collection('institutions').add({
          'name': _nameController.text.trim(),
          'ownerId': newOwnerId,
          'status': _isActive ? 'active' : 'inactive',
          'licenseExpiresAt': Timestamp.fromDate(_licenseDate),
          'createdAt': FieldValue.serverTimestamp(),

          'plan': _selectedPlan,
          'plan_status': 'active',
          'features_usage': initialFeatures, // <--- Aqui cria na nova
          'billing_cycle_start': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance.collection('users').doc(newOwnerId).set({
          'uid': newOwnerId,
          'email': _emailController.text.trim(),
          'fullName': 'Admin ${_nameController.text}',
          'role': 'admin',
          'institutionId': instRef.id,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });

        await secondaryApp.delete();

      } else {
        // === EDIÇÃO (CORREÇÃO AQUI) ===

        // Prepara os dados para atualizar
        Map<String, dynamic> updateData = {
          'name': _nameController.text.trim(),
          'status': _isActive ? 'active' : 'inactive',
          'licenseExpiresAt': Timestamp.fromDate(_licenseDate),
          'plan': _selectedPlan,
        };

        // Verifica se no dado original (antes de abrir o modal) já tinha os contadores
        // Se não tiver (null), a gente cria agora.
        bool hasFeatures = widget.data != null && widget.data!['features_usage'] != null;

        if (!hasFeatures) {
          updateData['features_usage'] = initialFeatures; // Cria se não existir
          updateData['plan_status'] = 'active'; // Garante status ativo
          updateData['billing_cycle_start'] = FieldValue.serverTimestamp();
        }

        await FirebaseFirestore.instance
            .collection('institutions')
            .doc(widget.instId)
            .update(updateData);
      }

      if(mounted) {
        Navigator.pop(context);
        AppSnackBar.showSuccess(context, message: 'Salvo com sucesso!');
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
              const SizedBox(height: 15),

              // --- SELETOR DE PLANO ---
              DropdownButtonFormField<String>(
                value: _selectedPlan,
                decoration: const InputDecoration(
                  labelText: 'Plano de Assinatura',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                ),
                items: _planOptions.map((plan) {
                  return DropdownMenuItem(
                    value: plan,
                    child: Text(
                        plan,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: plan == 'ELITE' ? Colors.amber[800] :
                            plan == 'PERFORMANCE' ? Colors.blue[800] : Colors.black87
                        )
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPlan = val);
                },
              ),
              const SizedBox(height: 15),

              if (!isEditing) ...[
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'E-mail do Admin'),
                  validator: (v) => !v!.contains('@') ? 'E-mail inválido' : null,
                ),
                const SizedBox(height: 10),
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