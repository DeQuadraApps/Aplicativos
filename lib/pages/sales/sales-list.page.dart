// lib/pages/sales/sales-list.page.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/models/sale.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/pages/sales/edit-sale.page.dart';
import 'package:quadra_vendas/services/pdf-sale.service.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';
import 'package:share_plus/share_plus.dart';

class SalesListPage extends StatefulWidget {
  const SalesListPage({super.key});

  @override
  State<SalesListPage> createState() => _SalesListPageState();
}

class _SalesListPageState extends State<SalesListPage> {
  String? _institutionId;
  String _institutionName = '';
  UserModel? _currentUserData;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _salesStream;

  // ✨ ESTADOS PARA A PESQUISA
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeUserDataAndStream();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // +++ HELPER: Verifica Permissão de Deletar +++
  bool get _canDeleteSale {
    if (_currentUserData == null) return false;
    if (_currentUserData!.role == 'admin') return true;
    return _currentUserData!.permissions['canDeleteSale'] == true;
  }

  // +++ HELPER: Verifica Permissão de Marcar Entregue +++
  bool get _canMarkDelivered {
    if (_currentUserData == null) return false;
    if (_currentUserData!.role == 'admin') return true;
    return _currentUserData!.permissions['canMarkDelivered'] == true;
  }

  Future<void> _initializeUserDataAndStream() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!mounted) return;

      _currentUserData = UserModel.fromFirestore(userDoc);
      _institutionId = _currentUserData!.institutionId;

      final instDoc = await FirebaseFirestore.instance.collection('institutions').doc(_institutionId).get();
      _institutionName = instDoc.data()?['name'] ?? '';

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('institutions').doc(_institutionId)
          .collection('sales');

      if (_currentUserData!.role != 'admin') {
        query = query.where('userId', isEqualTo: user.uid);
      }

      setState(() {
        _salesStream = query.orderBy('saleDate', descending: true).snapshots();
      });
    } catch (e) {
      if(mounted) {
        debugPrint("Falha ao inicializar dados e stream de vendas: $e");
        setState(() {
          _salesStream = Stream.error("Falha ao carregar dados do usuário: $e");
        });
      }
    }
  }

  Future<void> _toggleDeliveryStatus(Sale sale) async {
    // +++ VERIFICAÇÃO DE PERMISSÃO ANTES DA AÇÃO +++
    if (!_canMarkDelivered) {
      AppSnackBar.showError(context, message: 'Você não tem permissão para alterar o status de entrega.');
      return;
    }

    if (_institutionId == null) return;

    final currentStatus = sale.isDelivered;
    final newStatus = !currentStatus;

    try {
      await FirebaseFirestore.instance
          .collection('institutions').doc(_institutionId)
          .collection('sales').doc(sale.id)
          .update({'isDelivered': newStatus});

      if (mounted) {
        String msg = newStatus ? 'Venda marcada como ENTREGUE.' : 'Venda marcada como PENDENTE.';
        AppSnackBar.showSuccess(context, message: msg);
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: 'Erro ao atualizar status.');
    }
  }

  void _deleteSale(String saleId) {
    // +++ VERIFICAÇÃO DE PERMISSÃO ANTES DA AÇÃO +++
    if (!_canDeleteSale) {
      AppSnackBar.showError(context, message: 'Você não tem permissão para excluir vendas.');
      return;
    }

    if (_institutionId == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza que deseja excluir esta venda? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('institutions').doc(_institutionId).collection('sales').doc(saleId).delete();
                if (mounted) {
                  Navigator.pop(context);
                  AppSnackBar.showSuccess(context, message: 'Venda excluída com sucesso.');
                }
              } catch (e) {
                if (mounted) AppSnackBar.showError(context, message: 'Erro ao excluir venda.');
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<Client?> _fetchFullClient(String clientId) async {
    if (_institutionId == null) return null;
    final clientDoc = await FirebaseFirestore.instance
        .collection('institutions').doc(_institutionId!)
        .collection('clients').doc(clientId).get();
    return clientDoc.exists ? Client.fromFirestore(clientDoc) : null;
  }

  Future<void> _showPdfPreview(Sale sale) async {
    final client = await _fetchFullClient(sale.clientId);
    if (client == null) {
      if (mounted) AppSnackBar.showError(context, message: 'Cliente desta venda não encontrado.');
      return;
    }
    final fullSaleData = Sale(client: client, id: sale.id, clientName: sale.clientName, clientId: sale.clientId, items: sale.items, totalAmount: sale.totalAmount, withInvoice: sale.withInvoice, newClient: sale.newClient, observations: sale.observations, saleDate: sale.saleDate, userId: sale.userId, paymentMethod: sale.paymentMethod, salespersonName: sale.salespersonName, isDelivered: sale.isDelivered);

    final pdfService = PdfSaleService(sale: fullSaleData, institutionName: _institutionName);
    final pdfBytes = await pdfService.generatePdf();
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }

  Future<void> _shareSale(Sale sale) async {
    AppSnackBar.showInfo(context, message: "A preparar documento para partilha...");
    final client = await _fetchFullClient(sale.clientId);
    if (client == null) {
      if (mounted) AppSnackBar.showError(context, message: 'Cliente desta venda não encontrado.');
      return;
    }
    try {
      final fullSaleData = Sale(client: client, id: sale.id, clientName: sale.clientName, clientId: sale.clientId, items: sale.items, totalAmount: sale.totalAmount, withInvoice: sale.withInvoice, newClient: sale.newClient, observations: sale.observations, saleDate: sale.saleDate, userId: sale.userId, paymentMethod: sale.paymentMethod, salespersonName: sale.salespersonName, isDelivered: sale.isDelivered);

      final pdfService = PdfSaleService(sale: fullSaleData, institutionName: _institutionName);
      final pdfBytes = await pdfService.generatePdf();
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/venda_${sale.id}.pdf').create();
      await file.writeAsBytes(pdfBytes);
      final xfile = XFile(file.path);
      await Share.shareXFiles([xfile], text: 'Segue em anexo a ordem de venda para o cliente ${sale.clientName}.');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: 'Erro ao partilhar a venda.');
    }
  }


  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: Text(_currentUserData?.role == 'admin' ? 'Histórico de Vendas' : 'Minhas Vendas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Pesquisar por cliente ou data (dd/mm/aaaa)...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
                    : null,
              ),
            ),
          ),

          Expanded(
            child: _salesStream == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _salesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Erro ao carregar vendas."));
                }
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Nenhuma venda registrada ainda.'));

                final allSales = snapshot.data!.docs.map((doc) => Sale.fromFirestore(doc)).toList();

                final filteredSales = allSales.where((sale) {
                  if (_searchQuery.isEmpty) return true;
                  final queryLower = _searchQuery.toLowerCase();
                  final clientNameLower = sale.clientName.toLowerCase();
                  final formattedDate = dateFormatter.format(sale.saleDate);
                  return clientNameLower.contains(queryLower) || formattedDate.contains(queryLower);
                }).toList();

                if (filteredSales.isEmpty) {
                  return Center(child: Text('Nenhum resultado encontrado para "$_searchQuery"'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredSales.length,
                  itemBuilder: (context, index) {
                    final sale = filteredSales[index];
                    final isDelivered = sale.isDelivered;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: isDelivered
                          ? RoundedRectangleBorder(side: const BorderSide(color: Colors.green, width: 1.5), borderRadius: BorderRadius.circular(12))
                          : null,
                      child: ExpansionTile(
                        leading: isDelivered
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.shopping_bag_outlined),
                        title: Text(
                            sale.clientName,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDelivered ? Colors.green[800] : null
                            )
                        ),
                        subtitle: Text('Data: ${dateFormatter.format(sale.saleDate)} • Pgto: ${sale.paymentMethod}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currencyFormatter.format(sale.totalAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                switch (value) {
                                  case 'toggle_delivery':
                                    _toggleDeliveryStatus(sale);
                                    break;
                                  case 'edit':
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => EditSalePage(sale: sale)));
                                    break;
                                  case 'delete':
                                    _deleteSale(sale.id!);
                                    break;
                                  case 'pdf':
                                    _showPdfPreview(sale);
                                    break;
                                  case 'share':
                                    _shareSale(sale);
                                    break;
                                }
                              },
                              itemBuilder: (context) {
                                // +++ FILTRA OS ITENS DO MENU BASEADO NA PERMISSÃO +++
                                final List<PopupMenuEntry<String>> menuItems = [];

                                // 1. Marcar Entregue
                                if (_canMarkDelivered) {
                                  menuItems.add(
                                    PopupMenuItem(
                                      value: 'toggle_delivery',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                            isDelivered ? Icons.cancel_outlined : Icons.check_circle_outline,
                                            color: isDelivered ? Colors.orange : Colors.green
                                        ),
                                        title: Text(isDelivered ? 'Marcar como Pendente' : 'Marcar como Entregue'),
                                      ),
                                    ),
                                  );
                                  menuItems.add(const PopupMenuDivider());
                                }

                                // 2. Itens Comuns
                                menuItems.addAll([
                                  const PopupMenuItem(value: 'edit', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('Editar'))),
                                  const PopupMenuItem(value: 'pdf', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.picture_as_pdf_outlined), title: Text('Ver PDF'))),
                                  const PopupMenuItem(value: 'share', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.share_outlined), title: Text('Partilhar'))),
                                ]);

                                // 3. Excluir
                                if (_canDeleteSale) {
                                  menuItems.add(
                                    const PopupMenuItem(value: 'delete', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_forever_outlined, color: Colors.red), title: Text('Excluir', style: TextStyle(color: Colors.red)))),
                                  );
                                }

                                return menuItems;
                              },
                            ),
                          ],
                        ),
                        children: [
                          const Divider(height: 1),
                          for (final item in sale.items)
                            ListTile(
                              dense: true,
                              title: Text(item.product.name),
                              leading: Text('${item.quantity}x'),
                              trailing: Text(currencyFormatter.format(item.totalPrice)),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}