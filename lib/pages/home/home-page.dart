// lib/pages/home_page.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/pages/clients/clients-list.page.dart';
import 'package:quadra_vendas/pages/dashboard/dashboard.page.dart';
import 'package:quadra_vendas/pages/info/info.page.dart';
import 'package:quadra_vendas/pages/product/product-list.page.dart';
import 'package:quadra_vendas/pages/sales/new-sale.page.dart';
import 'package:quadra_vendas/pages/sales/sales-list.page.dart';
import 'package:quadra_vendas/pages/settings/settings.page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

class DashboardMetrics {
  final int clientCount; final int productCount; final int salesCount;
  final double totalRevenue; final double monthRevenue;
  DashboardMetrics({required this.clientCount, required this.productCount, required this.salesCount, required this.totalRevenue, required this.monthRevenue});
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

  String _institutionName = 'Carregando...';
  String _expirationDateStr = '';
  String _userName = '';

  late Future<DashboardMetrics> _metricsFuture;

  // =======================================================
  // A SOLUÇÃO DEFINITIVA: UMA CHAVE GLOBAL PARA O SCAFFOLD
  // =======================================================
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final GlobalKey _keyMenu = GlobalKey();
  final GlobalKey _keyDashboard = GlobalKey();
  final GlobalKey _keyNewSale = GlobalKey();
  final GlobalKey _keyClients = GlobalKey();
  final GlobalKey _keyProducts = GlobalKey();
  final GlobalKey _keySales = GlobalKey();
  final GlobalKey _keySettings = GlobalKey();
  final GlobalKey _keyReplayTour = GlobalKey();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _metricsFuture = _fetchDashboardData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptTourIfNeeded());
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult);

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final isOffline = result.contains(ConnectivityResult.none);
    if (_isOffline != isOffline) {
      setState(() {
        _isOffline = isOffline;
        // Se a ligação voltar, atualiza os dados do dashboard
        if (!_isOffline) {
          _metricsFuture = _fetchDashboardData();
        }
      });
    }
  }

  Future<void> _promptTourIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final bool tourCompleted = prefs.getBool('home_tour_completed') ?? false;

    if (!tourCompleted) {
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
        _startMainTour();
      }
    }
  }

  void _startMainTour() {
    ShowCaseWidget.of(context).startShowCase([_keyMenu, _keyDashboard]);
  }

  void _startDrawerTour() {
    ShowCaseWidget.of(context).startShowCase([_keyClients, _keyProducts, _keySales, _keyNewSale, _keySettings, _keyReplayTour]);
  }

  Future<DashboardMetrics> _fetchDashboardData() async {
    // ... esta função permanece a mesma ...
    if (currentUser == null) throw Exception("Utilizador não autenticado.");
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
    if (!userDoc.exists) throw Exception("Dados do utilizador não encontrados.");
    final userData = userDoc.data()!;
    final institutionId = userData['institutionId'] as String?;
    if (institutionId == null) throw Exception("Utilizador não vinculado a uma instituição.");
    if(mounted) {
      final institutionDoc = await FirebaseFirestore.instance.collection('institutions').doc(institutionId).get();
      setState(() {
        _userName = userData['fullName'] ?? currentUser!.email!;
        _institutionName = institutionDoc.data()?['name'] ?? 'Instituição sem nome';
        final timestamp = institutionDoc.data()?['licenseExpiresAt'] as Timestamp?;
        if (timestamp != null) _expirationDateStr = DateFormat('dd/MM/yyyy').format(timestamp.toDate());
      });
    }
    final institutionRef = FirebaseFirestore.instance.collection('institutions').doc(institutionId);
    final results = await Future.wait([
      institutionRef.collection('clients').count().get(),
      institutionRef.collection('products').count().get(),
      institutionRef.collection('sales').get(),
    ]);
    final clientCount = (results[0] as AggregateQuerySnapshot).count ?? 0;
    final productCount = (results[1] as AggregateQuerySnapshot).count ?? 0;
    final salesSnapshot = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final salesCount = salesSnapshot.size;
    double totalRevenue = 0, monthRevenue = 0;
    final now = DateTime.now(), startOfMonth = DateTime(now.year, now.month, 1);
    for (var doc in salesSnapshot.docs) {
      final saleData = doc.data();
      final amount = (saleData['totalAmount'] as num? ?? 0).toDouble();
      totalRevenue += amount;
      if ((saleData['saleDate'] as Timestamp).toDate().isAfter(startOfMonth)) monthRevenue += amount;
    }
    return DashboardMetrics(clientCount: clientCount, productCount: productCount, salesCount: salesCount, totalRevenue: totalRevenue, monthRevenue: monthRevenue);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      // Atribuímos a chave ao Scaffold
      key: _scaffoldKey,
      drawer: _buildDrawer(context, textTheme, colorScheme),
      appBar: AppBar(
        leading: Showcase(
          key: _keyMenu,
          description: 'Toque aqui para aceder a todos os menus da aplicação.',
          onTargetClick: () async {
            // Usamos a chave para abrir o drawer
            _scaffoldKey.currentState?.openDrawer();
            Future.delayed(const Duration(milliseconds: 300), () {
              _startDrawerTour();
            });
          },
          disposeOnTap: true,
          child: IconButton(
            icon: const Icon(Icons.menu),
            // Usamos a chave para abrir o drawer
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        title: Column(
          children: [
            Text(_institutionName, style: textTheme.titleLarge),
            if (_expirationDateStr.isNotEmpty)
              Text('Licença expira em: $_expirationDateStr', style: textTheme.bodySmall?.copyWith(color: colorScheme.error, fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(tooltip: "Atualizar Dados", icon: const Icon(Icons.refresh), onPressed: () => setState(() { _metricsFuture = _fetchDashboardData(); })),
        ],
      ),
      body: _isOffline
          ? _buildOfflineBody()
          : FutureBuilder<DashboardMetrics>(
        future: _metricsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro ao carregar o painel: ${snapshot.error}"));
          }
          if (!snapshot.hasData || !snapshot.data!.hasData) {
            return _buildWelcomeBody(textTheme, colorScheme);
          }

          final metrics = snapshot.data!;
          return _buildDashboardGrid(metrics, currencyFormatter);
        },
      ),
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
            Text(
              'Painel inacessível',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Você está offline. As outras funcionalidades como registar vendas e clientes continuam disponíveis e serão sincronizadas quando a ligação voltar.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Widget para o corpo da página quando não há dados
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

  // Widget para o grid do dashboard
  Widget _buildDashboardGrid(DashboardMetrics metrics, NumberFormat currencyFormatter) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Showcase(
        key: _keyDashboard,
        description: 'Este é o seu painel principal. Aqui você tem uma visão rápida das métricas mais importantes do seu negócio.',
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.2,
          children: [
            DashboardCard(icon: Icons.attach_money, title: 'Vendas (Este Mês)', value: currencyFormatter.format(metrics.monthRevenue), color: Colors.green),
            DashboardCard(icon: Icons.receipt_long, title: 'Total de Vendas', value: currencyFormatter.format(metrics.totalRevenue), color: Colors.blue),
            DashboardCard(icon: Icons.people, title: 'Total de Clientes', value: metrics.clientCount.toString(), color: Colors.orange),
            DashboardCard(icon: Icons.inventory, title: 'Total de Produtos', value: metrics.productCount.toString(), color: Colors.purple),
            DashboardCard(icon: Icons.shopping_cart, title: 'Nº de Vendas', value: metrics.salesCount.toString(), color: Colors.teal),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context, TextTheme textTheme, ColorScheme colorScheme) {
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
          Showcase(
            key: _keyClients,
            description: 'Gerencie e edite facilmente as informações dos seus clientes.',
            child: ListTile(leading: const Icon(Icons.people_alt_outlined), title: const Text('Clientes'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const ClientsListPage())); })
          ),
          Showcase(
            key: _keyProducts,
            description: 'Cadastre e atualize seus produtos de forma prática e rápida.',
            child: ListTile(leading: const Icon(Icons.inventory_2_outlined), title: const Text('Produtos'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsListPage())); })
          ),
          Showcase(
            key: _keySales,
            description: 'Acompanhe todas as vendas realizadas com detalhes e facilidade.',
            child: ListTile(leading: const Icon(Icons.shopping_cart_outlined), title: const Text('Vendas'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesListPage())); })
          ),
          Showcase(
            key: _keyNewSale,
            description: 'Use este menu para registar uma nova venda rapidamente.',
            child: ListTile(leading: const Icon(Icons.point_of_sale_outlined), title: const Text('Registrar Venda'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const NewSalePage())); }),
          ),
          const Divider(),
          Showcase(
            key: _keyReplayTour,
            description: 'Pode rever este guia a qualquer momento clicando aqui.',
            disposeOnTap: true,
            onTargetClick: () => ShowCaseWidget.of(context).dismiss(),
            child: ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Rever Tour'),
              onTap: () {
                Navigator.pop(context);
                _startMainTour();
              },
            ),
          ),
          ListTile(leading: const Icon(Icons.info_outline), title: const Text('Informações'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const InfoPage())); }),
          Showcase(
            key: _keySettings,
            description: 'Aqui você pode alterar as configurações da aplicação, como o tema visual.',
            child: ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Configurações'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())); }),
          ),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Sair'), onTap: () => FirebaseAuth.instance.signOut()),
        ],
      ),
    );
  }
}
