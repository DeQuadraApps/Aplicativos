// lib/pages/admin/salesperson_detail_page.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/models/goal.model.dart';
import 'package:quadra_vendas/models/sale.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/pages/admin/goals/goal-progress-card.dart';
import 'package:quadra_vendas/pages/admin/goals/set-goal.page.dart';
import 'package:quadra_vendas/pages/clients/add-edit-client.page.dart';
import 'package:quadra_vendas/pages/sales/edit-sale.page.dart';
import 'package:quadra_vendas/services/pdf-sale.service.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';
import 'package:share_plus/share_plus.dart';

class SalespersonDetailPage extends StatefulWidget {
  final UserModel salesperson;
  final String institutionId;

  const SalespersonDetailPage({
    super.key,
    required this.salesperson,
    required this.institutionId,
  });

  @override
  State<SalespersonDetailPage> createState() => _SalespersonDetailPageState();
}

class _SalespersonDetailPageState extends State<SalespersonDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _institutionName = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchInstitutionName();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchInstitutionName() async {
    final instDoc = await FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).get();
    if(mounted) {
      setState(() {
        _institutionName = instDoc.data()?['name'] ?? '';
      });
    }
  }

  // --- Funções de Gestão ---

  // +++ NOVA FUNÇÃO: Alternar Status de Entrega +++
  Future<void> _toggleDeliveryStatus(Sale sale) async {
    final currentStatus = sale.isDelivered;
    final newStatus = !currentStatus;

    try {
      await FirebaseFirestore.instance
          .collection('institutions').doc(widget.institutionId)
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

  void _deleteClient(String clientId) {
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
                    .collection('institutions').doc(widget.institutionId)
                    .collection('clients').doc(clientId)
                    .delete();
                if (mounted) {
                  Navigator.pop(context);
                  AppSnackBar.showSuccess(context, message: 'Cliente excluído com sucesso.');
                }
              } catch (e) {
                if (mounted) AppSnackBar.showError(context, message: 'Erro ao excluir cliente.');
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteSale(String saleId) {
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
                await FirebaseFirestore.instance
                    .collection('institutions').doc(widget.institutionId)
                    .collection('sales').doc(saleId)
                    .delete();
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

  Future<void> _showPdfPreview(Sale sale) async {
    final clientDoc = await FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).collection('clients').doc(sale.clientId).get();
    if (!clientDoc.exists && mounted) {
      AppSnackBar.showError(context, message: 'Cliente desta venda não encontrado.');
      return;
    }
    final client = Client.fromFirestore(clientDoc as DocumentSnapshot<Map<String, dynamic>>);
    // Recriando o objeto Sale completo com o client
    final fullSaleData = Sale(client: client, id: sale.id, clientName: sale.clientName, clientId: sale.clientId, items: sale.items, totalAmount: sale.totalAmount, withInvoice: sale.withInvoice, newClient: sale.newClient, observations: sale.observations, saleDate: sale.saleDate, userId: sale.userId, paymentMethod: sale.paymentMethod, isDelivered: sale.isDelivered);

    final pdfService = PdfSaleService(sale: fullSaleData, institutionName: _institutionName);
    final pdfBytes = await pdfService.generatePdf();
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }

  Future<void> _shareSale(Sale sale) async {
    AppSnackBar.showInfo(context, message: "A preparar documento...");
    final clientDoc = await FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).collection('clients').doc(sale.clientId).get();
    if (!clientDoc.exists && mounted) {
      AppSnackBar.showError(context, message: 'Cliente desta venda não encontrado.');
      return;
    }
    final client = Client.fromFirestore(clientDoc as DocumentSnapshot<Map<String, dynamic>>);
    try {
      final fullSaleData = Sale(client: client, id: sale.id, clientName: sale.clientName, clientId: sale.clientId, items: sale.items, totalAmount: sale.totalAmount, withInvoice: sale.withInvoice, newClient: sale.newClient, observations: sale.observations, saleDate: sale.saleDate, userId: sale.userId, paymentMethod: sale.paymentMethod, isDelivered: sale.isDelivered);

      final pdfService = PdfSaleService(sale: fullSaleData, institutionName: _institutionName);
      final pdfBytes = await pdfService.generatePdf();
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/venda_${sale.id}.pdf').create();
      await file.writeAsBytes(pdfBytes);
      final xfile = XFile(file.path);
      await Share.shareXFiles([xfile], text: 'Segue em anexo a ordem de venda para o cliente ${sale.clientName}.');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: 'Erro ao partilhar a venda: $e');
    }
  }

  Future<void> _deleteGoal(SalesGoal goal) async {
    if (goal.id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem a certeza que deseja excluir a meta de ${DateFormat('MMMM de yyyy', 'pt_BR').format(DateTime(goal.year, goal.month))}? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('institutions').doc(widget.institutionId)
            .collection('goals').doc(goal.id)
            .delete();

        if(mounted) AppSnackBar.showSuccess(context, message: 'Meta excluída com sucesso.');
      } catch (e) {
        if(mounted) AppSnackBar.showError(context, message: 'Erro ao excluir a meta.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.salesperson.fullName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Clientes'),
            Tab(icon: Icon(Icons.show_chart_outlined), text: 'Metas'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Vendas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClientsTab(),
          _buildGoalsTab(),
          _buildSalesTab(),
        ],
      ),
    );
  }

  /// --- Aba de Clientes ---
  Widget _buildClientsTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditClientPage(
                institutionId: widget.institutionId,
                salespersonId: widget.salesperson.id,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Novo Cliente para este Vendedor',
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('institutions').doc(widget.institutionId)
            .collection('clients')
            .where('salespersonId', isEqualTo: widget.salesperson.id)
            .orderBy('companyName')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Erro ao carregar clientes: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Este vendedor ainda não possui clientes.'));

          final clients = snapshot.data!.docs.map((doc) => Client.fromFirestore(doc)).toList();
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(client.companyName),
                  subtitle: Text('${client.city} - ${client.cnpj}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => AddEditClientPage(institutionId: widget.institutionId, client: client)));
                      } else if (value == 'delete') {
                        _deleteClient(client.id!);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Editar'))),
                      const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_forever), title: Text('Excluir'))),
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

  /// --- Aba de Metas ---
  Widget _buildGoalsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('institutions').doc(widget.institutionId)
          .collection('goals')
          .where('salespersonId', isEqualTo: widget.salesperson.id)
          .orderBy('year', descending: true).orderBy('month', descending: true)
          .snapshots(),
      builder: (context, goalSnapshot) {
        if (goalSnapshot.hasError) return Center(child: Text("Erro ao carregar metas: ${goalSnapshot.error}"));
        if (goalSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!goalSnapshot.hasData || goalSnapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Nenhuma meta definida para este vendedor.'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SetGoalPage(institutionId: widget.institutionId, salesperson: widget.salesperson))),
                  child: const Text('Definir Primeira Meta'),
                )
              ],
            ),
          );
        }
        final goals = goalSnapshot.data!.docs.map((doc) => SalesGoal.fromFirestore(doc)).toList();
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SetGoalPage(institutionId: widget.institutionId, salesperson: widget.salesperson))),
            child: const Icon(Icons.edit_calendar),
            tooltip: 'Definir ou Editar Meta',
          ),
          body: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: GoalProgressCard(key: ValueKey(goal.id), goal: goal, institutionId: widget.institutionId),
                  ),
                  Positioned(
                    top: 0,
                    right: 4,
                    child: IconButton(
                      icon: Icon(Icons.delete_forever, color: Colors.red.shade300),
                      tooltip: 'Excluir Meta',
                      onPressed: () => _deleteGoal(goal),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// --- Aba de Vendas (Atualizada) ---
  Widget _buildSalesTab() {
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('institutions').doc(widget.institutionId)
          .collection('sales')
          .where('userId', isEqualTo: widget.salesperson.id)
          .orderBy('saleDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Erro ao carregar vendas: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Nenhuma venda registrada por este vendedor.'));

        final sales = snapshot.data!.docs.map((doc) => Sale.fromFirestore(doc)).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: sales.length,
          itemBuilder: (context, index) {
            final sale = sales[index];
            final isDelivered = sale.isDelivered; // Propriedade nova

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              // Visual sutil se entregue
              shape: isDelivered
                  ? RoundedRectangleBorder(side: const BorderSide(color: Colors.green, width: 1.5), borderRadius: BorderRadius.circular(12))
                  : null,
              child: ExpansionTile(
                // Ícone na esquerda
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
                      itemBuilder: (context) => [
                        // +++ OPÇÃO DE ENTREGUE / PENDENTE +++
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
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: 'edit', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('Editar'))),
                        const PopupMenuItem(value: 'pdf', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.picture_as_pdf_outlined), title: Text('Ver PDF'))),
                        const PopupMenuItem(value: 'share', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.share_outlined), title: Text('Partilhar'))),
                        const PopupMenuItem(value: 'delete', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_forever_outlined, color: Colors.red), title: Text('Excluir', style: TextStyle(color: Colors.red)))),
                      ],
                    ),
                  ],
                ),
                children: [
                  const Divider(height: 1, thickness: 1),
                  for (final item in sale.items)
                    ListTile(
                      dense: true,
                      title: Text(item.product.name),
                      leading: Text('${item.quantity}x'),
                      trailing: Text(currencyFormatter.format(item.totalPrice)),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 4,
                      runSpacing: 0,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}