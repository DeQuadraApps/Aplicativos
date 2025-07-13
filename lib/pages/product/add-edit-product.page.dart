// lib/pages/products/add_edit_product_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quadra_vendas/models/product-category.model.dart';
import 'package:quadra_vendas/models/product.model.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';

class AddEditProductPage extends StatefulWidget {
  final String institutionId;
  final ProductCategory category; // Categoria à qual o produto pertence
  final Product? product; // Se for nulo, é "Adicionar". Senão, é "Editar".

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
      _costPriceCtrl.text = widget.product!.costPrice?.toString() ?? '';
      _salePriceCtrl.text = widget.product!.salePrice.toString();
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final productData = {
      'name': _nameCtrl.text.trim(),
      'costPrice': double.tryParse(_costPriceCtrl.text),
      'salePrice': double.parse(_salePriceCtrl.text),
      'categoryId': widget.category.id, // Vínculo com a categoria!
      'categoryName': widget.category.name, // Denormalizado para facilitar
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
        AppSnackBar.showError(context, message: 'Erro ao salvar produto.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.product == null ? 'Novo Produto' : 'Editar Produto'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(30),
            child: Text(
              'Categoria: ${widget.category.name}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
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
                TextFormField(controller: _costPriceCtrl, decoration: const InputDecoration(labelText: 'Preço de Custo (Opcional)'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _salePriceCtrl, decoration: const InputDecoration(labelText: 'Preço de Venda'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saveProduct,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}