import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/pages/admin/salesperson/add-salesperson.page.dart';
import 'package:quadra_vendas/pages/admin/salesperson/salesperson-detail.page.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';

class SalespeopleListPage extends StatefulWidget {
  const SalespeopleListPage({super.key});

  @override
  State<SalespeopleListPage> createState() => _SalespeopleListPageState();
}

class _SalespeopleListPageState extends State<SalespeopleListPage> {
  String? _institutionId;

  @override
  void initState() {
    super.initState();
    _fetchInstitutionId();
  }

  Future<void> _fetchInstitutionId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _institutionId = userDoc.data()?['institutionId'];
        });
      }
    }
  }

  /// Desativa um vendedor, impedindo o seu acesso ao sistema.
  Future<void> _deactivateSalesperson(UserModel salesperson) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Desativação'),
        content: Text('Tem a certeza que deseja desativar o vendedor "${salesperson.fullName}"? Ele não poderá mais aceder ao sistema.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Desativar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(salesperson.id)
            .update({'status': 'inactive'});

        if(mounted) AppSnackBar.showSuccess(context, message: 'Vendedor desativado com sucesso.');
      } catch (e) {
        if(mounted) AppSnackBar.showError(context, message: 'Erro ao desativar vendedor.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vendedores')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_institutionId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      AddSalespersonPage(institutionId: _institutionId!)),
            );
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Novo Vendedor',
      ),
      body: _institutionId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // A consulta agora filtra para mostrar apenas vendedores ativos
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('institutionId', isEqualTo: _institutionId)
            .where('role', isEqualTo: 'employee')
            .where('status', isEqualTo: 'active') // <-- FILTRO ADICIONADO
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Erro ao carregar vendedores.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('Nenhum vendedor ativo cadastrado.'));
          }

          final salespeople = snapshot.data!.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: salespeople.length,
            itemBuilder: (context, index) {
              final person = salespeople[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(person.fullName),
                  subtitle: Text(person.email),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SalespersonDetailPage(
                          salesperson: person,
                          institutionId: _institutionId!,
                        ),
                      ),
                    );
                  },
                  // O trailing agora é um menu de opções
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'details') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SalespersonDetailPage(
                              salesperson: person,
                              institutionId: _institutionId!,
                            ),
                          ),
                        );
                      } else if (value == 'deactivate') {
                        _deactivateSalesperson(person);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Text('Ver Detalhes'),
                      ),
                      const PopupMenuItem(
                        value: 'deactivate',
                        child: Text('Desativar', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}