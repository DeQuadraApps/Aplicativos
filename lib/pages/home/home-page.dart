// lib/pages/home_page.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/models/goal.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/pages/admin/reports/report-options.page.dart';
import 'package:quadra_vendas/pages/admin/salespeople/salespeople-list.page.dart';
import 'package:quadra_vendas/pages/clients/clients-list.page.dart';
import 'package:quadra_vendas/pages/dashboard/dashboard.page.dart';
import 'package:quadra_vendas/pages/info/info.page.dart';
import 'package:quadra_vendas/pages/product/product-list.page.dart';
import 'package:quadra_vendas/pages/sales/direct-sale.page.dart';
import 'package:quadra_vendas/pages/sales/new-sale.page.dart';
import 'package:quadra_vendas/pages/sales/sales-list.page.dart';
import 'package:quadra_vendas/pages/settings/settings.page.dart';
import 'package:quadra_vendas/widgets/goal-progress-card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

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

  // Chaves para o tutorial
  final GlobalKey _keyMenu = GlobalKey();
  final GlobalKey _keyDashboard = GlobalKey();
  final GlobalKey _keyVendedoresMenu = GlobalKey();
  final GlobalKey _keyRelatorioMenu = GlobalKey();
  final GlobalKey _keyClientesMenu = GlobalKey();
  final GlobalKey _keyProdutosMenu = GlobalKey();
  final GlobalKey _keyVendasMenu = GlobalKey();
  final GlobalKey _keyRegistrarVendaMenu = GlobalKey();

  String? _institutionId;
  String _institutionName = 'Carregando...';
  String _expirationDateStr = '';
  String _userName = '';
  UserModel? _currentUserData;

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

  // Helper para buscar as chaves do tour que ficam DENTRO do menu
  List<GlobalKey> _getMenuTourKeys() {
    final bool isAdmin = _currentUserData?.role == 'admin';
    final keys = <GlobalKey>[];

    if (isAdmin) {
      keys.add(_keyVendedoresMenu);
      keys.add(_keyRelatorioMenu);
    }

    keys.addAll([
      _keyClientesMenu,
      _keyProdutosMenu,
      _keyVendasMenu,
      _keyRegistrarVendaMenu,
    ]);

    return keys;
  }

  // Inicia a segunda parte do tour (itens do menu) após um atraso
  void _startMenuTour() {
    // Abre o drawer e espera a animação terminar antes de iniciar o showcase
    _scaffoldKey.currentState?.openDrawer();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        ShowCaseWidget.of(context).startShowCase(_getMenuTourKeys());
      }
    });
  }

  // Inicia a primeira parte do tour
  void _startFullTour() {
    if (mounted) {
      ShowCaseWidget.of(context).startShowCase([_keyDashboard, _keyMenu]);
    }
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
        if (!_isOffline) {
          _metricsFuture = _fetchHomePageData();
        }
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
      if (wantTour == true) {
        _startFullTour();
      }
    }
  }

  Future<HomePageMetrics> _fetchHomePageData() async {
    if (currentUser == null) throw Exception("Utilizador não autenticado.");

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
    if (!userDoc.exists) throw Exception("Dados do utilizador não encontrados.");

    final localUserData = UserModel.fromFirestore(userDoc);
    final institutionId = localUserData.institutionId;

    final institutionDocFuture = FirebaseFirestore.instance.collection('institutions').doc(institutionId).get();

    final institutionRef = FirebaseFirestore.instance.collection('institutions').doc(institutionId);
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    Query salesQuery = institutionRef.collection('sales');
    if(localUserData.role != 'admin'){
      salesQuery = salesQuery.where('userId', isEqualTo: currentUser!.uid);
    }
    final salesSnapshotFuture = salesQuery.get();

    SalesGoal? monthlyGoal;
    if (localUserData.role != 'admin') {
      final goalQuery = await institutionRef.collection('goals')
          .where('salespersonId', isEqualTo: currentUser!.uid)
          .where('year', isEqualTo: now.year)
          .where('month', isEqualTo: now.month)
          .limit(1)
          .get();
      if(goalQuery.docs.isNotEmpty) {
        monthlyGoal = SalesGoal.fromFirestore(goalQuery.docs.first);
      }
    }

    int clientCount = 0;
    int productCount = 0;
    int myClientsCount = 0;
    if(localUserData.role == 'admin'){
      final results = await Future.wait([
        institutionRef.collection('clients').count().get(),
        institutionRef.collection('products').count().get(),
      ]);
      clientCount = (results[0]).count ?? 0;
      productCount = (results[1]).count ?? 0;
    } else {
      // LÓGICA PARA VENDEDOR: Busca a contagem de seus próprios clientes
      final myClientsSnapshot = await institutionRef
          .collection('clients')
          .where('salespersonId', isEqualTo: currentUser!.uid) // <-- AJUSTE AQUI SE O NOME DO CAMPO FOR OUTRO
          .count()
          .get();
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

    return HomePageMetrics(
      clientCount: clientCount,
      productCount: productCount,
      salesCount: salesCount,
      totalRevenue: totalRevenue,
      monthRevenue: monthRevenue,
      monthlyGoal: monthlyGoal,
      myClientsCount: myClientsCount,
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
          // CORREÇÃO: Usamos disposeOnTap e onTargetClick para controlar o fluxo
          disposeOnTap: true,
          onTargetClick: () => _startMenuTour(),
          child: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
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
                    GoalProgressCard(
                      goal: metrics.monthlyGoal!,
                      totalSold: metrics.monthRevenue,
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (!isAdmin)
                    _buildSalespersonDashboard(metrics),

                  if (isAdmin)
                    _buildAdminDashboard(metrics),
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

    // Usando LayoutBuilder para tornar o painel responsivo
    return LayoutBuilder(
      builder: (context, constraints) {
        // Define o número de colunas com base na largura da tela
        int crossAxisCount = 2; // Padrão para telas menores (celular)
        if (constraints.maxWidth >= 800) {
          crossAxisCount = 3; // 3 colunas para telas maiores (desktop)
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            DashboardCard(icon: Icons.attach_money, title: 'Minhas Vendas (Mês)', value: currencyFormatter.format(metrics.monthRevenue), color: Colors.green),
            DashboardCard(icon: Icons.receipt_long, title: 'Nº de Vendas', value: metrics.salesCount.toString(), color: Colors.teal),
            DashboardCard(
                icon: Icons.people,
                title: 'Meus Clientes',
                value: metrics.myClientsCount?.toString() ?? '0',
                color: Colors.orange
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
            DashboardCard(icon: Icons.attach_money, title: 'Vendas (Este Mês)', value: currencyFormatter.format(metrics.monthRevenue), color: Colors.green),
            DashboardCard(icon: Icons.receipt_long, title: 'Total de Vendas', value: currencyFormatter.format(metrics.totalRevenue), color: Colors.blue),
            DashboardCard(icon: Icons.people, title: 'Total de Clientes', value: metrics.clientCount.toString(), color: Colors.orange),
            DashboardCard(icon: Icons.inventory, title: 'Total de Produtos', value: metrics.productCount.toString(), color: Colors.purple),
            DashboardCard(icon: Icons.shopping_cart, title: 'Nº de Vendas', value: metrics.salesCount.toString(), color: Colors.teal),
          ],
        );
      },
    );
  }

  Widget _buildOfflineBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 64, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(height: 16),
            Text('Você está Offline', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('O painel de métricas está inacessível, mas pode continuar a registar clientes e vendas.', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBody(TextTheme textTheme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Bem-vindo à', style: textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_institutionName, style: textTheme.headlineMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Text("Comece por registar a sua primeira venda ou cliente!", textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context, TextTheme textTheme, ColorScheme colorScheme, bool isAdmin) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(_userName, style: textTheme.titleLarge?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(currentUser?.email ?? '', style: textTheme.bodyMedium?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          ListTile(leading: const Icon(Icons.home_outlined), title: const Text('Início'), onTap: () => Navigator.pop(context)),

          if (isAdmin)
            Showcase(
              key: _keyVendedoresMenu,
              description: 'Gerencie aqui a sua equipa de vendedores.',
              child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Vendedores'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SalespeopleListPage()));
                },
              ),
            ),

          if (isAdmin)
            Showcase(
              key: _keyRelatorioMenu,
              description: 'Emita relatórios detalhados de vendas, produtos e clientes.',
              child: ListTile(
                leading: const Icon(Icons.assessment_outlined),
                title: const Text('Emitir Relatório'),
                onTap: () {
                  Navigator.pop(context);
                  if (_institutionId != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ReportOptionsPage(institutionId: _institutionId!)));
                  }
                },
              ),
            ),

          Showcase(
            key: _keyClientesMenu,
            description: 'Aceda aqui à sua lista de clientes para adicionar, editar ou visualizar.',
            child: ListTile(leading: const Icon(Icons.people_alt_outlined), title: const Text('Clientes'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const ClientsListPage())); }),
          ),
          Showcase(
            key: _keyProdutosMenu,
            description: 'Aceda aqui à sua lista de produtos.',
            child: ListTile(leading: const Icon(Icons.inventory_2_outlined), title: const Text('Produtos'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsListPage())); }),
          ),
          Showcase(
            key: _keyVendasMenu,
            description: 'Visualize aqui o seu histórico de vendas realizadas.',
            child: ListTile(leading: const Icon(Icons.shopping_cart_outlined), title: const Text('Vendas'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesListPage())); }),
          ),
          Showcase(
            key: _keyRegistrarVendaMenu,
            description: 'Toque aqui para iniciar o registo de uma nova venda.',
            child: ListTile(leading: const Icon(Icons.point_of_sale_outlined), title: const Text('Registrar Venda'), onTap: _navigateToSalePage),
          ),
          const Divider(),
          ListTile(leading: const Icon(Icons.info_outline), title: const Text('Informações'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const InfoPage())); }),
          ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Configurações'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())); }),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Rever Tutorial'),
            onTap: () {
              Navigator.pop(context);
              _startFullTour();
            },
          ),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Sair'), onTap: () => FirebaseAuth.instance.signOut()),
        ],
      ),
    );
  }
}