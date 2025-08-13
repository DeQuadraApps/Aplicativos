import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/pages/clients/add-edit-client.page.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';

class ClientsListPage extends StatefulWidget {
  const ClientsListPage({super.key});

  @override
  State<ClientsListPage> createState() => _ClientsListPageState();
}

class _ClientsListPageState extends State<ClientsListPage> {
  String? _institutionId;
  UserModel? _currentUserData;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _clientsStream;

  @override
  void initState() {
    super.initState();
    _initializeUserDataAndStream();
  }

  Future<void> _initializeUserDataAndStream() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!mounted) return;

      _currentUserData = UserModel.fromFirestore(userDoc);
      _institutionId = _currentUserData!.institutionId;

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('institutions').doc(_institutionId)
          .collection('clients');

      // A lógica chave: se o utilizador não for admin, filtra pelo seu próprio ID.
      if (_currentUserData!.role != 'admin') {
        query = query.where('salespersonId', isEqualTo: user.uid);
      }

      setState(() {
        _clientsStream = query.orderBy('companyName').snapshots();
      });
    } catch (e) {
      if(mounted) {
        setState(() {
          _clientsStream = Stream.error("Falha ao inicializar dados do usuário: $e");
        });
      }
    }
  }

  void _deleteClient(String clientId) {
    if (_institutionId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza que deseja excluir este cliente? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('institutions').doc(_institutionId)
                    .collection('clients').doc(clientId)
                    .delete();
                if (mounted) {
                  Navigator.pop(context);
                  AppSnackBar.showSuccess(context, message: 'Cliente excluído com sucesso.');
                }
              } catch (e) {
                if (mounted) {
                  AppSnackBar.showError(context, message: 'Erro ao excluir cliente.');
                }
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_currentUserData?.role == 'admin' ? 'Todos os Clientes' : 'Meus Clientes')),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (_institutionId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddEditClientPage(institutionId: _institutionId!)),
              );
            }
          },
          child: const Icon(Icons.add),
        ),
        body: _clientsStream == null
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _clientsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint("===================== ERRO AO CARREGAR CLIENTES =====================");
              debugPrint("VERIFIQUE SE O ERRO ABAIXO CONTÉM UM LINK PARA CRIAR ÍNDICE:");
              debugPrint("${snapshot.error}");
              debugPrint("=====================================================================");
              return Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Erro ao carregar clientes.\n\nVerifique o console de depuração para mais detalhes e para um possível link de criação de índice no Firebase.", textAlign: TextAlign.center),
              ));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('Nenhum cliente cadastrado.'));
            }

            final clients = snapshot.data!.docs.map((doc) => Client.fromFirestore(doc)).toList();
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: clients.length,
              itemBuilder: (context, index) {
                final client = clients[index];
                return Card(
                  child: ListTile(
                    title: Text(client.companyName),
                    subtitle: Text(client.cnpj),
                    trailing: PopupMenuButton(
                      onSelected: (value) {
                        if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AddEditClientPage(
                              institutionId: _institutionId!,
                              client: client,
                            )),
                          );
                        } else if (value == 'delete') {
                          _deleteClient(client.id!);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_note, size: 20),
                              SizedBox(width: 8),
                              Text('Editar Cliente'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_forever, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Excluir Cliente'),
                              ],
                            )),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}