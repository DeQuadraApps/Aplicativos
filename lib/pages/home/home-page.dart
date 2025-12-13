// lib/pages/home_page.dart
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:quadra_vendas/models/goal.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/pages/admin/permissions/manage-permissions.page.dart';
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
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:url_launcher/url_launcher.dart';

// --- ESTRUTURAS DE DADOS ---
class HomePageMetrics {
  final int clientCount;
  final int productCount;
  final int salesCount;
  final double totalRevenue;
  final double monthRevenue;
  final double weekRevenue;
  final double dayRevenue;
  final SalesGoal? monthlyGoal;
  final int? myClientsCount;
  final int newClientsMonthCount;

  HomePageMetrics({
    required this.clientCount,
    required this.productCount,
    required this.salesCount,
    required this.totalRevenue,
    required this.monthRevenue,
    required this.weekRevenue,
    required this.dayRevenue,
    required this.newClientsMonthCount,
    this.monthlyGoal,
    this.myClientsCount,
  });

  bool get hasData => clientCount > 0 || productCount > 0 || salesCount > 0;
}

// --- WIDGET PRINCIPAL ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(builder: (context) => const _HomePageContent());
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bool updateDialogShown = await _checkVersion();

      if (!updateDialogShown && mounted) {
        _promptTourIfNeeded();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

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

  Future<void> _launchUpdateURL() async {
    final url = Uri.parse(
      'https://dequadraapps.com.br/pages/produto-app1.html',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('não foi possível abrir a página de atualização.'),
          ),
        );
      }
    }
  }

  Future<bool> _checkVersion() async {
    // 1. "somente se estiver o app instalado.apk"
    // kReleaseMode é 'true' para builds de release (apk/aab) e 'false' para debug
    if (!kReleaseMode) {
      print('modo debug, pulando verificação de versão.');
      return false; // não está em release, não mostra o dialog
    }

    try {
      // 2. pega a versão local
      final packageInfo = await PackageInfo.fromPlatform();
      // 'buildNumber' é o 'versionCode' no android
      final localVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      final doc =
          await FirebaseFirestore.instance.doc('application/version').get();
      if (!doc.exists) {
        print('documento de versão não encontrado no firestore.');
        return false;
      }

      final remoteVersionCode = doc.data()?['versionCode'] as int? ?? 0;

      print(
        'versão local: $localVersionCode | versão remota: $remoteVersionCode',
      );

      if (localVersionCode < remoteVersionCode) {
        if (!mounted) return true;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (ctx) => WillPopScope(
                onWillPop: () async => false,
                child: AlertDialog(
                  title: const Text('Atualização Disponível'),
                  content: const Text(
                    'uma nova versão do aplicativo está disponível. por favor, atualize para a versão mais recente para continuar usando.',
                  ),
                  actions: [
                    TextButton(
                      child: const Text('ATUALIZAR AGORA'),
                      onPressed: _launchUpdateURL,
                    ),
                  ],
                ),
              ),
        );
        return true;
      }
    } catch (e) {
      print('erro ao verificar a versão: $e');
    }

    return false;
  }

  void _startMenuTour() {
    _scaffoldKey.currentState?.openDrawer();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) ShowCaseWidget.of(context).startShowCase(_getMenuTourKeys());
    });
  }

  void _startFullTour() {
    if (mounted)
      ShowCaseWidget.of(context).startShowCase([_keyDashboard, _keyMenu]);
  }

  Future<void> _initConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
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
    if (mounted) Navigator.pop(context);
    Widget pageToNavigate =
        (mode == 'direct') ? const DirectSalePage() : const NewSalePage();
    if (mounted)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pageToNavigate),
      );
  }

  Future<void> _promptTourIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final bool tourCompleted = prefs.getBool('home_tour_completed') ?? false;
    if (!tourCompleted && mounted) {
      final bool? wantTour = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Bem-vindo ao Quadra Vendas!'),
              content: const Text(
                'Gostaria de fazer um tour rápido pelas principais funcionalidades?',
              ),
              actions: [
                TextButton(
                  child: const Text('Agora não'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                ElevatedButton(
                  child: const Text('Sim, por favor'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
      );
      await prefs.setBool('home_tour_completed', true);
      if (wantTour == true) _startFullTour();
    }
  }

  Future<HomePageMetrics> _fetchHomePageData() async {
    if (currentUser == null) throw Exception("Utilizador não autenticado.");

    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();
    if (!userDoc.exists)
      throw Exception("Dados do utilizador não encontrados.");

    final localUserData = UserModel.fromFirestore(userDoc);
    final institutionId = localUserData.institutionId;
    final institutionRef = FirebaseFirestore.instance
        .collection('institutions')
        .doc(institutionId);

    final now = DateTime.now();
    // DEFINIÇÕES DE DATA
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfDay = DateTime(now.year, now.month, now.day);
    // (weekday: seg=1, dom=7) - subtrai os dias passados desde segunda
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekClean = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );

    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    Future<AggregateQuerySnapshot>? newClientsCountFuture;

    if (localUserData.role == 'admin') {
      final salespeopleSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('institutionId', isEqualTo: institutionId)
              .where('role', whereIn: ['employee', 'salesperson'])
              .get();
      _salespeople =
          salespeopleSnapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();

      newClientsCountFuture =
          institutionRef
              .collection('clients')
              .where('createdOn', isGreaterThanOrEqualTo: startOfMonth)
              .where('createdOn', isLessThanOrEqualTo: endOfMonth)
              .count()
              .get();
    }

    final institutionDocFuture = institutionRef.get();

    Query salesQuery = institutionRef.collection('sales');
    if (localUserData.role != 'admin') {
      salesQuery = salesQuery.where('userId', isEqualTo: currentUser!.uid);
    }
    // query pega todas as vendas, o filtro é feito no loop
    final salesSnapshotFuture = salesQuery.get();

    SalesGoal? monthlyGoal;
    if (localUserData.role != 'admin') {
      final goalQuery =
          await institutionRef
              .collection('goals')
              .where('salespersonId', isEqualTo: currentUser!.uid)
              .where('year', isEqualTo: now.year)
              .where('month', isEqualTo: now.month)
              .limit(1)
              .get();
      if (goalQuery.docs.isNotEmpty)
        monthlyGoal = SalesGoal.fromFirestore(goalQuery.docs.first);
    }

    int clientCount = 0,
        productCount = 0,
        myClientsCount = 0,
        newClientsMonthCount = 0;

    if (localUserData.role == 'admin') {
      final results = await Future.wait([
        institutionRef.collection('clients').count().get(),
        institutionRef.collection('products').count().get(),
      ]);
      clientCount = (results[0]).count ?? 0;
      productCount = (results[1]).count ?? 0;

      if (newClientsCountFuture != null) {
        final newClientsSnapshot = await newClientsCountFuture;
        newClientsMonthCount = newClientsSnapshot.count ?? 0;
      }
    } else {
      final myClientsSnapshot =
          await institutionRef
              .collection('clients')
              .where('salespersonId', isEqualTo: currentUser!.uid)
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
        _institutionName =
            institutionDoc.data()?['name'] ?? 'Instituição sem nome';
        final timestamp =
            institutionDoc.data()?['licenseExpiresAt'] as Timestamp?;
        if (timestamp != null)
          _expirationDateStr = DateFormat(
            'dd/MM/yyyy',
          ).format(timestamp.toDate());
      });
    }

    int salesCount = salesSnapshot.size;
    // INICIALIZA AS NOVAS VARIÁVEIS
    double totalRevenue = 0, monthRevenue = 0, weekRevenue = 0, dayRevenue = 0;

    for (var doc in salesSnapshot.docs) {
      final saleData = doc.data() as Map<String, dynamic>;
      final amount = (saleData['totalAmount'] as num? ?? 0).toDouble();
      final saleDate =
          (saleData['saleDate'] as Timestamp)
              .toDate(); // pegamos a data da venda

      totalRevenue += amount;

      // CÁLCULO DOS 3 PERÍODOS
      if (saleDate.isAfter(startOfMonth)) {
        monthRevenue += amount;
      }
      if (saleDate.isAfter(startOfWeekClean)) {
        weekRevenue += amount;
      }
      if (saleDate.isAfter(startOfDay)) {
        dayRevenue += amount;
      }
    }

    return HomePageMetrics(
      clientCount: clientCount,
      productCount: productCount,
      salesCount: salesCount,
      totalRevenue: totalRevenue,
      monthRevenue: monthRevenue,
      weekRevenue: weekRevenue,
      dayRevenue: dayRevenue,
      monthlyGoal: monthlyGoal,
      myClientsCount: myClientsCount,
      newClientsMonthCount: newClientsMonthCount,
    );
  }

  void _showChartPage(String title, Widget content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: content,
            ),
          );
        },
      ),
    );
  }

  void _showDetailsModal(String title, Widget content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(width: double.maxFinite, child: content),
          actions: <Widget>[
            TextButton(
              child: const Text('Fechar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
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
          child: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        title: Column(
          children: [
            Text(_institutionName, style: textTheme.titleLarge),
            if (_expirationDateStr.isNotEmpty && isAdmin)
              Text(
                'Licença expira em: $_expirationDateStr',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Atualizar Dados",
            icon: const Icon(Icons.refresh),
            onPressed:
                () => setState(() {
                  _metricsFuture = _fetchHomePageData();
                }),
          ),
        ],
      ),
      body:
          _isOffline
              ? _buildOfflineBody()
              : FutureBuilder<HomePageMetrics>(
                future: _metricsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError)
                    return Center(
                      child: Text(
                        "Erro ao carregar o painel: ${snapshot.error}",
                      ),
                    );
                  if (!snapshot.hasData || _currentUserData == null)
                    return _buildWelcomeBody(textTheme, colorScheme);
                  final metrics = snapshot.data!;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Showcase(
                      key: _keyDashboard,
                      description:
                          'Este é o seu painel principal, com as métricas mais importantes do seu negócio.',
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
    final currencyFormatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        double childAspectRatio = 2.0;

        if (constraints.maxWidth < 600) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth >= 800) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 2;
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          children: [
            DashboardCard(
              icon: Icons.attach_money,
              title: 'Minhas Vendas (Período)', // TÍTULO ATUALIZADO
              value: currencyFormatter.format(
                metrics.monthRevenue,
              ), // Continua mostrando o valor do mês
              color: Colors.green,
              onTap:
                  () => _showDetailsModal(
                    // MODAL ATUALIZADO
                    'Minhas Vendas',
                    _SalespersonSalesModal(
                      // ESTE É O NOVO WIDGET MODAL
                      institutionId: _institutionId!,
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
    final currencyFormatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        double childAspectRatio = 2.0;

        if (constraints.maxWidth < 600) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth > 1000) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 2;
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          children: [
            DashboardCard(
              icon: Icons.attach_money,
              title: 'Vendas (Período)', // TÍTULO ATUALIZADO
              value: currencyFormatter.format(metrics.monthRevenue),
              color: Colors.green,
              onTap:
                  () => _showDetailsModal(
                    'Vendas por Vendedor', // Título do Modal
                    _SalesValueBySalespersonModal(
                      institutionId: _institutionId!,
                      salespeople: _salespeople,
                    ),
                  ),
            ),
            DashboardCard(
              icon: Icons.people,
              title: 'Total de Clientes',
              value: metrics.clientCount.toString(),
              color: Colors.orange,
              onTap:
                  () => _showDetailsModal(
                    'Clientes por Vendedor',
                    _ClientsBySalespersonModal(
                      institutionId: _institutionId!,
                      salespeople: _salespeople,
                    ),
                  ),
            ),
            DashboardCard(
              icon: Icons.person_add_alt_1,
              title: 'Novos Clientes (Mês)',
              value: metrics.newClientsMonthCount.toString(),
              color: Colors.blue,
              onTap:
                  () => _showDetailsModal(
                    'Novos Clientes',
                    _NewClientsByMonthModal(institutionId: _institutionId!),
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
              title: 'Nº de Vendas (Período)', // TÍTULO ATUALIZADO
              value: metrics.salesCount.toString(),
              color: Colors.teal,
              onTap:
                  () => _showDetailsModal(
                    'Nº de Vendas por Vendedor', // Título do Modal
                    _SalesCountBySalespersonModal(
                      institutionId: _institutionId!,
                      salespeople: _salespeople,
                    ),
                  ),
            ),
            DashboardCard(
              icon: Icons.bar_chart,
              title: 'Relação de Vendas',
              value: 'Gráfico',
              color: Colors.redAccent,
              onTap:
                  () => _showChartPage(
                    'Evolução de Vendas Mensal',
                    _SalesComparisonChartModal(
                      institutionId: _institutionId!,
                      salespeople: _salespeople,
                    ),
                  ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOfflineBody() => const Center(
    child: Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 64),
          SizedBox(height: 16),
          Text('Você está Offline', textAlign: TextAlign.center),
          SizedBox(height: 8),
          Text(
            'O painel de métricas está inacessível, mas pode continuar a registar clientes e vendas.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
  Widget _buildWelcomeBody(TextTheme textTheme, ColorScheme colorScheme) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Bem-vindo à', style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                _institutionName,
                style: textTheme.headlineMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                "Comece por registar a sua primeira venda ou cliente!",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
  Drawer _buildDrawer(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
    bool isAdmin,
  ) => Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: colorScheme.primary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                _userName,
                style: textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                currentUser?.email ?? '',
                style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.home_outlined),
          title: const Text('Início'),
          onTap: () => Navigator.pop(context),
        ),
        if (isAdmin)
          Showcase(
            key: _keyVendedoresMenu,
            description: 'Gerencie aqui a sua equipa de vendedores.',
            child: ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Vendedores'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SalespeopleListPage(),
                  ),
                );
              },
            ),
          ),
        if (isAdmin)
          ListTile(
            leading: const Icon(Icons.lock_person_outlined),
            title: const Text('Permissões de Vendedores'),
            onTap: () {
              Navigator.pop(context);
              if (_institutionId != null) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ManagePermissionsPage(institutionId: _institutionId!)));
              }
            },
          ),
        if (isAdmin)
          Showcase(
            key: _keyRelatorioMenu,
            description:
                'Emita relatórios detalhados de vendas, produtos e clientes.',
            child: ListTile(
              leading: const Icon(Icons.assessment_outlined),
              title: const Text('Emitir Relatório'),
              onTap: () {
                Navigator.pop(context);
                if (_institutionId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              ReportOptionsPage(institutionId: _institutionId!),
                    ),
                  );
                }
              },
            ),
          ),
        Showcase(
          key: _keyClientesMenu,
          description:
              'Aceda aqui à sua lista de clientes para adicionar, editar ou visualizar.',
          child: ListTile(
            leading: const Icon(Icons.people_alt_outlined),
            title: const Text('Clientes'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ClientsListPage(),
                ),
              );
            },
          ),
        ),
        Showcase(
          key: _keyProdutosMenu,
          description: 'Aceda aqui à sua lista de produtos.',
          child: ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Produtos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProductsListPage(),
                ),
              );
            },
          ),
        ),
        Showcase(
          key: _keyVendasMenu,
          description: 'Visualize aqui o seu histórico de vendas realizadas.',
          child: ListTile(
            leading: const Icon(Icons.shopping_cart_outlined),
            title: const Text('Vendas'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SalesListPage()),
              );
            },
          ),
        ),
        Showcase(
          key: _keyRegistrarVendaMenu,
          description: 'Toque aqui para iniciar o registo de uma nova venda.',
          child: ListTile(
            leading: const Icon(Icons.point_of_sale_outlined),
            title: const Text('Registrar Venda'),
            onTap: _navigateToSalePage,
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Informações'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const InfoPage()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Configurações'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.school_outlined),
          title: const Text('Rever Tutorial'),
          onTap: () {
            Navigator.pop(context);
            _startFullTour();
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sair'),
          onTap: () => FirebaseAuth.instance.signOut(),
        ),
      ],
    ),
  );
}

// --- WIDGETS DOS CARDS E MODAIS ---

// Enum para controlar o período nos modais de vendas
enum SalesModalPeriod { Day, Week, Month }

class DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const DashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
  });

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
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientsBySalespersonModal extends StatelessWidget {
  final String institutionId;
  final List<UserModel> salespeople;
  const _ClientsBySalespersonModal({
    required this.institutionId,
    required this.salespeople,
  });

  Future<Map<String, int>> _fetchData() async {
    final clientsSnapshot =
        await FirebaseFirestore.instance
            .collection('institutions')
            .doc(institutionId)
            .collection('clients')
            .get();

    final clientsBySalesperson = <String, int>{};
    for (var doc in clientsSnapshot.docs) {
      final data = doc.data();
      final salespersonId = data['salespersonId'] as String;
      final salespersonName =
          salespeople
              .firstWhere(
                (s) => s.id == salespersonId,
                orElse:
                    () => UserModel(
                      id: '',
                      fullName: 'Sem Vendedor',
                      email: '',
                      institutionId: '',
                      role: '',
                    ),
              )
              .fullName;
      clientsBySalesperson[salespersonName] =
          (clientsBySalesperson[salespersonName] ?? 0) + 1;
    }
    return clientsBySalesperson;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _fetchData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const Text('Nenhum cliente encontrado.');

        final data = snapshot.data!;
        final entries =
            data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        return ListView(
          shrinkWrap: true,
          children:
              entries
                  .map(
                    (entry) => ListTile(
                      title: Text(entry.key),
                      trailing: Text(entry.value.toString()),
                    ),
                  )
                  .toList(),
        );
      },
    );
  }
}

class _SalesComparisonChartModal extends StatefulWidget {
  final String institutionId;
  final List<UserModel> salespeople;
  const _SalesComparisonChartModal({
    required this.institutionId,
    required this.salespeople,
  });

  @override
  State<_SalesComparisonChartModal> createState() =>
      _SalesComparisonChartModalState();
}

class _SalesComparisonChartModalState
    extends State<_SalesComparisonChartModal> {
  late Future<Map<String, Map<String, double>>> _dataFuture;
  PageController? _pageController;
  int _currentPage = 0;
  int _monthsPerPage = 4;
  List<String> _monthKeys = [];
  bool _initialPageIsSet = false;

  final List<Color> _barColors = [
    Colors.blue,
    Colors.orange,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.teal,
    Colors.pink,
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

  Future<Map<String, Map<String, double>>> _fetchChartDataForLastMonths(
    int numberOfMonths,
  ) async {
    final now = DateTime.now();
    final allMonthsData = <String, Map<String, double>>{};

    for (int i = 0; i < numberOfMonths; i++) {
      final targetMonth = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('MMM/yy', 'pt_BR').format(targetMonth);

      final startDate = DateTime(targetMonth.year, targetMonth.month, 1);
      final endDate = DateTime(
        targetMonth.year,
        targetMonth.month + 1,
        0,
        23,
        59,
        59,
      );

      final salesSnapshot =
          await FirebaseFirestore.instance
              .collection('institutions')
              .doc(widget.institutionId)
              .collection('sales')
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
        final salespersonName =
            widget.salespeople
                .firstWhere(
                  (s) => s.id == userId,
                  orElse:
                      () => UserModel(
                        id: '',
                        fullName: 'Desconhecido',
                        email: '',
                        institutionId: '',
                        role: '',
                      ),
                )
                .fullName;

        salesDataForMonth[salespersonName] =
            (salesDataForMonth[salespersonName] ?? 0) + amount;
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
    if (residual > 5)
      niceMultiplier = 10;
    else if (residual > 2)
      niceMultiplier = 5;
    else if (residual > 1)
      niceMultiplier = 2;
    else
      niceMultiplier = 1;

    final interval = niceMultiplier * magnitude;
    return interval > 0 ? interval : 1;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Map<String, double>>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
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
            firstMonthWithSalesIndex = _monthKeys.length - 1;
          }

          int initialPageIndex =
              (firstMonthWithSalesIndex / _monthsPerPage).floor();
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
                  final endIndex = min(
                    startIndex + _monthsPerPage,
                    _monthKeys.length,
                  );
                  final pageMonthKeys = _monthKeys.sublist(
                    startIndex,
                    endIndex,
                  );

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
                        ),
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
                            final salespersonName =
                                widget.salespeople[rodIndex].fullName
                                    .split(' ')
                                    .first;
                            final currencyFormatter = NumberFormat.currency(
                              locale: 'pt_BR',
                              symbol: 'R\$',
                            );
                            return BarTooltipItem(
                              '$salespersonName\n',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              children: <TextSpan>[
                                TextSpan(
                                  text: currencyFormatter.format(rod.toY),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 45,
                            interval: interval,
                            getTitlesWidget: (value, meta) {
                              if (value == 0 && pageMaxY > 0)
                                return const Text('0');
                              if (value > meta.max) return const Text('');
                              if (value >= 1000)
                                return Text(
                                  'R\$${(value / 1000).toStringAsFixed(0)}k',
                                );
                              return Text('R\$${value.toStringAsFixed(0)}');
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= pageMonthKeys.length)
                                return const Text('');
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  pageMonthKeys[index].split('/').first,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                      ),
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
                    Container(
                      width: 12,
                      height: 12,
                      color: _barColors[index % _barColors.length],
                    ),
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
                    onPressed:
                        _currentPage > 0
                            ? () {
                              _pageController?.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.ease,
                              );
                            }
                            : null,
                  ),
                  Text('${_currentPage + 1} / $totalPages'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed:
                        _currentPage < totalPages - 1
                            ? () {
                              _pageController?.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.ease,
                              );
                            }
                            : null,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _NewClientsByMonthModal extends StatefulWidget {
  final String institutionId;
  const _NewClientsByMonthModal({required this.institutionId});

  @override
  State<_NewClientsByMonthModal> createState() =>
      _NewClientsByMonthModalState();
}

class _NewClientsByMonthModalState extends State<_NewClientsByMonthModal> {
  late int _selectedMonth;
  late int _selectedYear;
  late Future<QuerySnapshot> _dataFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _dataFuture = _fetchData();
  }

  Future<QuerySnapshot> _fetchData() async {
    final startDate = DateTime(_selectedYear, _selectedMonth, 1);
    final endDate = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);

    return FirebaseFirestore.instance
        .collection('institutions')
        .doc(widget.institutionId)
        .collection('clients')
        .where('createdOn', isGreaterThanOrEqualTo: startDate)
        .where('createdOn', isLessThanOrEqualTo: endDate)
        .orderBy('createdOn', descending: true)
        .get();
  }

  void _onDateChanged() {
    setState(() {
      _dataFuture = _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final months = List.generate(
      12,
      (i) => DateFormat.MMMM('pt_BR').format(DateTime(0, i + 1)),
    );
    final years = List.generate(5, (i) => DateTime.now().year - i);
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButton<int>(
                value: _selectedMonth,
                isExpanded: true,
                items: List.generate(
                  12,
                  (i) => DropdownMenuItem(value: i + 1, child: Text(months[i])),
                ),
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
                items:
                    years
                        .map(
                          (y) => DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          ),
                        )
                        .toList(),
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
        FutureBuilder<QuerySnapshot>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError)
              return const Center(child: Text('Erro ao carregar clientes.'));

            final docs = snapshot.data?.docs ?? [];
            final count = docs.length;

            if (count == 0) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Nenhum cliente novo (0) encontrado para este período.',
                  ),
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    'Total de novos clientes: $count',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: count, // usa a variável 'count'
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final clientName =
                        data['companyName'] ?? 'Cliente sem nome';
                    String subtitle = 'Data de criação não registrada';

                    if (data['createdOn'] != null) {
                      final createdOnDate =
                          (data['createdOn'] as Timestamp).toDate();
                      subtitle =
                          'Criado em: ${dateFormatter.format(createdOnDate)}';
                    }

                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(clientName),
                      subtitle: Text(subtitle),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// Modal de Vendas para o VENDEDOR (com seletor de período)
class _SalespersonSalesModal extends StatefulWidget {
  final String institutionId;
  final String userId;
  const _SalespersonSalesModal({
    required this.institutionId,
    required this.userId,
  });

  @override
  State<_SalespersonSalesModal> createState() => _SalespersonSalesModalState();
}

class _SalespersonSalesModalState extends State<_SalespersonSalesModal> {
  // Define o período inicial como Mês
  SalesModalPeriod _selectedPeriod = SalesModalPeriod.Month;
  late Future<QuerySnapshot> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchData();
  }

  Future<QuerySnapshot> _fetchData() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now; // Para Dia e Semana, o fim é agora.

    switch (_selectedPeriod) {
      case SalesModalPeriod.Day:
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case SalesModalPeriod.Week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );
        break;
      case SalesModalPeriod.Month:
        // Para o vendedor, vamos sempre mostrar o mês corrente
        startDate = DateTime(now.year, now.month, 1);
        // E o fim do mês corrente
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
    }

    return FirebaseFirestore.instance
        .collection('institutions')
        .doc(widget.institutionId)
        .collection('sales')
        .where('userId', isEqualTo: widget.userId) // Filtro do vendedor
        .where('saleDate', isGreaterThanOrEqualTo: startDate)
        .where('saleDate', isLessThanOrEqualTo: endDate)
        .orderBy('saleDate', descending: true)
        .get();
  }

  void _onPeriodChanged(SalesModalPeriod? value) {
    if (value != null) {
      setState(() {
        _selectedPeriod = value;
        _dataFuture = _fetchData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );

    // ✨ 1. container para limitar a altura
    return Container(
      width: double.maxFinite,
      height: MediaQuery.of(context).size.height * 0.6, // 60% da tela
      child: Column(
        // ✨ mainaxissize.min removido
        children: [
          // --- SELETORES DE RÁDIO ---
          RadioListTile<SalesModalPeriod>(
            title: const Text('Hoje'),
            value: SalesModalPeriod.Day,
            groupValue: _selectedPeriod,
            onChanged: _onPeriodChanged,
          ),
          RadioListTile<SalesModalPeriod>(
            title: const Text('Esta Semana'),
            value: SalesModalPeriod.Week,
            groupValue: _selectedPeriod,
            onChanged: _onPeriodChanged,
          ),
          RadioListTile<SalesModalPeriod>(
            title: const Text('Este Mês'), // Simplificado (só mês corrente)
            value: SalesModalPeriod.Month,
            groupValue: _selectedPeriod,
            onChanged: _onPeriodChanged,
          ),
          const Divider(height: 24),

          // ✨ 2. expanded no futurebuilder
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Erro ao carregar vendas.'));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Nenhuma venda encontrada para este período.',
                      ),
                    ),
                  );
                }

                // Calcular o total
                double total = 0;
                for (var doc in docs) {
                  total +=
                      (doc.data() as Map<String, dynamic>)['totalAmount']
                          as num? ??
                      0;
                }

                // ✨ 3. column normal
                return Column(
                  children: [
                    // 1. Totalizador
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        'Total do Período: ${currencyFormatter.format(total)}',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),

                    // ✨ 4. expanded na listview
                    Expanded(
                      child: ListView.builder(
                        // ✨ shrinkwrap: true removido!
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          final title = data['clientName']?.toString() ?? 'N/A';
                          final amount =
                              (data['totalAmount'] as num? ?? 0).toDouble();
                          final subtitle = currencyFormatter.format(amount);

                          return ListTile(
                            leading: Icon(
                              Icons.receipt_long,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(title),
                            subtitle: Text(subtitle),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Modal de VALOR de Vendas para o ADMIN (com seletor de período)
class _SalesValueBySalespersonModal extends StatefulWidget {
  final String institutionId;
  final List<UserModel> salespeople;
  const _SalesValueBySalespersonModal({
    required this.institutionId,
    required this.salespeople,
  });

  @override
  State<_SalesValueBySalespersonModal> createState() =>
      _SalesValueBySalespersonModalState();
}

class _SalesValueBySalespersonModalState
    extends State<_SalesValueBySalespersonModal> {
  late int _selectedMonth;
  late int _selectedYear;
  SalesModalPeriod _selectedPeriod = SalesModalPeriod.Month; // estado do rádio
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
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    // lógica de data baseada no rádio
    switch (_selectedPeriod) {
      case SalesModalPeriod.Day:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = now;
        break;
      case SalesModalPeriod.Week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );
        endDate = now;
        break;
      case SalesModalPeriod.Month:
        startDate = DateTime(_selectedYear, _selectedMonth, 1);
        endDate = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
        break;
    }

    final salesSnapshot =
        await FirebaseFirestore.instance
            .collection('institutions')
            .doc(widget.institutionId)
            .collection('sales')
            .where('saleDate', isGreaterThanOrEqualTo: startDate)
            .where('saleDate', isLessThanOrEqualTo: endDate)
            .get();

    final salesBySalesperson = <String, double>{};
    for (var doc in salesSnapshot.docs) {
      final data = doc.data();
      final userId = data['userId'] as String;
      final amount = (data['totalAmount'] as num).toDouble();
      final salespersonName =
          widget.salespeople
              .firstWhere(
                (s) => s.id == userId,
                orElse:
                    () => UserModel(
                      id: '',
                      fullName: 'Desconhecido',
                      email: '',
                      institutionId: '',
                      role: '',
                    ),
              )
              .fullName;
      salesBySalesperson[salespersonName] =
          (salesBySalesperson[salespersonName] ?? 0) + amount;
    }
    return salesBySalesperson;
  }

  void _onPeriodChanged(SalesModalPeriod? value) {
    if (value != null) {
      setState(() {
        _selectedPeriod = value;
        _dataFuture = _fetchData();
      });
    }
  }

  void _onDateChanged() {
    setState(() {
      _dataFuture = _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final months = List.generate(
      12,
      (i) => DateFormat.MMMM('pt_BR').format(DateTime(0, i + 1)),
    );
    final years = List.generate(5, (i) => DateTime.now().year - i);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- seletores de rádio ---
        RadioListTile<SalesModalPeriod>(
          title: const Text('Hoje'),
          value: SalesModalPeriod.Day,
          groupValue: _selectedPeriod,
          onChanged: _onPeriodChanged,
        ),
        RadioListTile<SalesModalPeriod>(
          title: const Text('Esta Semana'),
          value: SalesModalPeriod.Week,
          groupValue: _selectedPeriod,
          onChanged: _onPeriodChanged,
        ),
        RadioListTile<SalesModalPeriod>(
          title: const Text('Este Mês (ou selecionar)'),
          value: SalesModalPeriod.Month,
          groupValue: _selectedPeriod,
          onChanged: _onPeriodChanged,
        ),

        // --- dropdowns de data (só aparecem para 'mês') ---
        if (_selectedPeriod == SalesModalPeriod.Month)
          Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  value: _selectedMonth,
                  isExpanded: true,
                  items: List.generate(
                    12,
                    (i) =>
                        DropdownMenuItem(value: i + 1, child: Text(months[i])),
                  ),
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
                  items:
                      years
                          .map(
                            (y) => DropdownMenuItem(
                              value: y,
                              child: Text(y.toString()),
                            ),
                          )
                          .toList(),
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

        // --- lista de resultados ---
        FutureBuilder<Map<String, double>>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.isEmpty)
              return const Text('Nenhuma venda encontrada para este período.');

            final data = snapshot.data!;
            final total = data.values.fold(0.0, (sum, item) => sum + item);
            final currencyFormatter = NumberFormat.currency(
              locale: 'pt_BR',
              symbol: 'R\$',
            );

            final entries =
                data.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

            return ListView(
              shrinkWrap: true,
              children: [
                ...entries.map(
                  (entry) => ListTile(
                    title: Text(entry.key),
                    trailing: Text(currencyFormatter.format(entry.value)),
                  ),
                ),
                const Divider(),
                ListTile(
                  title: const Text(
                    'Total do Período',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Text(
                    currencyFormatter.format(total),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// Modal de CONTAGEM de Vendas para o ADMIN (com seletor de período)
class _SalesCountBySalespersonModal extends StatefulWidget {
  final String institutionId;
  final List<UserModel> salespeople;
  const _SalesCountBySalespersonModal({
    required this.institutionId,
    required this.salespeople,
  });

  @override
  State<_SalesCountBySalespersonModal> createState() =>
      _SalesCountBySalespersonModalState();
}

class _SalesCountBySalespersonModalState
    extends State<_SalesCountBySalespersonModal> {
  late int _selectedMonth;
  late int _selectedYear;
  SalesModalPeriod _selectedPeriod = SalesModalPeriod.Month; // estado do rádio
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
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    // lógica de data baseada no rádio
    switch (_selectedPeriod) {
      case SalesModalPeriod.Day:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = now;
        break;
      case SalesModalPeriod.Week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );
        endDate = now;
        break;
      case SalesModalPeriod.Month:
        startDate = DateTime(_selectedYear, _selectedMonth, 1);
        endDate = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
        break;
    }

    final salesSnapshot =
        await FirebaseFirestore.instance
            .collection('institutions')
            .doc(widget.institutionId)
            .collection('sales')
            .where('saleDate', isGreaterThanOrEqualTo: startDate)
            .where('saleDate', isLessThanOrEqualTo: endDate)
            .get();

    final salesCount = <String, int>{};
    for (var doc in salesSnapshot.docs) {
      final data = doc.data();
      final userId = data['userId'] as String;
      final salespersonName =
          widget.salespeople
              .firstWhere(
                (s) => s.id == userId,
                orElse:
                    () => UserModel(
                      id: '',
                      fullName: 'Desconhecido',
                      email: '',
                      institutionId: '',
                      role: '',
                    ),
              )
              .fullName;
      salesCount[salespersonName] = (salesCount[salespersonName] ?? 0) + 1;
    }
    return salesCount;
  }

  void _onPeriodChanged(SalesModalPeriod? value) {
    if (value != null) {
      setState(() {
        _selectedPeriod = value;
        _dataFuture = _fetchData();
      });
    }
  }

  void _onDateChanged() {
    setState(() {
      _dataFuture = _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final months = List.generate(
      12,
      (i) => DateFormat.MMMM('pt_BR').format(DateTime(0, i + 1)),
    );
    final years = List.generate(5, (i) => DateTime.now().year - i);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- seletores de rádio ---
        RadioListTile<SalesModalPeriod>(
          title: const Text('Hoje'),
          value: SalesModalPeriod.Day,
          groupValue: _selectedPeriod,
          onChanged: _onPeriodChanged,
        ),
        RadioListTile<SalesModalPeriod>(
          title: const Text('Esta Semana'),
          value: SalesModalPeriod.Week,
          groupValue: _selectedPeriod,
          onChanged: _onPeriodChanged,
        ),
        RadioListTile<SalesModalPeriod>(
          title: const Text('Este Mês (ou selecionar)'),
          value: SalesModalPeriod.Month,
          groupValue: _selectedPeriod,
          onChanged: _onPeriodChanged,
        ),

        // --- dropdowns de data (só aparecem para 'mês') ---
        if (_selectedPeriod == SalesModalPeriod.Month)
          Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  value: _selectedMonth,
                  isExpanded: true,
                  items: List.generate(
                    12,
                    (i) =>
                        DropdownMenuItem(value: i + 1, child: Text(months[i])),
                  ),
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
                  items:
                      years
                          .map(
                            (y) => DropdownMenuItem(
                              value: y,
                              child: Text(y.toString()),
                            ),
                          )
                          .toList(),
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

        // --- lista de resultados ---
        FutureBuilder<Map<String, int>>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.isEmpty)
              return const Text('Nenhuma venda encontrada para este período.');

            final data = snapshot.data!;
            final entries =
                data.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

            return ListView(
              shrinkWrap: true,
              children:
                  entries
                      .map(
                        (entry) => ListTile(
                          title: Text(entry.key),
                          trailing: Text(entry.value.toString()),
                        ),
                      )
                      .toList(),
            );
          },
        ),
      ],
    );
  }
}
