// lib/pages/product/add-edit-product.page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quadra_vendas/models/product-category.model.dart';
import 'package:quadra_vendas/models/product.model.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';

class AddEditProductPage extends StatefulWidget {
  final String institutionId;
  final ProductCategory category;
  final Product? product;

  const AddEditProductPage({
    super.key,
    required this.institutionId,
    required this.category,
    this.product,
  });

  @override
  State<AddEditProductPage> createState() => _AddEditProductPageState();
}

class _AddEditProductPageState extends State<AddEditProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _salePriceCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameCtrl.text = widget.product!.name;
      _costPriceCtrl.text = widget.product!.costPrice?.toStringAsFixed(2).replaceAll('.', ',') ?? '';
      _salePriceCtrl.text = widget.product!.salePrice.toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _costPriceCtrl.dispose();
    _salePriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) AppSnackBar.showError(context, message: 'Utilizador não autenticado.');
      setState(() => _isLoading = false);
      return;
    }

    final productData = {
      'name': _nameCtrl.text.trim(),
      'costPrice': double.tryParse(_costPriceCtrl.text.trim().replaceAll(',', '.')),
      'salePrice': double.parse(_salePriceCtrl.text.trim().replaceAll(',', '.')),
      'categoryId': widget.category.id,
      'categoryName': widget.category.name,
      // Se for um novo produto, guarda o ID do criador. Se for uma edição, mantém o criador original.
      'createdBy': widget.product?.createdBy ?? currentUser.uid,
      // Manter os campos otherPrices e margin nulos se não forem usados nesta tela, para consistência.
      'otherPrices': widget.product?.otherPrices,
      'margin': widget.product?.margin,
    };

    try {
      final collectionRef = FirebaseFirestore.instance
          .collection('institutions').doc(widget.institutionId)
          .collection('products');

      if (widget.product == null) {
        await collectionRef.add(productData);
      } else {
        await collectionRef.doc(widget.product!.id).update(productData);
      }

      if (mounted) {
        AppSnackBar.showSuccess(context, message: 'Produto salvo com sucesso!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: 'Erro ao salvar produto: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Novo Produto' : 'Editar Produto'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Categoria: ${widget.category.name}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nome do Produto'), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _costPriceCtrl, decoration: const InputDecoration(labelText: 'Preço de Custo (Opcional)', prefixText: 'R\$ '), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 16),
              TextFormField(controller: _salePriceCtrl, decoration: const InputDecoration(labelText: 'Preço de Venda', prefixText: 'R\$ '), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)) : const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}