// lib/pages/admin/manage-institutions.page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- Import necessário
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/widgets/institution-form-dialog.dart';

class ManageInstitutionsPage extends StatelessWidget {
  const ManageInstitutionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Instituições'),
        actions: [
          // --- BOTÃO DE SAIR ---
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => showDialog(
          context: context,
          builder: (c) => const InstitutionFormDialog(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('institutions').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) return const Center(child: Text('Nenhuma instituição encontrada.'));

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;
              final expires = (data['licenseExpiresAt'] as Timestamp?)?.toDate();
              final isActive = data['status'] == 'active';

              return ListTile(
                title: Text(data['name'] ?? 'Sem nome'),
                subtitle: Text('Expira em: ${expires != null ? DateFormat('dd/MM/yyyy').format(expires) : 'N/A'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                        radius: 6,
                        backgroundColor: isActive ? Colors.green : Colors.red
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (c) => InstitutionFormDialog(instId: id, data: data),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}