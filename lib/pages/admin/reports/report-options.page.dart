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
  String? _selectedSalespersonId;
  bool _isLoading = true;

  int? _selectedMonth;
  int? _selectedYear;
  final List<String> _months = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];
  final List<int> _years = List<int>.generate(5, (index) => DateTime.now().year - index);

  // NOVO ESTADO E OPÇÕES PARA TIPO DE RELATÓRIO
  String _selectedReportType = 'complete';
  final Map<String, String> _reportTypes = {
    'complete': 'Relatório Completo',
    'sales_only': 'Relatório de Vendas',
    'clients_only': 'Relatório de Clientes',
  };

  @override
  void initState() {
    super.initState();
    _fetchSalespeople();
    _selectedMonth = DateTime.now().month;
    _selectedYear = DateTime.now().year;
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
    if (_selectedSalespersonId == null || _selectedMonth == null || _selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione todas as opções.'), backgroundColor: Colors.red),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportViewPage(
          institutionId: widget.institutionId,
          salespersonId: _selectedSalespersonId!,
          selectedMonth: _selectedMonth!,
          selectedYear: _selectedYear!,
          // ENVIAR TIPO DE RELATÓRIO PARA A PRÓXIMA TELA
          reportType: _selectedReportType,
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
            // NOVO SELETOR DE TIPO DE RELATÓRIO
            DropdownButtonFormField<String>(
              value: _selectedReportType,
              hint: const Text('Tipo de Relatório'),
              isExpanded: true,
              items: _reportTypes.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedReportType = value!;
                });
              },
              decoration: const InputDecoration(
                  labelText: 'Tipo de Relatório',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // SELETOR DE VENDEDOR
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
              decoration: const InputDecoration(
                  labelText: 'Vendedor',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // SELETORES DE MÊS E ANO
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    hint: const Text('Mês'),
                    items: List.generate(12, (index) {
                      return DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text(_months[index]),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        _selectedMonth = value;
                      });
                    },
                    decoration: const InputDecoration(
                        labelText: 'Mês',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    hint: const Text('Ano'),
                    items: _years.map((year) {
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedYear = value;
                      });
                    },
                    decoration: const InputDecoration(
                        labelText: 'Ano',
                        border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16)
              ),
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