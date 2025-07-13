// lib/pages/products/add_edit_category_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quadra_vendas/models/product-category.model.dart'; // Verifique o nome do seu import
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';

class AddEditCategoryPage extends StatefulWidget {
  final String institutionId;
  final ProductCategory? category; // Se for nulo, é "Adicionar". Senão, é "Editar".

  const AddEditCategoryPage({super.key, required this.institutionId, this.category});

  @override
  State<AddEditCategoryPage> createState() => _AddEditCategoryPageState();
}

class _AddEditCategoryPageState extends State<AddEditCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
    }
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final categoryData = {'name': _nameController.text.trim()};

    try {
      final collectionRef = FirebaseFirestore.instance
          .collection('institutions').doc(widget.institutionId)
          .collection('productCategories');

      if (widget.category == null) { // Adicionar nova
        await collectionRef.add(categoryData);
      } else { // Editar existente
        await collectionRef.doc(widget.category!.id).update(categoryData);
      }

      if (mounted) {
        AppSnackBar.showSuccess(context, message: 'Categoria salva com sucesso!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: 'Erro ao salvar categoria.');
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
          title: Text(widget.category == null ? 'Nova Categoria' : 'Editar Categoria'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nome da Categoria'),
                  validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 32),
                ElevatedButton( // Usando ElevatedButton como alternativa ao ShadowButton
                  onPressed: _saveCategory,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Salvar'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}