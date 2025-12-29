// lib/pages/reports/commission_report.page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/enums/plan-type.dart';
import 'package:quadra_vendas/models/sale.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';

class CommissionReportPage extends StatefulWidget {
  const CommissionReportPage({super.key});

  @override
  State<CommissionReportPage> createState() => _CommissionReportPageState();
}

class _CommissionReportPageState extends State<CommissionReportPage> {
  bool _isLoading = true;
  String _institutionId = '';
  PlanType _activePlan = PlanType.start;
  // ✨ Nova variável para lembrar a taxa da empresa
  double _institutionDefaultRate = 5.0;

  DateTime _selectedDate = DateTime.now();
  UserModel? _currentUser;
  List<UserModel> _salespeople = [];
  UserModel? _selectedSalesperson;

  final TextEditingController _percentageController = TextEditingController();
  double _totalSales = 0.0;
  double _totalCommission = 0.0;
  List<Sale> _salesList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = UserModel.fromFirestore(userDoc);
      _institutionId = userData.institutionId!;
      _currentUser = userData;

      final instDoc = await FirebaseFirestore.instance.collection('institutions').doc(_institutionId).get();
      final instData = instDoc.data();

      final plan = (instData?['plan'] ?? 'start').toString().toLowerCase();

      // Carrega a taxa padrão da empresa
      final savedRate = (instData?['commissionRate'] ?? 5.0).toDouble();

      if (userData.role == 'admin') {
        final usersQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('institutionId', isEqualTo: _institutionId)
            .get();
        _salespeople = usersQuery.docs.map((d) => UserModel.fromFirestore(d)).toList();
      } else {
        _selectedSalesperson = userData;
      }

      if (mounted) {
        setState(() {
          _activePlan = PlanType.fromString(plan);
          _institutionDefaultRate = savedRate; // ✨ Guarda a taxa padrão

          // Se for Admin e estiver vendo "Todos", usa a taxa da empresa.
          // Se for Vendedor logado, tenta pegar a taxa dele, senão usa a da empresa.
          if (userData.role != 'admin' && userData.commissionRate != null) {
            _percentageController.text = userData.commissionRate.toString();
          } else {
            _percentageController.text = savedRate.toString();
          }

          _isLoading = false;
        });
      }

      if (_activePlan != PlanType.start) {
        _fetchSales();
      }

    } catch (e) {
      if(mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.showError(context, message: 'Erro ao carregar dados.');
      }
    }
  }

  Future<void> _saveCommissionRate() async {
    // ✨ Lógica de segurança: Se tiver um vendedor selecionado, não salva no padrão da empresa
    // O ideal seria ter uma função para salvar no perfil do vendedor, mas por enquanto vamos bloquear/alertar
    if (_selectedSalesperson != null) {
      AppSnackBar.showInfo(context, message: 'Para alterar a taxa deste vendedor permanentemente, edite o perfil dele em Usuários.');
      return;
    }

    final rate = double.tryParse(_percentageController.text.replaceAll(',', '.')) ?? 0.0;

    try {
      await FirebaseFirestore.instance
          .collection('institutions')
          .doc(_institutionId)
          .update({'commissionRate': rate});

      if(mounted) {
        setState(() {
          _institutionDefaultRate = rate; // Atualiza a variável local também
        });
        AppSnackBar.showSuccess(context, message: 'Taxa padrão da empresa atualizada!');
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if(mounted) AppSnackBar.showError(context, message: 'Erro ao salvar taxa.');
    }
  }

  Future<void> _fetchSales() async {
    final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final endOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);

    Query query = FirebaseFirestore.instance
        .collection('institutions').doc(_institutionId)
        .collection('sales')
        .where('saleDate', isGreaterThanOrEqualTo: startOfMonth)
        .where('saleDate', isLessThanOrEqualTo: endOfMonth);

    if (_selectedSalesperson != null) {
      query = query.where('userId', isEqualTo: _selectedSalesperson!.id);
    }

    try {
      final snapshot = await query.get();
      final sales = snapshot.docs.map((d) => Sale.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();

      double totalSold = 0;
      for (var sale in sales) {
        totalSold += sale.totalAmount;
      }

      setState(() {
        _salesList = sales;
        _totalSales = totalSold;
      });

      // Recalcula comissão com base no total atualizado e taxa atual
      _calculateCommission();

    } catch (e) {
      print(e);
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + offset, 1);
    });
    _fetchSales();
  }

  void _calculateCommission() {
    final percentage = double.tryParse(_percentageController.text.replaceAll(',', '.')) ?? 0;
    setState(() {
      _totalCommission = _totalSales * (percentage / 100);
    });
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
            const Text("O Relatório de Comissões é exclusivo dos planos Control e Elite.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
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

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final dateFormat = DateFormat('MMMM yyyy', 'pt_BR');

    final bool isAdmin = _currentUser?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comissões'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activePlan == PlanType.start
          ? _buildLockedScreen()
          : Column(
        children: [
          // 1. Barra de Filtros
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
                    Text(
                      dateFormat.format(_selectedDate).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
                  ],
                ),
                const SizedBox(height: 10),

                if (isAdmin)
                  DropdownButtonFormField<UserModel>(
                    value: _selectedSalesperson,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar Vendedor',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("Todos os Vendedores")),
                      ..._salespeople.map((u) => DropdownMenuItem(value: u, child: Text(u.fullName))),
                    ],
                    // ✨ LÓGICA DE TROCA DE VENDEDOR
                    onChanged: (val) {
                      setState(() {
                        _selectedSalesperson = val;

                        if (val != null) {
                          // Se selecionou um vendedor específico, tenta usar a taxa dele
                          // Se ele não tiver taxa definida (null), usa a padrão da empresa
                          final userRate = val.commissionRate ?? _institutionDefaultRate;
                          _percentageController.text = userRate.toString();
                        } else {
                          // Se selecionou "Todos", volta para a taxa padrão da empresa
                          _percentageController.text = _institutionDefaultRate.toString();
                        }
                      });

                      // Busca as vendas e recalcula
                      _fetchSales();
                    },
                  ),
              ],
            ),
          ),

          // 2. Cards de Resumo
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                    child: _buildSummaryCard(
                        context,
                        title: "Total Vendido",
                        value: currencyFormat.format(_totalSales),
                        color: Colors.blue.shade700
                    )
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: _buildSummaryCard(
                      context,
                      title: "Comissão",
                      value: currencyFormat.format(_totalCommission),
                      color: Colors.green.shade700,
                      isCommission: true,
                    )
                ),
              ],
            ),
          ),

          if (isAdmin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Text("Taxa de Comissão (%): "),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _percentageController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    onChanged: (_) => _calculateCommission(),
                  ),
                ),
                if (isAdmin)
                  IconButton(
                    icon: Icon(Icons.save, color: _selectedSalesperson == null ? Colors.blue : Colors.grey),
                    tooltip: _selectedSalesperson == null
                        ? "Salvar taxa padrão da empresa"
                        : "Edite o usuário para salvar a taxa individual",
                    onPressed: _selectedSalesperson == null ? _saveCommissionRate : null,
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.lock, size: 16, color: Colors.grey),
                  )
              ],
            ),
          ),
          const Divider(),

          // 4. Lista de Vendas
          Expanded(
            child: _salesList.isEmpty
                ? const Center(child: Text("Nenhuma venda neste período.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              itemCount: _salesList.length,
              itemBuilder: (context, index) {
                final sale = _salesList[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.receipt_long, color: Colors.grey),
                  title: Text(sale.clientName),
                  subtitle: Text("${DateFormat('dd/MM').format(sale.saleDate)} • ${sale.salespersonName ?? 'N/A'}"),
                  trailing: Text(
                    currencyFormat.format(sale.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, {required String title, required String value, required Color color, bool isCommission = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}