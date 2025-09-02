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

  // ✨ 1. ESTADOS PARA A PESQUISA
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeUserDataAndStream();
    // Adiciona um listener para atualizar a UI quando o texto de pesquisa mudar
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  // ✨ Não esqueça de fazer o dispose do controller
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        body: Column( // ✨ Adicionado Column para acomodar a pesquisa e a lista
          children: [
            // ✨ 2. CAMPO DE PESQUISA
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Pesquisar por nome, CNPJ ou CPF...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _searchController.clear(),
                  )
                      : null,
                ),
              ),
            ),
            // ✨ Envolve o StreamBuilder com Expanded
            Expanded(
              child: _clientsStream == null
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
                      child: Text("Erro ao carregar clientes.\n\nVerifique o console de depuração para mais detalhes.", textAlign: TextAlign.center),
                    ));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Nenhum cliente cadastrado.'));
                  }

                  final allClients = snapshot.data!.docs.map((doc) => Client.fromFirestore(doc)).toList();

                  // ✨ 3. APLICANDO O FILTRO
                  final filteredClients = allClients.where((client) {
                    if (_searchQuery.isEmpty) {
                      return true;
                    }
                    final queryLower = _searchQuery.toLowerCase();
                    final nameLower = client.companyName.toLowerCase();
                    // Como o campo cnpj já armazena CPF também, uma única verificação é suficiente
                    final cnpjLower = client.cnpj.toLowerCase();

                    return nameLower.contains(queryLower) || cnpjLower.contains(queryLower);
                  }).toList();

                  if (filteredClients.isEmpty) {
                    return Center(child: Text('Nenhum resultado encontrado para "$_searchQuery"'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filteredClients.length, // Usa a lista filtrada
                    itemBuilder: (context, index) {
                      final client = filteredClients[index]; // Usa a lista filtrada
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
                                child: ListTile(leading: Icon(Icons.edit_note), title: Text('Editar')),
                              ),
                              const PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(leading: Icon(Icons.delete_forever, color: Colors.red), title: Text('Excluir'))),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}