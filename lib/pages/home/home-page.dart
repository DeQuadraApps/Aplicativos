// lib/pages/home_page.dart
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/models/goal.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/pages/admin/reports/report-options.page.dart';
import 'package:quadra_vendas/pages/admin/salespeople/salespeople-list.page.dart';
import 'package:quadra_vendas/pages/clients/clients-list.page.dart';
import 'package:quadra_vendas/pages/info/info.page.dart';
import 'package:quadra_vendas/pages/product/product-list.page.dart';
import 'package:quadra_vendas/pages/sales/direct-sale.page.dart';
import 'package:quadra_vendas/pages/sales/new-sale.page.dart';
import 'package:quadra_vendas/pages/sales/sales-list.page.dart';
import 'package:quadra_vendas/pages/settings/settings.page.dart';
import 'package:quadra_vendas/widgets/goal-progress-card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

// --- ESTRUTURAS DE DADOS ---
class HomePageMetrics {
  final int clientCount;
  final int productCount;
  final int salesCount;
  final double totalRevenue;
  final double monthRevenue;
  final SalesGoal? monthlyGoal;
  final int? myClientsCount;

  HomePageMetrics({
    required this.clientCount,
    required this.productCount,
    required this.salesCount,
    required this.totalRevenue,
    required this.monthRevenue,
    this.monthlyGoal,
    this.myClientsCount
  });

  bool get hasData => clientCount > 0 || productCount > 0 || salesCount > 0;
}

// --- WIDGET PRINCIPAL ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) => const _HomePageContent(),
    );
  }
}

class _HomePageContent extends StatefulWidget {
  const _HomePageContent();

  @override
  State<_HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<_HomePageContent> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ... Chaves do Showcase ...
  final GlobalKey _keyMenu = GlobalKey();
  final GlobalKey _keyDashboard = GlobalKey();
  final GlobalKey _keyVendedoresMenu = GlobalKey();
  final GlobalKey _keyRelatorioMenu = GlobalKey();
  final GlobalKey _keyClientesMenu = GlobalKey();
  final GlobalKey _keyProdutosMenu = GlobalKey();
  final GlobalKey _keyVendasMenu = GlobalKey();
  final GlobalKey _keyRegistrarVendaMenu = GlobalKey();

  // ... Estados da Página ...
  String? _institutionId;
  String _institutionName = 'Carregando...';
  String _expirationDateStr = '';
  String _userName = '';
  UserModel? _currentUserData;
  List<UserModel> _salespeople = []; // Armazena a lista de vendedores

  late Future<HomePageMetrics> _metricsFuture;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _metricsFuture = _fetchHomePageData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptTourIfNeeded());
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // ... Métodos do Showcase e Navegação (sem alterações) ...
  List<GlobalKey> _getMenuTourKeys() {
    final bool isAdmin = _currentUserData?.role == 'admin';
    final keys = <GlobalKey>[];
    if (isAdmin) {
      keys.add(_keyVendedoresMenu);
      keys.add(_keyRelatorioMenu);
    }
    keys.addAll([_keyClientesMenu, _keyProdutosMenu, _keyVendasMenu, _keyRegistrarVendaMenu]);
    return keys;
  }
  void _startMenuTour() {
    _scaffoldKey.currentState?.openDrawer();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) ShowCaseWidget.of(context).startShowCase(_getMenuTourKeys());
    });
  }
  void _startFullTour() {
    if (mounted) ShowCaseWidget.of(context).startShowCase([_keyDashboard, _keyMenu]);
  }
  Future<void> _initConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }
  void _updateConnectionStatus(List<ConnectivityResult> result) {
    if (!mounted) return;
    final isOffline = result.contains(ConnectivityResult.none);
    if (_isOffline != isOffline) {
      setState(() {
        _isOffline = isOffline;
        if (!_isOffline) _metricsFuture = _fetchHomePageData();
      });
    }
  }
  Future<void> _navigateToSalePage() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('saleMode') ?? 'cart';
    if(mounted) Navigator.pop(context);
    Widget pageToNavigate = (mode == 'direct') ? const DirectSalePage() : const NewSalePage();
    if(mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => pageToNavigate));
  }
  Future<void> _promptTourIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final bool tourCompleted = prefs.getBool('home_tour_completed') ?? false;
    if (!tourCompleted && mounted) {
      final bool? wantTour = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bem-vindo ao Quadra Vendas!'),
          content: const Text('Gostaria de fazer um tour rápido pelas principais funcionalidades?'),
          actions: [
            TextButton(child: const Text('Agora não'), onPressed: () => Navigator.of(context).pop(false)),
            ElevatedButton(child: const Text('Sim, por favor'), onPressed: () => Navigator.of(context).pop(true)),
          ],
        ),
      );
      await prefs.setBool('home_tour_completed', true);
      if (wantTour == true) _startFullTour();
    }
  }

  Future<HomePageMetrics> _fetchHomePageData() async {
    if (currentUser == null) throw Exception("Utilizador não autenticado.");

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
    if (!userDoc.exists) throw Exception("Dados do utilizador não encontrados.");

    final localUserData = UserModel.fromFirestore(userDoc);
    final institutionId = localUserData.institutionId;
    final institutionRef = FirebaseFirestore.instance.collection('institutions').doc(institutionId);

    if (localUserData.role == 'admin') {
      final salespeopleSnapshot = await FirebaseFirestore.instance.collection('users')
          .where('institutionId', isEqualTo: institutionId)
          .where('role', whereIn: ['employee', 'salesperson'])
          .get();
      _salespeople = salespeopleSnapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    }

    final institutionDocFuture = institutionRef.get();
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    Query salesQuery = institutionRef.collection('sales');
    if(localUserData.role != 'admin'){
      salesQuery = salesQuery.where('userId', isEqualTo: currentUser!.uid);
    }
    final salesSnapshotFuture = salesQuery.get();
    SalesGoal? monthlyGoal;
    if (localUserData.role != 'admin') {
      final goalQuery = await institutionRef.collection('goals').where('salespersonId', isEqualTo: currentUser!.uid).where('year', isEqualTo: now.year).where('month', isEqualTo: now.month).limit(1).get();
      if(goalQuery.docs.isNotEmpty) monthlyGoal = SalesGoal.fromFirestore(goalQuery.docs.first);
    }
    int clientCount = 0, productCount = 0, myClientsCount = 0;
    if(localUserData.role == 'admin'){
      final results = await Future.wait([institutionRef.collection('clients').count().get(), institutionRef.collection('products').count().get()]);
      clientCount = (results[0]).count ?? 0;
      productCount = (results[1]).count ?? 0;
    } else {
      final myClientsSnapshot = await institutionRef.collection('clients').where('salespersonId', isEqualTo: currentUser!.uid).count().get();
      myClientsCount = myClientsSnapshot.count ?? 0;
    }
    final institutionDoc = await institutionDocFuture;
    final salesSnapshot = await salesSnapshotFuture;
    if (mounted) {
      setState(() {
        _institutionId = institutionId;
        _currentUserData = localUserData;
        _userName = localUserData.fullName;
        _institutionName = institutionDoc.data()?['name'] ?? 'Instituição sem nome';
        final timestamp = institutionDoc.data()?['licenseExpiresAt'] as Timestamp?;
        if (timestamp != null) _expirationDateStr = DateFormat('dd/MM/yyyy').format(timestamp.toDate());
      });
    }
    int salesCount = salesSnapshot.size;
    double totalRevenue = 0, monthRevenue = 0;
    for (var doc in salesSnapshot.docs) {
      final saleData = doc.data() as Map<String, dynamic>;
      final amount = (saleData['totalAmount'] as num? ?? 0).toDouble();
      totalRevenue += amount;
      if ((saleData['saleDate'] as Timestamp).toDate().isAfter(startOfMonth)) {
        monthRevenue += amount;
      }
    }
    return HomePageMetrics(clientCount: clientCount, productCount: productCount, salesCount: salesCount, totalRevenue: totalRevenue, monthRevenue: monthRevenue, monthlyGoal: monthlyGoal, myClientsCount: myClientsCount);
  }

  // ✨ CORREÇÃO: Função para abrir uma página de tela cheia para o gráfico
  void _showChartPage(String title, Widget content) {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: content,
        ),
      );
    }));
  }

  // Função para modais de lista (não-gráficos)
  void _showDetailsModal(String title, Widget content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(width: double.maxFinite, child: content),
          actions: <Widget>[
            TextButton(child: const Text('Fechar'), onPressed: () => Navigator.of(context).pop()),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bool isAdmin = _currentUserData?.role == 'admin';

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context, textTheme, colorScheme, isAdmin),
      appBar: AppBar(
        leading: Showcase(
          key: _keyMenu,
          description: 'Toque aqui para aceder a todos os menus da aplicação.',
          disposeOnTap: true,
          onTargetClick: () => _startMenuTour(),
          child: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        ),
        title: Column(
          children: [
            Text(_institutionName, style: textTheme.titleLarge),
            if (_expirationDateStr.isNotEmpty && isAdmin)
              Text('Licença expira em: $_expirationDateStr', style: textTheme.bodySmall?.copyWith(color: colorScheme.error, fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(tooltip: "Atualizar Dados", icon: const Icon(Icons.refresh), onPressed: () => setState(() { _metricsFuture = _fetchHomePageData(); })),
        ],
      ),
      body: _isOffline
          ? _buildOfflineBody()
          : FutureBuilder<HomePageMetrics>(
        future: _metricsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Erro ao carregar o painel: ${snapshot.error}"));
          if (!snapshot.hasData || _currentUserData == null) return _buildWelcomeBody(textTheme, colorScheme);
          final metrics = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Showcase(
              key: _keyDashboard,
              description: 'Este é o seu painel principal, com as métricas mais importantes do seu negócio.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isAdmin && metrics.monthlyGoal != null) ...[
                    GoalProgressCard(goal: metrics.monthlyGoal!, totalSold: metrics.monthRevenue),
                    const SizedBox(height: 16),
                  ],
                  if (!isAdmin) _buildSalespersonDashboard(metrics),
                  if (isAdmin) _buildAdminDashboard(metrics),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSalespersonDashboard(HomePageMetrics metrics) {
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.maxWidth >= 800) crossAxisCount = 3;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            DashboardCard(
              icon: Icons.attach_money,
              title: 'Minhas Vendas (Mês)',
              value: currencyFormatter.format(metrics.monthRevenue),
              color: Colors.green,
              onTap: () => _showDetailsModal(
                'Minhas Vendas Recentes',
                _RecentItemsList(
                  institutionId: _institutionId!,
                  collectionName: 'sales',
                  titleField: 'clientName',
                  subtitleField: 'totalAmount',
                  icon: Icons.receipt_long,
                  dateField: 'saleDate',
                  formatAsCurrency: true,
                  filterByCurrentUser: true,
                  userId: currentUser!.uid,
                ),
              ),
            ),
            DashboardCard(
              icon: Icons.receipt_long,
              title: 'Nº de Vendas',
              value: metrics.salesCount.toString(),
              color: Colors.teal,
            ),
            DashboardCard(
              icon: Icons.people,
              title: 'Meus Clientes',
              value: metrics.myClientsCount?.toString() ?? '0',
              color: Colors.orange,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdminDashboard(HomePageMetrics metrics) {
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.maxWidth > 1200) crossAxisCount = 5;
        else if (constraints.maxWidth > 800) crossAxisCount = 4;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            DashboardCard(
              icon: Icons.attach_money,
              title: 'Vendas (Mês)',
              value: currencyFormatter.format(metrics.monthRevenue),
              color: Colors.green,
              onTap: () => _showDetailsModal(
                'Vendas por Vendedor',
                _SalesValueBySalespersonModal(institutionId: _institutionId!, salespeople: _salespeople),
              ),
            ),
            DashboardCard(
              icon: Icons.people,
              title: 'Total de Clientes',
              value: metrics.clientCount.toString(),
              color: Colors.orange,
              onTap: () => _showDetailsModal(
                'Clientes por Vendedor',
                _ClientsBySalespersonModal(institutionId: _institutionId!, salespeople: _salespeople),
              ),
            ),
            DashboardCard(
              icon: Icons.inventory,
              title: 'Total de Produtos',
              value: metrics.productCount.toString(),
              color: Colors.purple,
            ),
            DashboardCard(
              icon: Icons.shopping_cart,
              title: 'Nº de Vendas',
              value: metrics.salesCount.toString(),
              color: Colors.teal,
              onTap: () => _showDetailsModal(
                'Nº de Vendas por Vendedor',
                _SalesCountBySalespersonModal(institutionId: _institutionId!, salespeople: _salespeople),
              ),
            ),
            DashboardCard(
              icon: Icons.bar_chart,
              title: 'Relação de Vendas',
              value: 'Gráfico',
              color: Colors.redAccent,
              onTap: () => _showChartPage(
                'Evolução de Vendas Mensal',
                _SalesComparisonChartModal(institutionId: _institutionId!, salespeople: _salespeople),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOfflineBody() => const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.wifi_off, size: 64), SizedBox(height: 16), Text('Você está Offline', textAlign: TextAlign.center), SizedBox(height: 8), Text('O painel de métricas está inacessível, mas pode continuar a registar clientes e vendas.', textAlign: TextAlign.center)])));
  Widget _buildWelcomeBody(TextTheme textTheme, ColorScheme colorScheme) => Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Bem-vindo à', style: textTheme.headlineSmall), const SizedBox(height: 8), Text(_institutionName, style: textTheme.headlineMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold), textAlign: TextAlign.center), const SizedBox(height: 16), const Text("Comece por registar a sua primeira venda ou cliente!", textAlign: TextAlign.center)])));
  Drawer _buildDrawer(BuildContext context, TextTheme textTheme, ColorScheme colorScheme, bool isAdmin) => Drawer(child: ListView(padding: EdgeInsets.zero, children: [DrawerHeader(decoration: BoxDecoration(color: colorScheme.primary), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [Text(_userName, style: textTheme.titleLarge?.copyWith(color: Colors.white)), const SizedBox(height: 4), Text(currentUser?.email ?? '', style: textTheme.bodyMedium?.copyWith(color: Colors.white70))])), ListTile(leading: const Icon(Icons.home_outlined), title: const Text('Início'), onTap: () => Navigator.pop(context)), if (isAdmin) Showcase(key: _keyVendedoresMenu, description: 'Gerencie aqui a sua equipa de vendedores.', child: ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('Vendedores'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const SalespeopleListPage())); })), if (isAdmin) Showcase(key: _keyRelatorioMenu, description: 'Emita relatórios detalhados de vendas, produtos e clientes.', child: ListTile(leading: const Icon(Icons.assessment_outlined), title: const Text('Emitir Relatório'), onTap: () { Navigator.pop(context); if (_institutionId != null) { Navigator.push(context, MaterialPageRoute(builder: (context) => ReportOptionsPage(institutionId: _institutionId!))); } })), Showcase(key: _keyClientesMenu, description: 'Aceda aqui à sua lista de clientes para adicionar, editar ou visualizar.', child: ListTile(leading: const Icon(Icons.people_alt_outlined), title: const Text('Clientes'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const ClientsListPage())); })), Showcase(key: _keyProdutosMenu, description: 'Aceda aqui à sua lista de produtos.', child: ListTile(leading: const Icon(Icons.inventory_2_outlined), title: const Text('Produtos'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsListPage())); })), Showcase(key: _keyVendasMenu, description: 'Visualize aqui o seu histórico de vendas realizadas.', child: ListTile(leading: const Icon(Icons.shopping_cart_outlined), title: const Text('Vendas'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesListPage())); })), Showcase(key: _keyRegistrarVendaMenu, description: 'Toque aqui para iniciar o registo de uma nova venda.', child: ListTile(leading: const Icon(Icons.point_of_sale_outlined), title: const Text('Registrar Venda'), onTap: _navigateToSalePage)), const Divider(), ListTile(leading: const Icon(Icons.info_outline), title: const Text('Informações'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const InfoPage())); }), ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Configurações'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())); }), ListTile(leading: const Icon(Icons.school_outlined), title: const Text('Rever Tutorial'), onTap: () { Navigator.pop(context); _startFullTour(); }), const Divider(), ListTile(leading: const Icon(Icons.logout), title: const Text('Sair'), onTap: () => FirebaseAuth.instance.signOut())]));
}

// --- WIDGETS DOS CARDS E MODAIS ---

class DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const DashboardCard({super.key, required this.icon, required this.title, required this.value, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: color),
              const Spacer(),
              Text(title, style: Theme.of(context).textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentItemsList extends StatelessWidget {
  final String institutionId;
  final String collectionName;
  final String titleField;
  final String subtitleField;
  final IconData icon;
  final String? dateField;
  final bool formatAsCurrency;
  final bool filterByCurrentUser;
  final String userId;

  const _RecentItemsList({
    required this.institutionId,
    required this.collectionName,
    required this.titleField,
    required this.subtitleField,
    required this.icon,
    this.dateField,
    this.formatAsCurrency = false,
    this.filterByCurrentUser = false,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('institutions').doc(institutionId).collection(collectionName);
    if (filterByCurrentUser) {
      final fieldToFilter = collectionName == 'clients' ? 'salespersonId' : 'userId';
      query = query.where(fieldToFilter, isEqualTo: userId);
    }
    if (dateField != null) {
      query = query.orderBy(dateField!, descending: true);
    }
    query = query.limit(10);

    return FutureBuilder<QuerySnapshot>(
      future: query.get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Text("Erro ao carregar dados."));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhum item recente encontrado."));

        final docs = snapshot.data!.docs;
        final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

        return ListView.builder(
          shrinkWrap: true,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final title = data[titleField]?.toString() ?? 'N/A';
            String subtitle;
            if (formatAsCurrency) {
              final amount = (data[subtitleField] as num? ?? 0).toDouble();
              subtitle = currencyFormatter.format(amount);
            } else {
              subtitle = data[subtitleField]?.toString() ?? '';
            }
            return ListTile(
              leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
              title: Text(title),
              subtitle: Text(subtitle),
            );
          },
        );
      },
    );
  }
}

class _SalesValueBySalespersonModal extends StatefulWidget {
  final String institutionId;
  final List<UserModel> salespeople;
  const _SalesValueBySalespersonModal({required this.institutionId, required this.salespeople});

  @override
  State<_SalesValueBySalespersonModal> createState() => _SalesValueBySalespersonModalState();
}

class _SalesValueBySalespersonModalState extends State<_SalesValueBySalespersonModal> {
  late int _selectedMonth;
  late int _selectedYear;
  late Future<Map<String, double>> _dataFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _dataFuture = _fetchData();
  }

  Future<Map<String, double>> _fetchData() async {
    final startDate = DateTime(_selectedYear, _selectedMonth, 1);
    final endDate = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);

    final salesSnapshot = await FirebaseFirestore.instance
        .collection('institutions').doc(widget.institutionId).collection('sales')
        .where('saleDate', isGreaterThanOrEqualTo: startDate)
        .where('saleDate', isLessThanOrEqualTo: endDate)
        .get();

    final salesBySalesperson = <String, double>{};
    for (var doc in salesSnapshot.docs) {
      final data = doc.data();
      final userId = data['userId'] as String;
      final amount = (data['totalAmount'] as num).toDouble();
      final salespersonName = widget.salespeople.firstWhere((s) => s.id == userId, orElse: () => UserModel(id: '', fullName: 'Desconhecido', email: '', institutionId: '', role: '')).fullName;
      salesBySalesperson[salespersonName] = (salesBySalesperson[salespersonName] ?? 0) + amount;
    }
    return salesBySalesperson;
  }

  void _onDateChanged() {
    setState(() {
      _dataFuture = _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final months = List.generate(12, (i) => DateFormat.MMMM('pt_BR').format(DateTime(0, i + 1)));
    final years = List.generate(5, (i) => DateTime.now().year - i);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButton<int>(
                value: _selectedMonth,
                isExpanded: true,
                items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i]))),
                onChanged: (value) {
                  if (value != null) {
                    _selectedMonth = value;
                    _onDateChanged();
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButton<int>(
                value: _selectedYear,
                isExpanded: true,
                items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _selectedYear = value;
                    _onDateChanged();
                  }
                },
              ),
            ),
          ],
        ),
        const Divider(height: 24),
        FutureBuilder<Map<String, double>>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text('Nenhuma venda encontrada para este período.');

            final data = snapshot.data!;
            final total = data.values.fold(0.0, (sum, item) => sum + item);
            final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

            final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

            return ListView(
              shrinkWrap: true,
              children: [
                ...entries.map((entry) => ListTile(
                  title: Text(entry.key),
                  trailing: Text(currencyFormatter.format(entry.value)),
                )),
                const Divider(),
                ListTile(
                  title: const Text('Total do Período', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(currencyFormatter.format(total), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ClientsBySalespersonModal extends StatelessWidget {
  final String institutionId;
  final List<UserModel> salespeople;
  const _ClientsBySalespersonModal({required this.institutionId, required this.salespeople});

  Future<Map<String, int>> _fetchData() async {
    final clientsSnapshot = await FirebaseFirestore.instance
        .collection('institutions').doc(institutionId).collection('clients').get();

    final clientsBySalesperson = <String, int>{};
    for (var doc in clientsSnapshot.docs) {
      final data = doc.data();
      final salespersonId = data['salespersonId'] as String;
      final salespersonName = salespeople.firstWhere((s) => s.id == salespersonId, orElse: () => UserModel(id: '', fullName: 'Sem Vendedor', email: '', institutionId: '', role: '')).fullName;
      clientsBySalesperson[salespersonName] = (clientsBySalesperson[salespersonName] ?? 0) + 1;
    }
    return clientsBySalesperson;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _fetchData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text('Nenhum cliente encontrado.');

        final data = snapshot.data!;
        final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        return ListView(
          shrinkWrap: true,
          children: entries.map((entry) => ListTile(
            title: Text(entry.key),
            trailing: Text(entry.value.toString()),
          )).toList(),
        );
      },
    );
  }
}

class _SalesCountBySalespersonModal extends StatefulWidget {
  final String institutionId;
  final List<UserModel> salespeople;
  const _SalesCountBySalespersonModal({required this.institutionId, required this.salespeople});

  @override
  State<_SalesCountBySalespersonModal> createState() => _SalesCountBySalespersonModalState();
}

class _SalesCountBySalespersonModalState extends State<_SalesCountBySalespersonModal> {
  late int _selectedMonth;
  late int _selectedYear;
  late Future<Map<String, int>> _dataFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _dataFuture = _fetchData();
  }

  Future<Map<String, int>> _fetchData() async {
    final startDate = DateTime(_selectedYear, _selectedMonth, 1);
    final endDate = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);

    final salesSnapshot = await FirebaseFirestore.instance
        .collection('institutions').doc(widget.institutionId).collection('sales')
        .where('saleDate', isGreaterThanOrEqualTo: startDate)
        .where('saleDate', isLessThanOrEqualTo: endDate)
        .get();

    final salesCount = <String, int>{};
    for (var doc in salesSnapshot.docs) {
      final data = doc.data();
      final userId = data['userId'] as String;
      final salespersonName = widget.salespeople.firstWhere((s) => s.id == userId, orElse: () => UserModel(id: '', fullName: 'Desconhecido', email: '', institutionId: '', role: '')).fullName;
      salesCount[salespersonName] = (salesCount[salespersonName] ?? 0) + 1;
    }
    return salesCount;
  }

  void _onDateChanged() {
    setState(() {
      _dataFuture = _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final months = List.generate(12, (i) => DateFormat.MMMM('pt_BR').format(DateTime(0, i + 1)));
    final years = List.generate(5, (i) => DateTime.now().year - i);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButton<int>(
                value: _selectedMonth,
                isExpanded: true,
                items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i]))),
                onChanged: (value) {
                  if (value != null) {
                    _selectedMonth = value;
                    _onDateChanged();
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButton<int>(
                value: _selectedYear,
                isExpanded: true,
                items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _selectedYear = value;
                    _onDateChanged();
                  }
                },
              ),
            ),
          ],
        ),
        const Divider(height: 24),
        FutureBuilder<Map<String, int>>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text('Nenhuma venda encontrada para este período.');

            final data = snapshot.data!;
            final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

            return ListView(
              shrinkWrap: true,
              children: entries.map((entry) => ListTile(
                title: Text(entry.key),
                trailing: Text(entry.value.toString()),
              )).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _SalesComparisonChartModal extends StatefulWidget {
  final String institutionId;
  final List<UserModel> salespeople;
  const _SalesComparisonChartModal({required this.institutionId, required this.salespeople});

  @override
  State<_SalesComparisonChartModal> createState() => _SalesComparisonChartModalState();
}

class _SalesComparisonChartModalState extends State<_SalesComparisonChartModal> {
  late Future<Map<String, Map<String, double>>> _dataFuture;
  PageController? _pageController;
  int _currentPage = 0;
  int _monthsPerPage = 4;
  List<String> _monthKeys = [];
  bool _initialPageIsSet = false;

  final List<Color> _barColors = [
    Colors.blue, Colors.orange, Colors.green, Colors.red, Colors.purple, Colors.teal, Colors.pink
  ];

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchChartDataForLastMonths(12);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<Map<String, Map<String, double>>> _fetchChartDataForLastMonths(int numberOfMonths) async {
    final now = DateTime.now();
    final allMonthsData = <String, Map<String, double>>{};

    for (int i = 0; i < numberOfMonths; i++) {
      final targetMonth = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('MMM/yy', 'pt_BR').format(targetMonth);

      final startDate = DateTime(targetMonth.year, targetMonth.month, 1);
      final endDate = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);

      final salesSnapshot = await FirebaseFirestore.instance
          .collection('institutions').doc(widget.institutionId).collection('sales')
          .where('saleDate', isGreaterThanOrEqualTo: startDate)
          .where('saleDate', isLessThanOrEqualTo: endDate)
          .get();

      final salesDataForMonth = <String, double>{};
      for (var sp in widget.salespeople) {
        salesDataForMonth[sp.fullName] = 0.0;
      }

      for (var doc in salesSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String;
        final amount = (data['totalAmount'] as num).toDouble();
        final salespersonName = widget.salespeople.firstWhere((s) => s.id == userId, orElse: () => UserModel(id: '', fullName: 'Desconhecido', email: '', institutionId: '', role: '')).fullName;

        salesDataForMonth[salespersonName] = (salesDataForMonth[salespersonName] ?? 0) + amount;
      }
      allMonthsData[monthKey] = salesDataForMonth;
    }
    return allMonthsData;
  }

  double _calculateInterval(double maxValue) {
    if (maxValue <= 0) return 1;
    final roughInterval = maxValue / 5;
    final magnitude = pow(10, (log(roughInterval) / ln10).floor());
    final residual = roughInterval / magnitude;

    double niceMultiplier;
    if (residual > 5) niceMultiplier = 10;
    else if (residual > 2) niceMultiplier = 5;
    else if (residual > 1) niceMultiplier = 2;
    else niceMultiplier = 1;

    final interval = niceMultiplier * magnitude;
    return interval > 0 ? interval : 1;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Map<String, double>>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48.0),
            child: Text('Nenhum dado de venda encontrado.'),
          );
        }

        final allMonthsData = snapshot.data!;
        _monthKeys = allMonthsData.keys.toList().reversed.toList();

        if (!_initialPageIsSet) {
          int firstMonthWithSalesIndex = _monthKeys.indexWhere((key) {
            final monthData = allMonthsData[key]!;
            return monthData.values.any((sales) => sales > 0);
          });

          if (firstMonthWithSalesIndex == -1) {
            firstMonthWithSalesIndex = _monthKeys.length -1;
          }

          int initialPageIndex = (firstMonthWithSalesIndex / _monthsPerPage).floor();
          _pageController = PageController(initialPage: initialPageIndex);
          _currentPage = initialPageIndex;
          _initialPageIsSet = true;
        }

        final totalPages = (_monthKeys.length / _monthsPerPage).ceil();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: totalPages,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, pageIndex) {
                  final startIndex = pageIndex * _monthsPerPage;
                  final endIndex = min(startIndex + _monthsPerPage, _monthKeys.length);
                  final pageMonthKeys = _monthKeys.sublist(startIndex, endIndex);

                  final barGroups = <BarChartGroupData>[];
                  double pageMaxY = 0;

                  for (int i = 0; i < pageMonthKeys.length; i++) {
                    final monthKey = pageMonthKeys[i];
                    final monthData = allMonthsData[monthKey]!;

                    final barRods = <BarChartRodData>[];
                    for (int j = 0; j < widget.salespeople.length; j++) {
                      final salesperson = widget.salespeople[j];
                      final salesValue = monthData[salesperson.fullName] ?? 0.0;
                      if (salesValue > pageMaxY) pageMaxY = salesValue;
                      barRods.add(
                          BarChartRodData(
                            toY: salesValue,
                            color: _barColors[j % _barColors.length],
                            width: 12,
                            borderRadius: BorderRadius.circular(4),
                          )
                      );
                    }
                    barGroups.add(BarChartGroupData(x: i, barRods: barRods));
                  }

                  final interval = _calculateInterval(pageMaxY);

                  return BarChart(
                    BarChartData(
                      maxY: pageMaxY > 0 ? pageMaxY * 1.2 : 1,
                      barGroups: barGroups,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final salespersonName = widget.salespeople[rodIndex].fullName.split(' ').first;
                            final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
                            return BarTooltipItem(
                              '$salespersonName\n',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              children: <TextSpan>[
                                TextSpan(
                                  text: currencyFormatter.format(rod.toY),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, reservedSize: 45, interval: interval,
                            getTitlesWidget: (value, meta) {
                              if (value == 0 && pageMaxY > 0) return const Text('0');
                              if (value > meta.max) return const Text('');
                              if (value >= 1000) return Text('R\$${(value/1000).toStringAsFixed(0)}k');
                              return Text('R\$${value.toStringAsFixed(0)}');
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= pageMonthKeys.length) return const Text('');
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(pageMonthKeys[index].split('/').first),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: interval),
                      borderData: FlBorderData(show: false),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(widget.salespeople.length, (index) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 12, height: 12, color: _barColors[index % _barColors.length]),
                    const SizedBox(width: 4),
                    Text(widget.salespeople[index].fullName.split(' ').first),
                  ],
                );
              }),
            ),
            if (totalPages > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 0 ? () {
                      _pageController?.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
                    } : null,
                  ),
                  Text('${_currentPage + 1} / $totalPages'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < totalPages - 1 ? () {
                      _pageController?.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
                    } : null,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
