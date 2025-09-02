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

  // ... (seus outros métodos _deleteSale, _fetchFullClient, etc. continuam os mesmos)
  void _deleteSale(String saleId) {
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
    final fullSaleData = Sale(client: client, id: sale.id, clientName: sale.clientName, clientId: sale.clientId, items: sale.items, totalAmount: sale.totalAmount, withInvoice: sale.withInvoice, newClient: sale.newClient, observations: sale.observations, saleDate: sale.saleDate, userId: sale.userId, paymentMethod: sale.paymentMethod, salespersonName: sale.salespersonName);
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
      final fullSaleData = Sale(client: client, id: sale.id, clientName: sale.clientName, clientId: sale.clientId, items: sale.items, totalAmount: sale.totalAmount, withInvoice: sale.withInvoice, newClient: sale.newClient, observations: sale.observations, saleDate: sale.saleDate, userId: sale.userId, paymentMethod: sale.paymentMethod, salespersonName: sale.salespersonName);
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
      body: Column( // ✨ Adicionado Column para acomodar a pesquisa e a lista
        children: [
          // ✨ 2. CAMPO DE PESQUISA
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
          // ✨ Envolve o StreamBuilder com Expanded
          Expanded(
            child: _salesStream == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _salesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint("ERRO AO CARREGAR VENDAS: ${snapshot.error}");
                  return Center(child: Text("Erro ao carregar vendas. Verifique o console."));
                }
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Nenhuma venda registrada ainda.'));

                final allSales = snapshot.data!.docs.map((doc) => Sale.fromFirestore(doc)).toList();

                // ✨ 3. APLICANDO O FILTRO
                final filteredSales = allSales.where((sale) {
                  if (_searchQuery.isEmpty) {
                    return true; // Mostra todos se a pesquisa estiver vazia
                  }
                  final queryLower = _searchQuery.toLowerCase();
                  final clientNameLower = sale.clientName.toLowerCase();
                  final formattedDate = dateFormatter.format(sale.saleDate);

                  // Verifica se o nome do cliente OU a data formatada contêm o texto da pesquisa
                  return clientNameLower.contains(queryLower) || formattedDate.contains(queryLower);
                }).toList();

                if (filteredSales.isEmpty) {
                  return Center(child: Text('Nenhum resultado encontrado para "$_searchQuery"'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredSales.length, // Usa a lista filtrada
                  itemBuilder: (context, index) {
                    final sale = filteredSales[index]; // Usa a lista filtrada
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ExpansionTile(
                        title: Text(sale.clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar'))),
                                const PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined), title: Text('Ver PDF'))),
                                const PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.share_outlined), title: Text('Partilhar'))),
                                const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_forever_outlined, color: Colors.red), title: Text('Excluir', style: TextStyle(color: Colors.red)))),
                              ],
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