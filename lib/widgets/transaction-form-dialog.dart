import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/models/transaction.model.dart';

class TransactionFormDialog extends StatefulWidget {
  final String instId;
  final FinTransaction? transaction;

  const TransactionFormDialog({super.key, required this.instId, this.transaction});

  @override
  State<TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends State<TransactionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  String _type = 'expense';
  DateTime _dueDate = DateTime.now();
  bool _isPaid = false;
  bool _isLoading = false;
  String _category = 'Geral';

  // --- NOVOS CAMPOS PARA RECORRÊNCIA ---
  bool _isRecurring = false;
  int _installments = 2; // Começa sugerindo 2 meses

  final List<String> _categories = [
    'Geral', 'Vendas', 'Serviços', 'Aluguel', 'Fornecedores',
    'Salários', 'Impostos', 'Marketing', 'Manutenção', 'Outros'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      final t = widget.transaction!;
      _descController.text = t.description;
      _amountController.text = t.amount.toStringAsFixed(2).replaceAll('.', ',');
      _type = t.type;
      _dueDate = t.dueDate;
      _isPaid = t.status == 'paid';
      if (!_categories.contains(t.category)) {
        _categories.add(t.category);
      }
      _category = t.category;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      double amount = double.tryParse(_amountController.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

      final batch = FirebaseFirestore.instance.batch();
      final collectionRef = FirebaseFirestore.instance
          .collection('institutions')
          .doc(widget.instId)
          .collection('financial_transactions');

      // Lógica: Se for edição, salva apenas 1. Se for novo e tiver recorrência, faz loop.
      int loopCount = (widget.transaction == null && _isRecurring) ? _installments : 1;

      for (int i = 0; i < loopCount; i++) {
        // Calcula a data para este mês específico
        // O DateTime lida bem com overflow (ex: 31 de jan + 1 mes = final de fev)
        DateTime currentDueDate = DateTime(_dueDate.year, _dueDate.month + i, _dueDate.day);

        String description = _descController.text.trim();
        if (loopCount > 1) {
          description = '$description (${i + 1}/$loopCount)';
        }

        final data = {
          'institutionId': widget.instId,
          'description': description,
          'amount': amount, // Assume que o valor digitado é o valor DA PARCELA
          'type': _type,
          'status': (i == 0 && _isPaid) ? 'paid' : 'pending', // Só marca o primeiro como pago se selecionado
          'dueDate': Timestamp.fromDate(currentDueDate),
          'paidAt': (i == 0 && _isPaid) ? Timestamp.now() : null,
          'category': _category,
          'createdAt': FieldValue.serverTimestamp(),
        };

        if (widget.transaction == null) {
          // Cria novo ID para cada parcela
          final docRef = collectionRef.doc();
          batch.set(docRef, data);
        } else {
          // Atualiza existente (sem loop, loopCount será 1)
          batch.update(collectionRef.doc(widget.transaction!.id), data);
        }
      }

      await batch.commit();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    // ... (Mantenha seu código de delete anterior aqui) ...
    // Se quiser, posso repostar o delete, mas é o mesmo da versão anterior
    final confirm = await showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Excluir Lançamento?'),
      content: const Text('Essa ação não pode ser desfeita.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('institutions').doc(widget.instId).collection('financial_transactions').doc(widget.transaction!.id).delete();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.transaction != null;
    final primaryColor = Theme.of(context).primaryColor;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 24),
      title: Text(isEditing ? 'Editar Lançamento' : 'Novo Lançamento'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ... (Mantenha os botões de Tipo, Descrição, Categoria e Valor iguais ao anterior) ...
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _type = 'expense'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _type == 'expense' ? Colors.red.shade100 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _type == 'expense' ? Colors.red : Colors.transparent),
                        ),
                        child: Column(children: [
                          Icon(Icons.arrow_downward, color: _type == 'expense' ? Colors.red : Colors.grey),
                          Text('Saída', style: TextStyle(color: _type == 'expense' ? Colors.red : Colors.grey, fontWeight: FontWeight.bold))
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _type = 'income'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _type == 'income' ? Colors.green.shade100 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _type == 'income' ? Colors.green : Colors.transparent),
                        ),
                        child: Column(children: [
                          Icon(Icons.arrow_upward, color: _type == 'income' ? Colors.green : Colors.grey),
                          Text('Entrada', style: TextStyle(color: _type == 'income' ? Colors.green : Colors.grey, fontWeight: FontWeight.bold))
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Informe a descrição' : null,
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Valor da Parcela (R\$)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v!.isEmpty ? 'Informe o valor' : null,
              ),
              const SizedBox(height: 10),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vencimento (1ª Parcela)'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_dueDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setState(() => _dueDate = d);
                },
              ),

              // --- CAMPO NOVO: RECORRÊNCIA (Aparece só na criação) ---
              if (!isEditing)
                Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Repetir lançamento?'),
                      subtitle: const Text('Ex: Parcelamento ou Assinatura mensal'),
                      value: _isRecurring,
                      onChanged: (v) => setState(() => _isRecurring = v),
                    ),
                    if (_isRecurring)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            const Text("Repetir por: "),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _installments,
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0), border: OutlineInputBorder()),
                                items: [2, 3, 4, 5, 6, 9, 10, 12, 18, 24, 36, 48].map((e) => DropdownMenuItem(value: e, child: Text('$e meses'))).toList(),
                                onChanged: (v) => setState(() => _installments = v!),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_isPaid ? '✅ Pago/Recebido (1ª Parc.)' : '⏳ Pendente'),
                value: _isPaid,
                activeColor: Colors.green,
                onChanged: (v) => setState(() => _isPaid = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (isEditing) TextButton(onPressed: _delete, child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
            onPressed: _isLoading ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Salvar')
        ),
      ],
    );
  }
}