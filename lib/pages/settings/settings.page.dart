// lib/pages/settings/settings_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:quadra_vendas/providers/theme.provider.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SaleMode { cart, direct }

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final User? _user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  bool _isAdmin = false;

  // Estado Local
  SaleMode _selectedSaleMode = SaleMode.cart;
  String _appVersion = '';

  // Dados do Firestore
  String? _institutionId;
  final TextEditingController _companyNameController = TextEditingController();
  String _currentPlan = '';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    // 1. Carrega Preferências (Modo de Venda)
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString('saleMode') ?? 'cart';

    // 2. Carrega Versão do App
    final packageInfo = await PackageInfo.fromPlatform();

    // 3. Carrega Dados do Firestore (Instituição)
    if (_user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user.uid).get();
        _isAdmin = userDoc.data()?['role'] == 'admin';
        final instId = userDoc.data()?['institutionId'];

        if (instId != null) {
          final instDoc = await FirebaseFirestore.instance.collection('institutions').doc(instId).get();
          final data = instDoc.data();

          if (mounted) {
            setState(() {
              _institutionId = instId;
              _companyNameController.text = data?['name'] ?? '';
              _currentPlan = (data?['plan'] ?? 'start').toString().toLowerCase();
            });
          }
        }
      } catch (e) {
        debugPrint('Erro ao carregar dados da empresa: $e');
      }
    }

    if (mounted) {
      setState(() {
        _selectedSaleMode = modeString == 'direct' ? SaleMode.direct : SaleMode.cart;
        _appVersion = packageInfo.version;
        _isLoading = false;
      });
    }
  }

  Future<void> _setSaleMode(SaleMode? mode) async {
    if (mode == null) return;
    setState(() => _selectedSaleMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saleMode', mode == SaleMode.direct ? 'direct' : 'cart');
  }

  Future<void> _updateCompanyName() async {
    if (_institutionId == null) return;
    if (_companyNameController.text.trim().isEmpty) {
      AppSnackBar.showError(context, message: 'O nome da empresa não pode ficar vazio.');
      return;
    }

    FocusScope.of(context).unfocus(); // Fecha teclado

    try {
      await FirebaseFirestore.instance
          .collection('institutions')
          .doc(_institutionId)
          .update({'name': _companyNameController.text.trim()});

      if (mounted) AppSnackBar.showSuccess(context, message: 'Nome da empresa atualizado!');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: 'Erro ao salvar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configurações')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          // --- SEÇÃO 1: APARÊNCIA ---
          _buildSectionHeader(context, 'Aparência'),
          RadioListTile<ThemeMode>(
            title: const Text('Tema Claro'),
            secondary: const Icon(Icons.light_mode_outlined),
            value: ThemeMode.light,
            groupValue: themeProvider.themeMode,
            onChanged: (val) => val != null ? themeProvider.setThemeMode(val) : null,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Tema Escuro'),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: ThemeMode.dark,
            groupValue: themeProvider.themeMode,
            onChanged: (val) => val != null ? themeProvider.setThemeMode(val) : null,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Seguir o Sistema'),
            secondary: const Icon(Icons.settings_system_daydream_outlined),
            subtitle: const Text('O tema segue a configuração do telemóvel.'),
            value: ThemeMode.system,
            groupValue: themeProvider.themeMode,
            onChanged: (val) => val != null ? themeProvider.setThemeMode(val) : null,
          ),
          const Divider(),

          // --- SEÇÃO 2: PREFERÊNCIAS DE VENDA ---
          _buildSectionHeader(context, 'Modo de Venda'),
          RadioListTile<SaleMode>(
            title: const Text('Modo Carrinho'),
            subtitle: const Text('Adicione vários itens antes de finalizar.'),
            value: SaleMode.cart,
            groupValue: _selectedSaleMode,
            onChanged: _setSaleMode,
          ),
          RadioListTile<SaleMode>(
            title: const Text('Modo Venda Direta'),
            subtitle: const Text('Venda rápida de 1 item (Ideal para serviços).'),
            value: SaleMode.direct,
            groupValue: _selectedSaleMode,
            onChanged: _setSaleMode,
          ),
          const Divider(),

          if (_isAdmin) ...[
            _buildSectionHeader(context, 'Dados da Empresa'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _companyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome Fantasia',
                        border: OutlineInputBorder(),
                        helperText: 'Aparecerá nos PDFs e na Home.',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    icon: const Icon(Icons.save),
                    onPressed: _updateCompanyName,
                    tooltip: 'Salvar Nome',
                  )
                ],
              ),
            ),
            ListTile(
              title: const Text('Plano Atual'),
              subtitle: Text(_currentPlan.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
              trailing: _currentPlan == 'elite'
                  ? Icon(Icons.verified, color: Colors.amber.shade700)
                  : OutlinedButton(
                onPressed: () => AppSnackBar.showInfo(context, message: 'Contate o suporte para upgrade.'),
                child: const Text('Upgrade'),
              ),
            ),
            const Divider(),
          ],

          // --- SEÇÃO 4: SOBRE ---
          _buildSectionHeader(context, 'Sobre'),
          ListTile(
            leading: Icon(Icons.info_outline, color: colorScheme.primary),
            title: const Text('Versão do App'),
            trailing: Text(_appVersion),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              icon: Icon(Icons.logout, color: colorScheme.error),
              label: Text('Sair da Conta', style: TextStyle(color: colorScheme.error)),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}