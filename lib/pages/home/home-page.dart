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
import 'package:quadra_vendas/enums/plan-type.dart';
// IMPORTANTE: Certifique-se que os imports abaixo estão corretos para o seu projeto
import 'package:quadra_vendas/models/goal.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/pages/admin/permissions/manage-permissions.page.dart';
import 'package:quadra_vendas/pages/admin/reports/report-options.page.dart';
import 'package:quadra_vendas/pages/admin/salespeople/salespeople-list.page.dart';
import 'package:quadra_vendas/pages/clients/clients-list.page.dart';
import 'package:quadra_vendas/pages/financial/financial.page.dart';
import 'package:quadra_vendas/pages/info/info.page.dart';
import 'package:quadra_vendas/pages/product/product-list.page.dart';
import 'package:quadra_vendas/pages/reports/commission_report.page.dart';
import 'package:quadra_vendas/pages/sales/direct-sale.page.dart';
import 'package:quadra_vendas/pages/sales/new-sale.page.dart';
import 'package:quadra_vendas/pages/sales/sales-list.page.dart';
import 'package:quadra_vendas/pages/settings/settings.page.dart';
import 'package:quadra_vendas/services/subscription.service.dart';
import 'package:quadra_vendas/widgets/goal-progress-card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:url_launcher/url_launcher.dart';

// --- ENUM GLOBAL ---
enum SalesModalPeriod { Day, Week, Month }

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
  final List<QueryDocumentSnapshot> recentSales;

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
    this.recentSales = const [],
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
  final GlobalKey _keyFinanceiroMenu = GlobalKey();
  final GlobalKey _keyConfigMenu = GlobalKey();

  // ... Estados da Página ...
  String? _institutionId;
  String _institutionName = 'Carregando...';
  Map<String, dynamic>? _institutionData;
  String _expirationDateStr = '';
  String _userName = '';
  UserModel? _currentUserData;
  List<UserModel> _salespeople = [];

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

  // ... (Funções de Versão, Tour e Conectividade mantidas iguais) ...
  List<GlobalKey> _getMenuTourKeys() {
    final bool isAdmin = _currentUserData?.role == 'admin';
    final keys = <GlobalKey>[];

    // 1. Operacional (O mais usado)
    keys.add(_keyRegistrarVendaMenu);
    keys.add(_keyVendasMenu);

    // 2. Cadastros
    keys.add(_keyClientesMenu);
    keys.add(_keyProdutosMenu);

    // 3. Admin / Gestão
    if (isAdmin) {
      keys.add(_keyRelatorioMenu);
      keys.add(_keyFinanceiroMenu); // Nova chave
      keys.add(_keyVendedoresMenu);
    }

    // 4. Sistema
    keys.add(_keyConfigMenu); // Nova chave

    return keys;
  }

  Future<void> _launchUpdateURL() async {
    final url = Uri.parse(
      'https://dequadraapps.com.br/pages/produto-app1.html',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('não foi possível abrir a página de atualização.'),
          ),
        );
    }
  }

  Future<bool> _checkVersion() async {
    if (!kReleaseMode) return false;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final localVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      final doc =
      await FirebaseFirestore.instance.doc('application/version').get();
      if (!doc.exists) return false;
      final remoteVersionCode = doc.data()?['versionCode'] as int? ?? 0;

      if (localVersionCode < remoteVersionCode) {
        if (!mounted) return true;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (ctx) =>
              WillPopScope(
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
    Widget pageToNavigate =
    (mode == 'direct') ? const DirectSalePage() : const NewSalePage();
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pageToNavigate),
      );
    }
  }

  Future<void> _promptTourIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final bool tourCompleted = prefs.getBool('home_tour_completed') ?? false;
    if (!tourCompleted && mounted) {
      final bool? wantTour = await showDialog<bool>(
        context: context,
        builder:
            (context) =>
            AlertDialog(
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

  // --- CARREGAMENTO DE DADOS ---
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
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfDay = DateTime(now.year, now.month, now.day);
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

    // 1. RECUPERAR AS 5 ÚLTIMAS VENDAS
    final List<QueryDocumentSnapshot> sortedDocs = List.from(
      salesSnapshot.docs,
    );
    sortedDocs.sort((a, b) {
      Timestamp tA = a['saleDate'];
      Timestamp tB = b['saleDate'];
      return tB.compareTo(tA); // Decrescente
    });
    final recentSalesDocs = sortedDocs.take(5).toList();

    if (mounted) {
      setState(() {
        _institutionId = institutionId;
        Map<String, dynamic> data =
        institutionDoc.data() as Map<String, dynamic>;
        data['id'] = institutionId;
        _institutionData = data;
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
    double totalRevenue = 0,
        monthRevenue = 0,
        weekRevenue = 0,
        dayRevenue = 0;

    for (var doc in salesSnapshot.docs) {
      final saleData = doc.data() as Map<String, dynamic>;
      final amount = (saleData['totalAmount'] as num? ?? 0).toDouble();
      final saleDate = (saleData['saleDate'] as Timestamp).toDate();

      totalRevenue += amount;
      if (saleDate.isAfter(startOfMonth)) monthRevenue += amount;
      if (saleDate.isAfter(startOfWeekClean)) weekRevenue += amount;
      if (saleDate.isAfter(startOfDay)) dayRevenue += amount;
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
      recentSales: recentSalesDocs,
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

  // --- BUILD UI ---

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme
        .of(context)
        .textTheme;
    final colorScheme = Theme
        .of(context)
        .colorScheme;
    final bool isAdmin = _currentUserData?.role == 'admin';
    final activePlan = PlanType.fromString(_institutionData?['plan']);
    final bool isStartPlan = activePlan == PlanType.start;

    return Scaffold(
      key: _scaffoldKey,
      // Usa uma variante da cor de superfície para o fundo, criando profundidade
      backgroundColor: colorScheme.background,
      drawer: _buildDrawer(context, textTheme, colorScheme, isAdmin),
      appBar: AppBar(
        leading: Showcase(
          key: _keyMenu,
          description: 'Toque aqui para aceder a todos os menus.',
          disposeOnTap: true,
          onTargetClick: () => _startMenuTour(),
          child: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        title: Column(
          children: [
            // 1. NOME DA INSTITUIÇÃO (Mantém destaque)
            Text(
              _institutionName,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            // 2. LINHA COM PLANO E DATA
            // Usamos um Row para colocar um ao lado do outro ou centralizado
            if (_institutionData != null) ...[
              const SizedBox(height: 2), // Pequeno respiro
              Builder(
                  builder: (context) {
                    // Lógica para obter o nome do plano
                    final rawPlan = _institutionData!['plan'] ?? 'start';
                    final String planName = rawPlan.toString().toUpperCase();

                    // Lógica de Cores do Plano
                    Color badgeColor;
                    Color badgeTextColor;

                    if (rawPlan == 'elite') {
                      badgeColor = Colors.amber.shade100;
                      badgeTextColor = Colors.amber.shade900;
                    } else if (rawPlan == 'control' || rawPlan == 'pro') {
                      badgeColor = colorScheme.primaryContainer;
                      badgeTextColor = colorScheme.onPrimaryContainer;
                    } else {
                      // Start
                      badgeColor = colorScheme.surfaceVariant;
                      badgeTextColor = colorScheme.onSurfaceVariant;
                    }

                    // Lógica da Data (Agressividade Condicional)
                    bool isUrgent = false;
                    if (_institutionData!['licenseExpiresAt'] != null) {
                      final expireDate = (_institutionData!['licenseExpiresAt'] as Timestamp)
                          .toDate();
                      final daysLeft = expireDate
                          .difference(DateTime.now())
                          .inDays;
                      if (daysLeft < 7) isUrgent =
                      true; // Só fica vermelho se faltar menos de uma semana
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // BADGE DO PLANO
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PLANO $planName',
                            style: TextStyle(
                              fontSize: 9,
                              color: badgeTextColor,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                        // DATA DE EXPIRAÇÃO (Aparece só para Admin se tiver data)
                        if (_expirationDateStr.isNotEmpty && isAdmin) ...[
                          const SizedBox(width: 6),
                          Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                  color: colorScheme.outline,
                                  shape: BoxShape.circle)
                          ), // Pontinho separador
                          const SizedBox(width: 6),
                          Text(
                            isUrgent
                                ? 'Vence em $_expirationDateStr'
                                : 'Renova em $_expirationDateStr',
                            style: textTheme.labelSmall?.copyWith(
                              // Se for urgente usa cor de erro, senão usa cinza discreto
                              color: isUrgent ? colorScheme.error : colorScheme
                                  .onSurfaceVariant.withOpacity(0.7),
                              fontSize: 10,
                              fontWeight: isUrgent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ]
                      ],
                    );
                  }
              ),
            ]
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Atualizar Dados",
            icon: const Icon(Icons.refresh),
            onPressed:
                () =>
                setState(() {
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

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _metricsFuture = _fetchHomePageData();
              });
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Showcase(
                key: _keyDashboard,
                description: 'Este é o seu painel principal.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. HERO CARD (Faturamento)
                    _buildHeroRevenueCard(metrics, colorScheme),
                    const SizedBox(height: 20),

                    // 2. AÇÕES RÁPIDAS
                    _buildQuickActions(context, colorScheme),
                    const SizedBox(height: 20),

                    // 3. METAS (Se existir e não for admin)
                    if (!isAdmin && metrics.monthlyGoal != null) ...[
                      GoalProgressCard(
                        goal: metrics.monthlyGoal!,
                        totalSold: metrics.monthRevenue,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 4. GRID DE MÉTRICAS
                    Text(
                      "Visão Geral",
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isAdmin)
                      _buildAdminDashboard(
                        metrics,
                        isStartPlan,
                        colorScheme,
                      )
                    else
                      _buildSalespersonDashboard(metrics, colorScheme),

                    const SizedBox(height: 20),

                    // 5. ÚLTIMAS VENDAS
                    if (metrics.recentSales.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Últimas Vendas",
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed:
                                () =>
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                    const SalesListPage(),
                                  ),
                                ),
                            child: const Text("Ver todas"),
                          ),
                        ],
                      ),
                      _buildRecentSalesList(
                        metrics.recentSales,
                        context,
                        colorScheme,
                        textTheme,
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- NOVOS WIDGETS DE UI (USANDO O TEMA) ---

  Widget _buildHeroRevenueCard(HomePageMetrics metrics,
      ColorScheme colorScheme,) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Gradiente usando a cor primária e uma versão ligeiramente transparente dela
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Usa onPrimary para texto sobre a cor primária
              Text(
                "Faturamento (Este Mês)",
                style: TextStyle(
                  color: colorScheme.onPrimary.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              Icon(
                Icons.trending_up,
                color: colorScheme.onPrimary.withOpacity(0.8),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            currencyFormatter.format(metrics.monthRevenue),
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  // Fundo semitransparente para contraste
                  color: colorScheme.onPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "Esta Semana: ${currencyFormatter.format(
                          metrics.weekRevenue)}",
                      style: TextStyle(
                          color: colorScheme.onPrimary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  // Fundo semitransparente para contraste
                  color: colorScheme.onPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "Hoje: ${currencyFormatter.format(metrics.dayRevenue)}",
                      style: TextStyle(
                          color: colorScheme.onPrimary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _QuickActionButton(
          icon: Icons.add_shopping_cart,
          label: "Nova Venda",
          // Ação principal: Cor Primária
          color: colorScheme.primary,
          onTap: _navigateToSalePage,
        ),
        _QuickActionButton(
          icon: Icons.person_add_alt,
          label: "Novo Cliente",
          // Ação secundária: Cor Secundária
          color: colorScheme.secondary,
          onTap:
              () =>
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ClientsListPage(),
                ),
              ),
        ),
        _QuickActionButton(
          icon: Icons.inventory_2,
          label: "Produtos",
          // Ação terciária: Cor Terciária
          color: colorScheme.tertiary,
          onTap:
              () =>
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProductsListPage(),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildRecentSalesList(List<QueryDocumentSnapshot> docs,
      BuildContext context,
      ColorScheme colorScheme,
      TextTheme textTheme,) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );

    return Column(
      children:
      docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['totalAmount'] as num? ?? 0).toDouble();
        final clientName = data['clientName'] ?? 'Consumidor Final';
        final date = (data['saleDate'] as Timestamp).toDate();
        final timeStr = DateFormat('HH:mm').format(date);
        final dateStr = DateFormat('dd/MM').format(date);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          // Cor de fundo do card baseada na superfície
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              // Fundo do avatar usa o container da cor primária
              backgroundColor: colorScheme.primaryContainer,
              // Ícone usa a cor "on" do container
              child: Icon(
                Icons.attach_money,
                color: colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            title: Text(
              clientName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            // Subtítulo usa a cor de texto secundária do tema
            subtitle: Text(
              "$dateStr às $timeStr",
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Text(
              currencyFormatter.format(amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: colorScheme.primary,
              ),
            ),
            onTap: () {
              // Pode adicionar navegação para detalhe da venda aqui se quiser
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSalespersonDashboard(HomePageMetrics metrics,
      ColorScheme colorScheme) {
    final currencyFormatter = NumberFormat.currency(
        locale: 'pt_BR', symbol: 'R\$');

    return LayoutBuilder(
      builder: (context, constraints) {
        // --- CORREÇÃO AQUI ---
        // Se a tela for pequena (< 600px), usa 2 colunas.
        // Se for maior (Tablet/PC), usa 3 colunas (para os 3 cards ficarem na mesma linha e menores).
        int crossAxisCount = constraints.maxWidth < 600 ? 2 : 3;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          // Mantém a proporção retangular bonita
          children: [
            DashboardCard(
              icon: Icons.attach_money,
              title: 'Minhas Vendas',
              value: currencyFormatter.format(metrics.monthRevenue),
              color: colorScheme.primary,
              isSmall: true,
              onTap: () =>
                  _showDetailsModal('Minhas Vendas',
                  _SalespersonSalesModal(institutionId: _institutionId!,
                      userId: currentUser!.uid)),
            ),
            DashboardCard(
              icon: Icons.receipt_long,
              title: 'Nº de Vendas',
              value: metrics.salesCount.toString(),
              color: colorScheme.secondary,
              // Mudei para secondary para variar a cor
              isSmall: true,
            ),
            DashboardCard(
              icon: Icons.people,
              title: 'Meus Clientes',
              value: metrics.myClientsCount?.toString() ?? '0',
              color: colorScheme.tertiary,
              // Mudei para tertiary
              isSmall: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdminDashboard(HomePageMetrics metrics,
      bool isStartPlan,
      ColorScheme colorScheme,) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            DashboardCard(
              icon: Icons.people_outline,
              title: 'Clientes',
              value: metrics.clientCount.toString(),
              // Clientes -> Secundária
              color: colorScheme.secondary,
              isSmall: true,
              onTap:
                  () =>
                  _showDetailsModal(
                    'Clientes por Vendedor',
                    _ClientsBySalespersonModal(
                      institutionId: _institutionId!,
                      salespeople: _salespeople,
                    ),
                  ),
            ),
            DashboardCard(
              icon: Icons.shopping_bag_outlined,
              title: 'Vendas (Qtd)',
              value: metrics.salesCount.toString(),
              // Vendas -> Primária
              color: colorScheme.primary,
              isSmall: true,
              onTap:
                  () =>
                  _showDetailsModal(
                    'Nº de Vendas por Vendedor',
                    _SalesCountBySalespersonModal(
                      institutionId: _institutionId!,
                      salespeople: _salespeople,
                    ),
                  ),
            ),
            DashboardCard(
              icon: Icons.person_add_outlined,
              title: 'Novos (Mês)',
              value: metrics.newClientsMonthCount.toString(),
              // Novos Clientes -> Terciária (Destaque)
              color: colorScheme.tertiary,
              isSmall: true,
              onTap:
                  () =>
                  _showDetailsModal(
                    'Novos Clientes',
                    _NewClientsByMonthModal(institutionId: _institutionId!),
                  ),
            ),
            DashboardCard(
              icon: Icons.bar_chart,
              title: 'Evolução',
              value: 'Gráfico',
              // Gráficos/Dados -> Secundária (ou outra cor de destaque do tema)
              color: colorScheme.secondary,
              isSmall: true,
              onTap:
                  () =>
                  _showChartPage(
                    'Evolução de Vendas Mensal',
                    _SalesComparisonChartModal(
                      institutionId: _institutionId!,
                      salespeople: _salespeople,
                    ),
                  ),
            ),

            // CARD FINANCEIRO (Lógica do Plano Start)
            if (isStartPlan)
              DashboardCard(
                icon: Icons.lock_outline,
                title: 'Financeiro',
                value: 'Bloqueado',
                // Bloqueado -> Usar cor de contorno/desabilitado do tema
                color: colorScheme.outline,
                isSmall: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Faça upgrade para ver o lucro líquido e despesas.",
                      ),
                    ),
                  );
                },
              )
            else
              DashboardCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Financeiro',
                value: 'Acessar',
                // Acesso liberado -> Primária (É o módulo principal)
                color: colorScheme.primary,
                isSmall: true,
                onTap: () {
                  if (_institutionData != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                            FinancialPage(
                              institutionData: _institutionData!,
                            ),
                      ),
                    );
                  }
                },
              ),
            if (isStartPlan)
              DashboardCard(
                icon: Icons.lock_outline,
                title: 'Comissões',
                value: 'Bloqueado',
                // Bloqueado -> Usar cor de contorno/desabilitado do tema
                color: colorScheme.outline,
                isSmall: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Faça upgrade para ver as comissões de seus vendedores.",
                      ),
                    ),
                  );
                },
              )
            else
              DashboardCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Comissões',
                value: 'Acessar',
                color: colorScheme.primary,
                isSmall: true,
                onTap: () {
                  if (_institutionData != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => CommissionReportPage(),
                      ),
                    );
                  }
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildOfflineBody() =>
      const Center(
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

  Drawer _buildDrawer(BuildContext context,
      TextTheme textTheme,
      ColorScheme colorScheme,
      bool isAdmin,) {
    bool isFinancialLocked() {
      if (_institutionData == null) return true;
      return !SubscriptionService(_institutionData!).canAccessFinancialModule;
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primary),
            accountName: Text(
              _userName,
              style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimary.withOpacity(0.8),
                  fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              currentUser?.email ?? '',
              style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimary.withOpacity(0.8)),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                style: TextStyle(fontSize: 24, color: colorScheme.primary),
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Visão Geral'),
            onTap: () => Navigator.pop(context),
          ),

          const Divider(),

          // --- OPERACIONAL ---
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
            child: Text("Operacional", style: textTheme.labelLarge?.copyWith(
                color: colorScheme.secondary)),
          ),
          Showcase(
            key: _keyRegistrarVendaMenu,
            description: 'Toque aqui para iniciar uma nova venda rapidamente.',
            child: ListTile(
              leading: const Icon(Icons.add_shopping_cart, color: Colors.green),
              title: const Text(
                  'Nova Venda', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: _navigateToSalePage,
            ),
          ),
          Showcase(
            key: _keyVendasMenu,
            description: 'Consulte aqui todo o histórico de vendas realizadas.',
            child: ListTile(
              leading: const Icon(Icons.list_alt_outlined),
              title: const Text('Histórico de Vendas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const SalesListPage()));
              },
            ),
          ),

          // --- CADASTROS ---
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
            child: Text("Cadastros", style: textTheme.labelLarge?.copyWith(
                color: colorScheme.secondary)),
          ),
          Showcase(
            key: _keyClientesMenu,
            description: 'Gerencie sua carteira de clientes aqui.',
            child: ListTile(
              leading: const Icon(Icons.people_alt_outlined),
              title: const Text('Clientes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const ClientsListPage()));
              },
            ),
          ),
          Showcase(
            key: _keyProdutosMenu,
            description: 'Cadastre e edite seus produtos ou serviços.',
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Produtos'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const ProductsListPage()));
              },
            ),
          ),

          // --- ADMINISTRAÇÃO ---
          if (isAdmin) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Text("Gestão & Financeiro",
                  style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.secondary)),
            ),

            Showcase(
              key: _keyRelatorioMenu,
              description: 'Acesse relatórios gerenciais e estatísticas avançadas.',
              child: ListTile(
                leading: const Icon(Icons.assessment_outlined),
                title: const Text('Relatórios Gerenciais'),
                onTap: () {
                  Navigator.pop(context);
                  if (_institutionId != null) {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (context) =>
                            ReportOptionsPage(institutionId: _institutionId!)));
                  }
                },
              ),
            ),

            // FINANCEIRO COM SHOWCASE
            Builder(builder: (context) {
              final isLocked = isFinancialLocked();
              final iconColor = isLocked ? Colors.grey : colorScheme
                  .onSurfaceVariant;

              // Envolvemos o ExpansionTile no Showcase
              return Showcase(
                key: _keyFinanceiroMenu,
                description: 'Controle seu fluxo de caixa e comissões aqui.',
                child: ExpansionTile(
                  leading: Icon(
                      Icons.account_balance_wallet_outlined, color: iconColor),
                  title: const Text('Financeiro'),
                  subtitle: isLocked ? const Text(
                      "Plano Básico", style: TextStyle(fontSize: 10)) : null,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 32),
                      leading: const Icon(Icons.attach_money, size: 20),
                      title: const Text('Fluxo de Caixa'),
                      trailing: isLocked
                          ? const Icon(Icons.lock, size: 16)
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        if (_institutionData != null) {
                          Navigator.push(context, MaterialPageRoute(
                              builder: (context) =>
                                  FinancialPage(
                                  institutionData: _institutionData!)));
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 32),
                      leading: const Icon(Icons.percent, size: 20),
                      title: const Text('Comissões'),
                      trailing: isLocked
                          ? const Icon(Icons.lock, size: 16)
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (
                            context) => const CommissionReportPage()));
                      },
                    ),
                  ],
                ),
              );
            }),

            ExpansionTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Equipe'),
              children: [
                Showcase(
                  key: _keyVendedoresMenu,
                  description: 'Adicione ou remova vendedores da sua equipe.',
                  child: ListTile(
                    contentPadding: const EdgeInsets.only(left: 32),
                    leading: const Icon(Icons.badge_outlined, size: 20),
                    title: const Text('Vendedores'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const SalespeopleListPage()));
                    },
                  ),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 32),
                  leading: const Icon(Icons.lock_person_outlined, size: 20),
                  title: const Text('Permissões de Acesso'),
                  onTap: () {
                    Navigator.pop(context);
                    if (_institutionId != null) {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) =>
                              ManagePermissionsPage(
                                  institutionId: _institutionId!)));
                    }
                  },
                ),
              ],
            ),
          ],

          const Divider(),

          // CONFIGURAÇÕES COM SHOWCASE
          Showcase(
            key: _keyConfigMenu,
            description: 'Ajuste as preferências do aplicativo e dados da empresa.',
            child: ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Configurações'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const SettingsPage()));
              },
            ),
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Informações'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const InfoPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Ajuda & Tutorial'),
            onTap: () {
              Navigator.pop(context);
              _startFullTour(); // Reinicia o tour completo
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: colorScheme.error),
            title: Text('Sair', style: TextStyle(color: colorScheme.error)),
            onTap: () => FirebaseAuth.instance.signOut(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// --- WIDGETS AUXILIARES ---
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    // Usa o tema para as cores do botão de ação rápida
    final colorScheme = Theme.of(context).colorScheme;
    // O fundo é uma versão transparente da cor passada (que será primary/secondary/tertiary)
    final backgroundColor = color.withOpacity(0.1);
    // O ícone e o texto usam a própria cor
    final contentColor = color;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: contentColor, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  final bool isSmall;
  const DashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
    this.isSmall = false,
  });
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Usa a cor passada (primary/secondary/etc) para o ícone e seu fundo
    final iconBackgroundColor = color.withOpacity(0.1);
    final iconColor = color;

    return Card(
      elevation: 0,
      // Cor de fundo do card baseada na superfície do tema
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const Spacer(),
              Text(
                value,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: value.length > 5 ? 20 : 24,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
    // (Mantido a mesma lógica de busca...)
    final clientsSnapshot = await FirebaseFirestore.instance
        .collection('institutions')
        .doc(institutionId)
        .collection('clients')
        .get();

    final clientsBySalesperson = <String, int>{};
    for (var doc in clientsSnapshot.docs) {
      final data = doc.data();
      final salespersonId = data['salespersonId'] as String? ?? '';

      // Busca segura pelo nome
      final salespersonName = salespeople
          .firstWhere((s) => s.id == salespersonId,
          orElse: () => UserModel(id: '', fullName: 'Sem Vendedor', email: '', institutionId: '', role: ''))
          .fullName;

      clientsBySalesperson[salespersonName] = (clientsBySalesperson[salespersonName] ?? 0) + 1;
    }
    return clientsBySalesperson;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.maxFinite,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      child: FutureBuilder<Map<String, int>>(
        future: _fetchData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum dado encontrado.'));
          }

          final data = snapshot.data!;
          final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final colorScheme = Theme.of(context).colorScheme;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pie_chart, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text("Total: ${entries.fold(0, (sum, item) => sum + item.value)} clientes"),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final initial = entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?';

                    return Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: index < 3 ? colorScheme.primary : colorScheme.surfaceVariant,
                          foregroundColor: index < 3 ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                          child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            entry.value.toString(),
                            style: TextStyle(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
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
  State<_SalesComparisonChartModal> createState() => _SalesComparisonChartModalState();
}

class _SalesComparisonChartModalState extends State<_SalesComparisonChartModal> {
  late Future<Map<String, Map<String, double>>> _dataFuture;
  PageController? _pageController;
  int _currentPage = 0;
  final int _monthsPerPage = 4; // Mostra 4 meses por vez
  List<String> _monthKeys = [];
  bool _initialPageIsSet = false;

  // Paleta de cores moderna
  final List<Color> _barColors = [
    const Color(0xFF6750A4), // Primary Purple
    const Color(0xFFB58392), // Pinkish
    const Color(0xFF63A002), // Green
    const Color(0xFF9C4146), // Reddish
    const Color(0xFF006D77), // Teal
    const Color(0xFFE29578), // Orange/Peach
  ];

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchOptimizedData(12);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  // Busca TUDO de uma vez (Economiza leituras no Firebase)
  Future<Map<String, Map<String, double>>> _fetchOptimizedData(int monthsBack) async {
    final now = DateTime.now();
    // Data inicial: 1º dia do mês, 'monthsBack' meses atrás
    final startTarget = DateTime(now.year, now.month - monthsBack + 1, 1);

    // Query única
    final querySnapshot = await FirebaseFirestore.instance
        .collection('institutions')
        .doc(widget.institutionId)
        .collection('sales')
        .where('saleDate', isGreaterThanOrEqualTo: startTarget)
        .get();

    // Estrutura para armazenar: Mês -> {Vendedor: Valor}
    // Inicializa todos os meses com 0 para todos os vendedores
    final Map<String, Map<String, double>> aggregatedData = {};
    for (int i = 0; i < monthsBack; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('MMM/yy', 'pt_BR').format(d);
      aggregatedData[key] = {for (var s in widget.salespeople) s.fullName: 0.0};
    }

    // Processa os documentos em memória
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final saleDate = (data['saleDate'] as Timestamp).toDate();
      final amount = (data['totalAmount'] as num).toDouble();
      final userId = data['userId'] as String? ?? '';

      final monthKey = DateFormat('MMM/yy', 'pt_BR').format(saleDate);

      // Acha o nome do vendedor (ou 'Outros' se não estiver na lista ativa)
      final salesperson = widget.salespeople.firstWhere(
            (s) => s.id == userId,
        orElse: () => UserModel(id: '', fullName: 'Outros', email: '', institutionId: '', role: ''),
      );

      if (aggregatedData.containsKey(monthKey)) {
        final currentVal = aggregatedData[monthKey]![salesperson.fullName] ?? 0.0;
        aggregatedData[monthKey]![salesperson.fullName] = currentVal + amount;
      }
    }
    return aggregatedData;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // Altura confortável
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: FutureBuilder<Map<String, Map<String, double>>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Sem dados para exibir.'));
          }

          final allData = snapshot.data!;
          // Ordena chaves cronologicamente (do mais antigo para o novo) para o gráfico,
          // ou reverso se preferir. Aqui mantive reverso (mais recente primeiro) para a paginação funcionar da direita pra esquerda.
          _monthKeys = allData.keys.toList(); // Já vieram na ordem gerada (recente -> antigo)

          // Configura paginação inicial se houver dados
          if (!_initialPageIsSet) {
            _pageController = PageController(initialPage: 0);
            _initialPageIsSet = true;
          }

          final totalPages = (_monthKeys.length / _monthsPerPage).ceil();

          return Column(
            children: [
              // LEGENDA
              Container(
                padding: const EdgeInsets.only(bottom: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: List.generate(widget.salespeople.length, (index) {
                    final spName = widget.salespeople[index].fullName.split(' ').first;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _barColors[index % _barColors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(spName, style: textTheme.bodySmall),
                      ],
                    );
                  }),
                ),
              ),

              // GRÁFICO COM PAGINAÇÃO
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: totalPages,
                  reverse: true, // Para começar do mês mais recente (direita)
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemBuilder: (context, pageIndex) {
                    // Lógica para fatiar os meses corretos para esta página
                    final startIndex = pageIndex * _monthsPerPage;
                    final endIndex = min(startIndex + _monthsPerPage, _monthKeys.length);
                    // Pega sublista e INVERTE para exibir cronologicamente na tela (Jan -> Fev -> Mar)
                    final pageKeys = _monthKeys.sublist(startIndex, endIndex).reversed.toList();

                    // Calcula MaxY local para escala dinâmica
                    double maxY = 0;
                    final List<BarChartGroupData> barGroups = [];

                    for (int i = 0; i < pageKeys.length; i++) {
                      final key = pageKeys[i];
                      final monthValues = allData[key]!;
                      final rods = <BarChartRodData>[];

                      for (int j = 0; j < widget.salespeople.length; j++) {
                        final val = monthValues[widget.salespeople[j].fullName] ?? 0.0;
                        if (val > maxY) maxY = val;

                        rods.add(BarChartRodData(
                          toY: val,
                          color: _barColors[j % _barColors.length],
                          width: 14,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          backDrawRodData: BackgroundBarChartRodData(show: false),
                        ));
                      }
                      barGroups.add(BarChartGroupData(x: i, barRods: rods, barsSpace: 4));
                    }

                    // Se tudo for 0, define um mínimo visual
                    if (maxY == 0) maxY = 1000;
                    // Adiciona um respiro no topo (20%)
                    maxY *= 1.2;

                    return BarChart(
                      BarChartData(
                        maxY: maxY,
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: barGroups,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY / 5,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: colorScheme.outlineVariant.withOpacity(0.5),
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              maxIncluded: false,
                              getTitlesWidget: (value, meta) {
                                if (value == 0) return const SizedBox.shrink();
                                return Text(
                                  NumberFormat.compact(locale: 'pt_BR').format(value),
                                  style: TextStyle(color: colorScheme.outline, fontSize: 10),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= pageKeys.length) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    pageKeys[idx].split('/')[0], // Apenas o Mês (Ex: JAN)
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => colorScheme.inverseSurface,
                            tooltipPadding: const EdgeInsets.all(8),
                            tooltipMargin: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final person = widget.salespeople[rodIndex].fullName.split(' ')[0];
                              return BarTooltipItem(
                                '$person\n',
                                TextStyle(color: colorScheme.onInverseSurface, fontWeight: FontWeight.bold),
                                children: [
                                  TextSpan(
                                    text: NumberFormat.currency(symbol: 'R\$', decimalDigits: 0).format(rod.toY),
                                    style: TextStyle(color: colorScheme.onInverseSurface, fontWeight: FontWeight.normal),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // CONTROLES DE PÁGINA
              if (totalPages > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _pageController?.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      ),
                      Text(
                        "Página ${_currentPage + 1} de $totalPages",
                        style: textTheme.bodySmall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _pageController?.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NewClientsByMonthModal extends StatefulWidget {
  final String institutionId;
  const _NewClientsByMonthModal({required this.institutionId});
  @override
  State<_NewClientsByMonthModal> createState() => _NewClientsByMonthModalState();
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
    final colorScheme = Theme.of(context).colorScheme;
    final months = List.generate(12, (i) => DateFormat.MMMM('pt_BR').format(DateTime(0, i + 1)));
    final years = List.generate(5, (i) => DateTime.now().year - i);
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return SizedBox(
      width: double.maxFinite,
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          // SELETOR DE DATA ESTILIZADO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DropdownButton<int>(
                  value: _selectedMonth,
                  underline: Container(),
                  icon: Icon(Icons.arrow_drop_down, color: colorScheme.primary),
                  items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i].toUpperCase(), style: const TextStyle(fontSize: 12)))),
                  onChanged: (v) { if (v != null) { _selectedMonth = v; _onDateChanged(); }},
                ),
                Container(width: 1, height: 24, color: colorScheme.outline),
                DropdownButton<int>(
                  value: _selectedYear,
                  underline: Container(),
                  icon: Icon(Icons.arrow_drop_down, color: colorScheme.primary),
                  items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                  onChanged: (v) { if (v != null) { _selectedYear = v; _onDateChanged(); }},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) return const Center(child: Text('Nenhum novo cliente.'));

                return Column(
                  children: [
                    Text("${docs.length} Novos Registros", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final clientName = data['companyName'] ?? data['name'] ?? 'Sem nome';
                          final createdOn = (data['createdOn'] as Timestamp).toDate();

                          return ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: colorScheme.tertiaryContainer, shape: BoxShape.circle),
                              child: Icon(Icons.person_add, size: 16, color: colorScheme.onTertiaryContainer),
                            ),
                            title: Text(clientName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Cadastrado em: ${dateFormatter.format(createdOn)}'),
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

class _SalespersonSalesModal extends StatefulWidget {
  final String institutionId;
  final String userId;
  const _SalespersonSalesModal({required this.institutionId, required this.userId});

  @override
  State<_SalespersonSalesModal> createState() => _SalespersonSalesModalState();
}

class _SalespersonSalesModalState extends State<_SalespersonSalesModal> {
  SalesModalPeriod _selectedPeriod = SalesModalPeriod.Month;
  late Future<QuerySnapshot> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchData();
  }

  Future<QuerySnapshot> _fetchData() {
    final now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, 1);
    DateTime endDate = now;

    switch (_selectedPeriod) {
      case SalesModalPeriod.Day:
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case SalesModalPeriod.Week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        break;
      case SalesModalPeriod.Month:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
    }

    return FirebaseFirestore.instance
        .collection('institutions')
        .doc(widget.institutionId)
        .collection('sales')
        .where('userId', isEqualTo: widget.userId)
        .where('saleDate', isGreaterThanOrEqualTo: startDate)
        .where('saleDate', isLessThanOrEqualTo: endDate)
        .orderBy('saleDate', descending: true)
        .get();
  }

  void _onPeriodChanged(Set<SalesModalPeriod> newSelection) {
    setState(() {
      _selectedPeriod = newSelection.first;
      _dataFuture = _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return SizedBox(
      width: double.maxFinite,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          // FILTRO HORIZONTAL MODERNO
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<SalesModalPeriod>(
              segments: const [
                ButtonSegment(value: SalesModalPeriod.Day, label: Text('Hoje')),
                ButtonSegment(value: SalesModalPeriod.Week, label: Text('Semana')),
                ButtonSegment(value: SalesModalPeriod.Month, label: Text('Mês')),
              ],
              selected: {_selectedPeriod},
              onSelectionChanged: _onPeriodChanged,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return const Center(child: Text('Erro ao carregar vendas.'));

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: colorScheme.outline),
                      const SizedBox(height: 8),
                      const Text('Nenhuma venda neste período.'),
                    ],
                  );
                }

                double total = docs.fold(0, (sum, doc) => sum + ((doc.data() as Map)['totalAmount'] as num? ?? 0));

                return Column(
                  children: [
                    // CARD DE TOTAL
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total Vendido", style: TextStyle(color: colorScheme.onPrimaryContainer)),
                          Text(
                            currencyFormatter.format(total),
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // LISTA DE VENDAS
                    Expanded(
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final title = data['clientName']?.toString() ?? 'Cliente não inf.';
                          final amount = (data['totalAmount'] as num? ?? 0).toDouble();
                          final date = (data['saleDate'] as Timestamp).toDate();

                          return Card(
                            elevation: 0,
                            color: colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: colorScheme.secondaryContainer,
                                child: Icon(Icons.check, size: 16, color: colorScheme.onSecondaryContainer),
                              ),
                              title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              subtitle: Text(DateFormat('dd/MM HH:mm').format(date)),
                              trailing: Text(
                                currencyFormatter.format(amount),
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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

class _SalesCountBySalespersonModal extends StatefulWidget {
  final String institutionId;
  final List<UserModel> salespeople;
  const _SalesCountBySalespersonModal({required this.institutionId, required this.salespeople});
  @override
  State<_SalesCountBySalespersonModal> createState() => _SalesCountBySalespersonModalState();
}

class _SalesCountBySalespersonModalState extends State<_SalesCountBySalespersonModal> {
  SalesModalPeriod _selectedPeriod = SalesModalPeriod.Month;
  late Future<Map<String, int>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchData();
  }

  Future<Map<String, int>> _fetchData() async {
    final now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, 1);
    DateTime endDate = now;

    if (_selectedPeriod == SalesModalPeriod.Day) {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (_selectedPeriod == SalesModalPeriod.Week) {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    }

    final salesSnapshot = await FirebaseFirestore.instance
        .collection('institutions')
        .doc(widget.institutionId)
        .collection('sales')
        .where('saleDate', isGreaterThanOrEqualTo: startDate)
        .where('saleDate', isLessThanOrEqualTo: endDate)
        .get();

    final salesCount = <String, int>{};
    for (var doc in salesSnapshot.docs) {
      final data = doc.data();
      final userId = data['userId'] as String? ?? '';
      final salespersonName = widget.salespeople
          .firstWhere((s) => s.id == userId, orElse: () => UserModel(id: '', fullName: 'Desconhecido', email: '', institutionId: '', role: ''))
          .fullName;
      salesCount[salespersonName] = (salesCount[salespersonName] ?? 0) + 1;
    }
    return salesCount;
  }

  void _onPeriodChanged(Set<SalesModalPeriod> newSelection) {
    setState(() {
      _selectedPeriod = newSelection.first;
      _dataFuture = _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.maxFinite,
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<SalesModalPeriod>(
              segments: const [
                ButtonSegment(value: SalesModalPeriod.Day, label: Text('Hoje')),
                ButtonSegment(value: SalesModalPeriod.Week, label: Text('Semana')),
                ButtonSegment(value: SalesModalPeriod.Month, label: Text('Mês')),
              ],
              selected: {_selectedPeriod},
              onSelectionChanged: _onPeriodChanged,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<Map<String, int>>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Nenhuma venda encontrada.'));

                final data = snapshot.data!;
                final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final isTop = index == 0;

                    return Container(
                      decoration: BoxDecoration(
                        color: isTop ? colorScheme.primaryContainer.withOpacity(0.5) : colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isTop ? colorScheme.primary : colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isTop ? colorScheme.primary : colorScheme.surfaceVariant,
                          foregroundColor: isTop ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                          child: Text("${index + 1}º", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        title: Text(entry.key, style: TextStyle(fontWeight: isTop ? FontWeight.bold : FontWeight.normal)),
                        trailing: Text("${entry.value} vendas", style: const TextStyle(fontWeight: FontWeight.bold)),
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
