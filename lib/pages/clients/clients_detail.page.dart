// lib/pages/clients/client_detail.page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/enums/plan-type.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/models/sale.model.dart';
import 'package:quadra_vendas/models/user.model.dart'; // Importe o UserModel
import 'package:quadra_vendas/pages/clients/add-edit-client.page.dart';
import 'package:quadra_vendas/pages/sales/direct-sale.page.dart';
import 'package:quadra_vendas/pages/sales/new-sale.page.dart'; // Importe a Nova Venda
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';

class ClientDetailPage extends StatefulWidget {
  final Client client;
  final String institutionId;

  const ClientDetailPage({super.key, required this.client, required this.institutionId});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ✨ Estados necessários
  PlanType _activePlan = PlanType.start;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData(); // Carrega Plano e Usuário
  }

  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Carrega Plano da Instituição
      final instDoc = await FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).get();

      // 2. Carrega Dados do Usuário (Para saber a Role)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (mounted) {
        setState(() {
          _activePlan = PlanType.fromString(instDoc.data()?['plan']);
          _currentUser = UserModel.fromFirestore(userDoc);
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar dados iniciais: $e");
    }
  }

  // ✨ DIALOG DE UPGRADE
  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Funcionalidade Premium"),
        content: const Text("A função de 'Repetir Pedido' (Recompra Rápida) é exclusiva dos planos Control e Elite.\n\nAgilize suas visitas com um Upgrade!"),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Entendi"))],
      ),
    );
  }

  // ✨ AÇÃO MÁGICA: ROTEAMENTO INTELIGENTE
  void _repeatOrder(Sale sale) {
    if (_currentUser == null) return;

    Widget targetPage;

    // Se for Admin -> Vai para Passo-a-passo (NewSalePage)
    // Se for Vendedor -> Vai para Venda Direta (DirectSalePage)
    if (_currentUser!.role == 'admin') {
      targetPage = NewSalePage(
        preSelectedClient: widget.client,
        preSelectedItems: sale.items,
      );
    } else {
      targetPage = DirectSalePage(
        preSelectedClient: widget.client,
        preSelectedItems: sale.items,
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => targetPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client.companyName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Dados"),
            Tab(text: "Histórico de Compras"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard("CNPJ", widget.client.cnpj),
        _infoCard("Cidade", widget.client.city),
        _infoCard("Endereço", widget.client.address),
        _infoCard("Responsável", widget.client.contactName),
        _infoCard("Telefone", widget.client.phone),
        _infoCard("Email", widget.client.email ?? ''),
        const SizedBox(height: 20),
        ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AddEditClientPage(
                          institutionId: widget.institutionId,
                          client: widget.client
                      )
                  )
              );
            },
            icon: const Icon(Icons.edit),
            label: const Text("Editar Dados")
        )
      ],
    );
  }

  Widget _infoCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    // Validação do Plano para UI
    final isStartPlan = _activePlan == PlanType.start;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('institutions').doc(widget.institutionId)
          .collection('sales')
          .where('clientId', isEqualTo: widget.client.id)
          .orderBy('saleDate', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Erro ao carregar histórico"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text("Nenhuma compra registrada."));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final sale = Sale.fromFirestore(docs[index] as DocumentSnapshot<Map<String, dynamic>>);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ExpansionTile(
                leading: const Icon(Icons.shopping_bag, color: Colors.blue),
                title: Text(dateFormat.format(sale.saleDate)),
                subtitle: Text(currencyFormat.format(sale.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                // ✨ BOTÃO REPETIR COM LÓGICA DE PLANO E ROTEAMENTO
                trailing: ElevatedButton.icon(
                  icon: Icon(isStartPlan ? Icons.lock : Icons.replay, size: 16),
                  label: const Text("Repetir"),
                  onPressed: () {
                    // 1. Valida Plano
                    if (isStartPlan) {
                      _showUpgradeDialog();
                    } else {
                      // 2. Chama a função que valida o Usuário
                      _repeatOrder(sale);
                    }
                  },
                ),
                children: [
                  const Divider(),
                  ...sale.items.map((item) => ListTile(
                    dense: true,
                    title: Text(item.product.name),
                    trailing: Text("${item.quantity}x"),
                  )),
                ],
              ),
            );
          },
        );
      },
    );
  }
}