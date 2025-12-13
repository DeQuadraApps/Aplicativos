import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';

class ManagePermissionsPage extends StatelessWidget {
  final String institutionId;

  const ManagePermissionsPage({super.key, required this.institutionId});

  // Configuração centralizada das permissões para reuso
  final List<Map<String, String>> permissionsConfig = const [
    {'key': 'canMarkDelivered', 'label': 'Marcar Venda como Entregue'},
    {'key': 'canDeleteSale', 'label': 'Excluir Venda'},
    {'key': 'canDeleteClient', 'label': 'Excluir Cliente'},
    {'key': 'canEditClient', 'label': 'Editar Cliente'},
    {'key': 'canChangePrice', 'label': 'Alterar Preço na Venda'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissões'),
        actions: [
          // BOTÃO DE AÇÃO EM MASSA
          IconButton(
            icon: const Icon(Icons.playlist_add_check),
            tooltip: 'Aplicar permissões a todos',
            onPressed: () => _showBulkActionDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('institutionId', isEqualTo: institutionId)
            .where('role', whereIn: ['employee', 'salesperson'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Erro ao carregar equipe.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Nenhum vendedor encontrado.'));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_,__) => const Divider(),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final userId = docs[index].id;
              final name = data['fullName'] ?? 'Sem Nome';
              final email = data['email'] ?? '';

              // Garante que é um Map editável
              final permissions = Map<String, dynamic>.from(data['permissions'] ?? {});

              return ListTile(
                leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
                title: Text(name),
                subtitle: Text(email),
                trailing: const Icon(Icons.lock_person_outlined),
                onTap: () => _showPermissionEditor(context, userId, name, permissions),
              );
            },
          );
        },
      ),
    );
  }

  // --- 1. DIALOG PARA AÇÃO EM MASSA (TODOS OS USUÁRIOS) ---
  void _showBulkActionDialog(BuildContext context) {
    // Estado local do Dialog para marcar quais permissões aplicar
    Map<String, bool> bulkSelections = {
      for (var p in permissionsConfig) p['key']!: false
    };

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Aplicar a TODOS'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Selecione as permissões que deseja ATIVAR para todos os vendedores listados.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    // Checkbox "Marcar Todas" no dialog
                    CheckboxListTile(
                      title: const Text('Selecionar Todas', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: bulkSelections.values.every((v) => v),
                      onChanged: (val) {
                        setState(() {
                          bulkSelections.updateAll((key, value) => val ?? false);
                        });
                      },
                    ),
                    const Divider(),
                    ...permissionsConfig.map((perm) {
                      final key = perm['key']!;
                      return CheckboxListTile(
                        title: Text(perm['label']!),
                        value: bulkSelections[key],
                        onChanged: (val) {
                          setState(() => bulkSelections[key] = val ?? false);
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _applyBulkPermissions(context, bulkSelections);
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _applyBulkPermissions(BuildContext context, Map<String, bool> selections) async {
    // Filtra apenas as permissões que foram marcadas como TRUE para aplicar
    // Se quiser que o false desabilite, remova o .where, mas geralmente bulk action é aditiva.
    // Aqui vou fazer: O que estiver marcado será setado como TRUE. O que não estiver, IGNORA (não desativa).
    // Se quiser que FORCE o estado (ativar o que ta marcado, desativar o que nao ta), me avise.

    // Assumindo lógica: "Aplicar True onde estiver marcado"
    final permissionsToEnable = selections.entries.where((e) => e.value).map((e) => e.key).toList();

    if (permissionsToEnable.isEmpty) {
      AppSnackBar.showInfo(context, message: 'Nenhuma permissão selecionada.');
      return;
    }

    AppSnackBar.showInfo(context, message: 'Aplicando permissões...');

    try {
      // 1. Buscar todos os vendedores
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('institutionId', isEqualTo: institutionId)
          .where('role', whereIn: ['employee', 'salesperson'])
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in snapshot.docs) {
        // Prepara o update
        Map<String, dynamic> updateData = {};
        for (var key in permissionsToEnable) {
          updateData['permissions.$key'] = true;
        }

        // Se quiser que desmarque as outras, descomente abaixo e mude a lógica acima:
        /*
        for (var key in selections.keys) {
           updateData['permissions.$key'] = selections[key];
        }
        */

        batch.update(doc.reference, updateData);
      }

      await batch.commit();
      if (context.mounted) AppSnackBar.showSuccess(context, message: 'Permissões aplicadas a todos com sucesso!');

    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, message: 'Erro ao aplicar em massa: $e');
    }
  }

  // --- 2. EDITOR INDIVIDUAL (MANTIDO IGUAL, SÓ REFATORADO PARA USAR A LISTA CONST) ---
  void _showPermissionEditor(BuildContext context, String userId, String name, Map<String, dynamic> currentPermissions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {

            bool areAllEnabled = permissionsConfig.every(
                    (perm) => currentPermissions[perm['key']] == true
            );

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Permissões: $name', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text('Habilitar Todos', style: TextStyle(fontWeight: FontWeight.bold)),
                    value: areAllEnabled,
                    activeColor: Theme.of(context).primaryColor,
                    onChanged: (bool newValue) async {
                      setModalState(() {
                        for (var perm in permissionsConfig) {
                          currentPermissions[perm['key']!] = newValue;
                        }
                      });

                      Map<String, dynamic> batchUpdate = {};
                      for (var perm in permissionsConfig) {
                        batchUpdate['permissions.${perm['key']}'] = newValue;
                      }

                      try {
                        await FirebaseFirestore.instance.collection('users').doc(userId).update(batchUpdate);
                      } catch (e) {
                        debugPrint('Erro: $e');
                      }
                    },
                  ),
                  const Divider(thickness: 1.5),

                  ...permissionsConfig.map((perm) {
                    final key = perm['key']!;
                    final label = perm['label']!;
                    final isAllowed = currentPermissions[key] == true;

                    return SwitchListTile(
                      title: Text(label),
                      value: isAllowed,
                      onChanged: (bool value) async {
                        setModalState(() {
                          currentPermissions[key] = value;
                        });
                        try {
                          await FirebaseFirestore.instance.collection('users').doc(userId).update({
                            'permissions.$key': value
                          });
                        } catch (e) {
                          debugPrint('Erro: $e');
                        }
                      },
                    );
                  }).toList(),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Concluir'),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}