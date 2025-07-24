// lib/pages/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quadra_vendas/providers/theme.provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SaleMode { cart, direct }

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SaleMode _selectedSaleMode = SaleMode.cart;

  @override
  void initState() {
    _loadSaleMode();
    super.initState();
  }

  Future<void> _loadSaleMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('saleMode') ?? 'cart';
    setState(() {
      _selectedSaleMode = mode == 'direct' ? SaleMode.direct : SaleMode.cart;
    });
  }

  Future<void> _setSaleMode(SaleMode? mode) async {
    if (mode == null) return;

    setState(() {
      _selectedSaleMode = mode;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saleMode', mode == SaleMode.direct ? 'direct' : 'cart');
  }

  @override
  Widget build(BuildContext context) {
    // Acede ao nosso ThemeProvider para ler e alterar o tema
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Aparência',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Tema Claro'),
            value: ThemeMode.light,
            groupValue: themeProvider.themeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                themeProvider.setThemeMode(value);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Tema Escuro'),
            value: ThemeMode.dark,
            groupValue: themeProvider.themeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                themeProvider.setThemeMode(value);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Seguir o Sistema'),
            subtitle: const Text('O tema da aplicação irá corresponder ao do seu telemóvel.'),
            value: ThemeMode.system,
            groupValue: themeProvider.themeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                themeProvider.setThemeMode(value);
              }
            },
          ),
          const Divider(),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Modo de Venda',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          RadioListTile<SaleMode>(
            title: const Text('Modo Carrinho'),
            subtitle: const Text('Adicione produtos a um carrinho antes de finalizar.'),
            value: SaleMode.cart,
            groupValue: _selectedSaleMode,
            onChanged: _setSaleMode,
          ),
          RadioListTile<SaleMode>(
            title: const Text('Modo Venda Direta'),
            subtitle: const Text('Liste todos os produtos e adicione as quantidades diretamente.'),
            value: SaleMode.direct,
            groupValue: _selectedSaleMode,
            onChanged: _setSaleMode,
          ),
        ],
      ),
    );
  }
}
