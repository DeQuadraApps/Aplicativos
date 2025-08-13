// lib/pages/admin/report_options_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/pages/admin/reports/report-view.page.dart';

class ReportOptionsPage extends StatefulWidget {
  final String institutionId;

  const ReportOptionsPage({super.key, required this.institutionId});

  @override
  State<ReportOptionsPage> createState() => _ReportOptionsPageState();
}

class _ReportOptionsPageState extends State<ReportOptionsPage> {
  List<UserModel> _salespeople = [];
  String? _selectedSalespersonId; // Pode ser 'all' ou o ID de um vendedor
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSalespeople();
  }

  Future<void> _fetchSalespeople() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('institutionId', isEqualTo: widget.institutionId)
        .where('role', isEqualTo: 'employee')
        .get();

    if (mounted) {
      setState(() {
        _salespeople = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
        _isLoading = false;
      });
    }
  }

  void _generateReport() {
    if (_selectedSalespersonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma opção.'), backgroundColor: Colors.red),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportViewPage(
          institutionId: widget.institutionId,
          salespersonId: _selectedSalespersonId!, // 'all' ou um ID específico
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emitir Relatório')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedSalespersonId,
              hint: const Text('Selecione o Vendedor'),
              isExpanded: true,
              items: [
                const DropdownMenuItem<String>(
                  value: 'all',
                  child: Text('Todos os Vendedores'),
                ),
                ..._salespeople.map((user) {
                  return DropdownMenuItem<String>(
                    value: user.id,
                    child: Text(user.fullName),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedSalespersonId = value;
                });
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            // Futuramente, pode adicionar um seletor de data aqui
            ElevatedButton.icon(
              onPressed: _generateReport,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Gerar Relatório'),
            ),
          ],
        ),
      ),
    );
  }
}