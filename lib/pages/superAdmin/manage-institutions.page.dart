// lib/pages/admin/manage-institutions.page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () async => await FirebaseAuth.instance.signOut(),
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
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
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

              // Normaliza o nome do plano
              final planRaw = (data['plan'] ?? 'start').toString();
              final plan = planRaw.toUpperCase();

              // Cores baseadas nos novos planos
              Color planColor;
              switch (plan) {
                case 'ELITE': planColor = Colors.purple; break; // Roxo para Elite
                case 'PERFORMANCE': planColor = Colors.blue; break; // Azul para Performance
                case 'CONTROL': planColor = Colors.cyan; break; // Legado (se houver)
                default: planColor = Colors.grey; // Start
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: planColor.withOpacity(0.2),
                  child: Icon(Icons.business, color: planColor),
                ),
                title: Text(data['name'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // ✨ Etiqueta do Plano
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: planColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            plan,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ✨ Contador de Usuários
                        _UserCounter(institutionId: id),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expires != null
                          ? 'Expira: ${DateFormat('dd/MM/yyyy').format(expires)}'
                          : 'Licença Vitalícia',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: isActive ? 'Ativo' : 'Bloqueado',
                      child: CircleAvatar(
                        radius: 6,
                        backgroundColor: isActive ? Colors.green : Colors.red,
                      ),
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

// ✨ Widget separado para contar usuários sem travar a lista
class _UserCounter extends StatelessWidget {
  final String institutionId;

  const _UserCounter({required this.institutionId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AggregateQuerySnapshot>(
      // Usa COUNT aggregation (muito mais leve e barato que ler os docs)
      future: FirebaseFirestore.instance
          .collection('users')
          .where('institutionId', isEqualTo: institutionId)
          .count()
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
              width: 10, height: 10,
              child: CircularProgressIndicator(strokeWidth: 2)
          );
        }
        final count = snapshot.data!.count;
        return Row(
          children: [
            const Icon(Icons.people, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              "$count usuários",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        );
      },
    );
  }
}