// lib/pages/admin/set_goal_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/models/goal.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';
import 'package:quadra_vendas/widgets/elevated-button.widget.dart';

class SetGoalPage extends StatefulWidget {
  final String institutionId;
  final UserModel salesperson;

  const SetGoalPage({
    super.key,
    required this.institutionId,
    required this.salesperson,
  });

  @override
  State<SetGoalPage> createState() => _SetGoalPageState();
}

class _SetGoalPageState extends State<SetGoalPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  SalesGoal? _existingGoal;

  @override
  void initState() {
    super.initState();
    _fetchExistingGoal();
  }

  /// Busca se já existe uma meta para o mês e vendedor selecionados.
  Future<void> _fetchExistingGoal() async {
    // É seguro chamar setState aqui porque nenhuma operação assíncrona ocorreu ainda.
    setState(() => _isLoading = true);

    final collectionRef = FirebaseFirestore.instance
        .collection('institutions')
        .doc(widget.institutionId)
        .collection('goals');

    final query = await collectionRef
        .where('salespersonId', isEqualTo: widget.salesperson.id)
        .where('month', isEqualTo: _selectedDate.month)
        .where('year', isEqualTo: _selectedDate.year)
        .limit(1)
        .get();

    // +++ VERIFICAÇÃO ADICIONADA +++
    // Após o 'await', precisamos verificar se o widget ainda está na árvore.
    if (!mounted) return;

    if (query.docs.isNotEmpty) {
      _existingGoal = SalesGoal.fromFirestore(query.docs.first);
      _amountController.text = _existingGoal!.amount.toStringAsFixed(2);
    } else {
      _existingGoal = null;
      _amountController.clear();
    }
    setState(() => _isLoading = false);
  }

  /// Abre o seletor de mês/ano.
  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && (picked.month != _selectedDate.month || picked.year != _selectedDate.year)) {
      // É seguro chamar setState aqui porque o estado está contido na própria função.
      setState(() {
        _selectedDate = picked;
      });
      _fetchExistingGoal(); // Busca a meta para a nova data
    }
  }

  /// Salva a meta no banco de dados.
  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;

    final goalToSave = SalesGoal(
      id: _existingGoal?.id,
      salespersonId: widget.salesperson.id,
      salespersonName: widget.salesperson.fullName,
      month: _selectedDate.month,
      year: _selectedDate.year,
      amount: amount,
    );

    try {
      final collectionRef = FirebaseFirestore.instance
          .collection('institutions').doc(widget.institutionId)
          .collection('goals');

      if(goalToSave.id != null) {
        await collectionRef.doc(goalToSave.id).update(goalToSave.toFirestore());
      } else {
        await collectionRef.add(goalToSave.toFirestore());
      }

      // +++ VERIFICAÇÃO ADICIONADA +++
      if(mounted){
        AppSnackBar.showSuccess(context, message: 'Meta salva com sucesso!');
        Navigator.pop(context);
      }

    } catch (e) {
      // +++ VERIFICAÇÃO ADICIONADA +++
      if (mounted) AppSnackBar.showError(context, message: 'Erro ao salvar a meta.');
    } finally {
      // +++ VERIFICAÇÃO ADICIONADA +++
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthYearFormat = DateFormat('MMMM \'de\' yyyy', 'pt_BR');

    return Scaffold(
      appBar: AppBar(title: Text('Meta para ${widget.salesperson.fullName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Defina a meta de vendas para:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              ActionChip(
                onPressed: () => _selectMonth(context),
                avatar: const Icon(Icons.calendar_today),
                label: Text(
                  monthYearFormat.format(_selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Valor da Meta Mensal',
                  prefixText: 'R\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Campo obrigatório';
                  if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Valor inválido';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ShadowButton(
                text: "Salvar Meta",
                onPressed: _saveGoal,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}