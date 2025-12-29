import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:quadra_vendas/enums/plan-type.dart';
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

  TabController? _tabController;
  Map<String, dynamic>? _institutionData;
  bool _isLoading = true;
  String _institutionName = '';
  PlanType _activePlan = PlanType.start;

  // Controle de Comissões
  DateTime _commissionDate = DateTime.now();
  late double _currentCommissionRate; // ✨ Variável local para a taxa

  @override
  void initState() {
    super.initState();
    // Inicializa a taxa com o valor que veio do modelo (ou 0 se nulo)
    _currentCommissionRate = widget.salesperson.commissionRate ?? 0.0;
    _fetchInstitutionData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchInstitutionData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).get();

      if (mounted) {
        setState(() {
          _institutionData = doc.data();
          _institutionName = _institutionData?['name'] ?? '';
          _isLoading = false;

          _activePlan = PlanType.fromString(_institutionData?['plan']);
          final tabCount = 4;

          _tabController = TabController(length: tabCount, vsync: this);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeCommissionMonth(int monthsToAdd) {
    setState(() {
      _commissionDate = DateTime(_commissionDate.year, _commissionDate.month + monthsToAdd, 1);
    });
  }

  Future<void> _editCommissionRate() async {
    final controller = TextEditingController(text: _currentCommissionRate.toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Definir Taxa de Comissão'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Informe a porcentagem que este vendedor ganha sobre as vendas.'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Porcentagem (%)',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final newValue = double.tryParse(controller.text.replaceAll(',', '.'));
              if (newValue != null) {
                try {
                  // --- CORREÇÃO: ACESSO DIRETO À COLEÇÃO RAIZ 'USERS' ---
                  await FirebaseFirestore.instance
                      .collection('users') // <--- Raiz
                      .doc(widget.salesperson.id)
                      .update({'commissionRate': newValue});

                  if (mounted) {
                    setState(() {
                      _currentCommissionRate = newValue;
                    });
                    Navigator.pop(context);
                    AppSnackBar.showSuccess(context, message: 'Taxa atualizada com sucesso!');
                  }
                } catch (e) {
                  if (mounted) AppSnackBar.showError(context, message: 'Erro ao salvar (Verifique permissões): $e');
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  // --- Funções de Gestão (Mantidas) ---
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
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Confirmar Exclusão'), content: const Text('Tem certeza que deseja excluir este cliente?'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), TextButton(onPressed: () async { try { await FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).collection('clients').doc(clientId).delete(); if (mounted) { Navigator.pop(context); AppSnackBar.showSuccess(context, message: 'Excluído.'); } } catch (e) { if (mounted) AppSnackBar.showError(context, message: 'Erro ao excluir.'); } }, child: const Text('Excluir', style: TextStyle(color: Colors.red))) ]));
  }

  void _deleteSale(String saleId) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Confirmar Exclusão'), content: const Text('Tem certeza que deseja excluir esta venda?'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), TextButton(onPressed: () async { try { await FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).collection('sales').doc(saleId).delete(); if (mounted) { Navigator.pop(context); AppSnackBar.showSuccess(context, message: 'Excluído.'); } } catch (e) { if (mounted) AppSnackBar.showError(context, message: 'Erro ao excluir.'); } }, child: const Text('Excluir', style: TextStyle(color: Colors.red))) ]));
  }

  Future<void> _showPdfPreview(Sale sale) async {
    // ... (Mantido igual) ...
    final clientDoc = await FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).collection('clients').doc(sale.clientId).get();
    if (!clientDoc.exists && mounted) return;
    final client = Client.fromFirestore(clientDoc as DocumentSnapshot<Map<String, dynamic>>);
    final fullSaleData = Sale(client: client, id: sale.id, clientName: sale.clientName, clientId: sale.clientId, items: sale.items, totalAmount: sale.totalAmount, withInvoice: sale.withInvoice, newClient: sale.newClient, observations: sale.observations, saleDate: sale.saleDate, userId: sale.userId, paymentMethod: sale.paymentMethod, isDelivered: sale.isDelivered);
    final pdfService = PdfSaleService(sale: fullSaleData, institutionName: _institutionName, activePlan: _activePlan);
    final pdfBytes = await pdfService.generatePdf();
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }

  Future<void> _shareSale(Sale sale) async {
    // ... (Mantido igual) ...
    final clientDoc = await FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).collection('clients').doc(sale.clientId).get();
    if (!clientDoc.exists && mounted) return;
    final client = Client.fromFirestore(clientDoc as DocumentSnapshot<Map<String, dynamic>>);
    final fullSaleData = Sale(client: client, id: sale.id, clientName: sale.clientName, clientId: sale.clientId, items: sale.items, totalAmount: sale.totalAmount, withInvoice: sale.withInvoice, newClient: sale.newClient, observations: sale.observations, saleDate: sale.saleDate, userId: sale.userId, paymentMethod: sale.paymentMethod, isDelivered: sale.isDelivered);
    final pdfService = PdfSaleService(sale: fullSaleData, institutionName: _institutionName, activePlan: _activePlan);
    final pdfBytes = await pdfService.generatePdf();
    final tempDir = await getTemporaryDirectory();
    final file = await File('${tempDir.path}/venda_${sale.id}.pdf').create();
    await file.writeAsBytes(pdfBytes);
    final xfile = XFile(file.path);
    await Share.shareXFiles([xfile], text: 'Segue em anexo a ordem de venda.');
  }

  Future<void> _deleteGoal(SalesGoal goal) async {
    // ... (Mantido igual) ...
    if (goal.id == null) return;
    final bool? confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Confirmar Exclusão'), content: const Text('Excluir meta?'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Excluir', style: TextStyle(color: Colors.red))) ]));
    if (confirmed == true) { await FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).collection('goals').doc(goal.id).delete(); }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.salesperson.fullName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final _activePlan = PlanType.fromString(_institutionData?['plan']);
    final isStartPlan = _activePlan == PlanType.start;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.salesperson.fullName),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabs: [
            const Tab(icon: Icon(Icons.people_alt_outlined), text: 'Clientes'),
            const Tab(icon: Icon(Icons.show_chart_outlined), text: 'Metas'),
            const Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Vendas'),
            const Tab(icon: Icon(Icons.monetization_on_outlined), text: 'Comissões'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClientsTab(),
          _buildGoalsTab(),
          _buildSalesTab(),
          if (!isStartPlan)
            _buildCommissionsTab()
          else
            _buildLockedScreen(),
        ],
      ),
    );
  }

  // --- Abas ---
  Widget _buildClientsTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddEditClientPage(institutionId: widget.institutionId, salespersonId: widget.salesperson.id))),
        child: const Icon(Icons.add), tooltip: 'Novo Cliente',
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).collection('clients').where('salespersonId', isEqualTo: widget.salesperson.id).orderBy('companyName').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Nenhum cliente.'));
          final clients = snapshot.data!.docs.map((doc) => Client.fromFirestore(doc)).toList();
          return ListView.builder(itemCount: clients.length, itemBuilder: (context, index) { final client = clients[index]; return Card(child: ListTile(title: Text(client.companyName), subtitle: Text(client.cnpj), trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteClient(client.id!)))); });
        },
      ),
    );
  }

  Widget _buildGoalsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).collection('goals').where('salespersonId', isEqualTo: widget.salesperson.id).orderBy('year', descending: true).orderBy('month', descending: true).snapshots(),
      builder: (context, goalSnapshot) {
        if (!goalSnapshot.hasData || goalSnapshot.data!.docs.isEmpty) return const Center(child: Text('Nenhuma meta.'));
        final goals = goalSnapshot.data!.docs.map((doc) => SalesGoal.fromFirestore(doc)).toList();
        return ListView.builder(itemCount: goals.length, itemBuilder: (context, index) => GoalProgressCard(goal: goals[index], institutionId: widget.institutionId));
      },
    );
  }

  Widget _buildSalesTab() {
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormatter = DateFormat('dd/MM/yyyy');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).collection('sales').where('userId', isEqualTo: widget.salesperson.id).orderBy('saleDate', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Nenhuma venda.'));
        final sales = snapshot.data!.docs.map((doc) => Sale.fromFirestore(doc)).toList();
        return ListView.builder(itemCount: sales.length, itemBuilder: (context, index) { final sale = sales[index]; return Card(child: ListTile(title: Text(sale.clientName), subtitle: Text(dateFormatter.format(sale.saleDate)), trailing: Text(currencyFormatter.format(sale.totalAmount)))); });
      },
    );
  }

  Widget _buildCommissionsTab() {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final startOfMonth = DateTime(_commissionDate.year, _commissionDate.month, 1);
    final endOfMonth = DateTime(_commissionDate.year, _commissionDate.month + 1, 0, 23, 59, 59);

    return Column(
      children: [
        // 1. SELETOR DE MÊS
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeCommissionMonth(-1)),
              Text(
                DateFormat('MMMM yyyy', 'pt_BR').format(_commissionDate).toUpperCase(),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeCommissionMonth(1)),
            ],
          ),
        ),
        const Divider(height: 1),

        // 2. CONTEÚDO
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('institutions').doc(widget.institutionId)
                .collection('sales')
                .where('userId', isEqualTo: widget.salesperson.id)
                .where('saleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
                .where('saleDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
                .orderBy('saleDate', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));

              final sales = snapshot.data?.docs.map((doc) => Sale.fromFirestore(doc)).toList() ?? [];

              final double totalSold = sales.fold(0.0, (sum, sale) => sum + sale.totalAmount);

              // ✨ USA A VARIÁVEL LOCAL (QUE PODE SER EDITADA)
              final double commissionValue = totalSold * (_currentCommissionRate / 100);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // CARD DE RESUMO
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text('COMISSÃO A PAGAR', style: theme.textTheme.labelSmall),
                          const SizedBox(height: 8),
                          Text(
                            currency.format(commissionValue),
                            style: theme.textTheme.headlineMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold
                            ),
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Vendido', style: theme.textTheme.bodySmall),
                                  Text(currency.format(totalSold), style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),

                              // ✨ BOTÃO PARA EDITAR TAXA
                              InkWell(
                                onTap: _editCommissionRate,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: colorScheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: colorScheme.primary.withOpacity(0.3))
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Taxa: ${_currentCommissionRate.toStringAsFixed(1)}%',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.edit, size: 14, color: colorScheme.onSurfaceVariant),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text("Detalhamento das Vendas", style: theme.textTheme.titleSmall),
                  ),
                  const SizedBox(height: 10),

                  if (sales.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: Text("Nenhuma venda neste mês.")),
                    )
                  else
                    ...sales.map((sale) {
                      final saleCommission = sale.totalAmount * (_currentCommissionRate / 100);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            child: Icon(Icons.monetization_on_outlined, color: colorScheme.primary, size: 20),
                          ),
                          title: Text(sale.clientName),
                          subtitle: Text(DateFormat('dd/MM/yyyy').format(sale.saleDate)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(currency.format(sale.totalAmount), style: theme.textTheme.bodySmall),
                              Text(
                                  '+ ${currency.format(saleCommission)}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList()
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLockedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
              child: Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            Text("Funcionalidade Premium", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text("O controle de Comissões está disponível apenas nos planos Performance e Elite.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => AppSnackBar.showInfo(context, message: "Entre em contato com o suporte."),
              child: const Text("Fazer Upgrade Agora"),
            )
          ],
        ),
      ),
    );
  }
}