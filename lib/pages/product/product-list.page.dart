// lib/pages/products/products_list_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/enums/category-import-action.enum.dart';
// Adicione o import para o seu novo enum
// Boa prática: renomear arquivos com hífen para underscore (ex: product_category_model.dart)
import 'package:quadra_vendas/models/product-category.model.dart';
import 'package:quadra_vendas/models/product.model.dart';
import 'package:quadra_vendas/pages/product/add-edit-category.page.dart';
import 'package:quadra_vendas/pages/product/add-edit-product.page.dart';
import 'package:quadra_vendas/services/product-import.service.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';

class ProductsListPage extends StatefulWidget {
  const ProductsListPage({super.key});

  @override
  State<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends State<ProductsListPage> {
  String? _institutionId;

  @override
  void initState() {
    super.initState();
    _fetchInstitutionId();
  }

  Future<void> _fetchInstitutionId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if(mounted) setState(() => _institutionId = userDoc.data()?['institutionId']);
    }
  }

  /// =================================================================
  /// PASSO 1: CRIAR A FUNÇÃO QUE MOSTRA O DIÁLOGO DE CONFLITO
  /// =================================================================
  Future<CategoryImportAction?> _showCategoryConflictDialog(String categoryName) async {
    return await showDialog<CategoryImportAction>(
      context: context,
      barrierDismissible: false, // O utilizador deve escolher uma opção
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Categoria Duplicada'),
          content: Text('A categoria "$categoryName" já existe. O que deseja fazer?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar Importação'),
              onPressed: () {
                Navigator.of(context).pop(CategoryImportAction.cancel);
              },
            ),
            TextButton(
              child: const Text('Criar Nova Categoria'),
              onPressed: () {
                Navigator.of(context).pop(CategoryImportAction.createNew);
              },
            ),
            ElevatedButton(
              child: const Text('Substituir'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(context).pop(CategoryImportAction.overwrite);
              },
            ),
          ],
        );
      },
    );
  }


  /// =======================================================
  /// PASSO 2: ATUALIZAR A FUNÇÃO DE IMPORTAÇÃO
  /// =======================================================
  void _importFromExcel() async {
    if (_institutionId == null) return;

    AppSnackBar.showInfo(context, message: 'Processando arquivo...', duration: const Duration(seconds: 15));

    final service = ProductImportService(institutionId: _institutionId!);
    // A chamada ao serviço agora passa a nossa função de diálogo como um parâmetro
    final String? resultMessage = await service.importFromExcel(
      onConflict: _showCategoryConflictDialog,
    );

    if (mounted) {
      if (resultMessage == null) {
        // NULO significa que a importação foi um SUCESSO.
        AppSnackBar.showSuccess(context, message: 'Produtos importados com sucesso!');
      } else {
        // Se houver uma mensagem, ela é um ERRO ou AVISO. Exibimos a mensagem.
        AppSnackBar.showError(context, message: resultMessage, duration: const Duration(seconds: 8));
      }
    }
  }

  // --- O resto do seu código permanece exatamente o mesmo ---

  Future<void> _deleteCategoryAndProducts(ProductCategory category) async {
    if (_institutionId == null || category.id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir a categoria "${category.name}"? TODOS os produtos dentro dela também serão apagados permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    AppSnackBar.showInfo(context, message: 'Excluindo categoria e produtos...');

    try {
      final firestore = FirebaseFirestore.instance;
      final institutionRef = firestore.collection('institutions').doc(_institutionId);
      final WriteBatch batch = firestore.batch();

      final productsQuery = await institutionRef.collection('products').where('categoryId', isEqualTo: category.id).get();
      for (final doc in productsQuery.docs) {
        batch.delete(doc.reference);
      }

      final categoryRef = institutionRef.collection('productCategories').doc(category.id);
      batch.delete(categoryRef);

      await batch.commit();

      if (mounted) AppSnackBar.showSuccess(context, message: 'Categoria e produtos excluídos.');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: 'Erro ao excluir: $e');
    }
  }

  Future<void> _deleteProduct(Product product) async {
    if (_institutionId == null || product.id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir o produto "${product.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('institutions').doc(_institutionId)
          .collection('products').doc(product.id)
          .delete();

      if (mounted) AppSnackBar.showSuccess(context, message: 'Produto excluído com sucesso.');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: 'Erro ao excluir produto.');
    }
  }


  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos e Categorias'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Importar de Excel',
            onPressed: _importFromExcel,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_institutionId != null) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => AddEditCategoryPage(institutionId: _institutionId!)));
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Nova Categoria',
      ),
      body: _institutionId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('institutions').doc(_institutionId)
            .collection('productCategories').orderBy('name')
            .snapshots(),
        builder: (context, categorySnapshot) {
          if (categorySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!categorySnapshot.hasData || categorySnapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhuma categoria encontrada.'));
          }

          final categories = categorySnapshot.data!.docs
              .map((doc) => ProductCategory.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
              .toList();

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ExpansionTile(
                title: Row(
                  children: [
                    Expanded(child: Text(category.name, style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                      icon: Icon(Icons.edit_note, color: Theme.of(context).colorScheme.secondary),
                      tooltip: 'Editar Categoria',
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => AddEditCategoryPage(institutionId: _institutionId!, category: category)));
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
                      tooltip: 'Excluir Categoria e Produtos',
                      onPressed: () => _deleteCategoryAndProducts(category),
                    ),
                  ],
                ),
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('institutions').doc(_institutionId)
                        .collection('products')
                        .where('categoryId', isEqualTo: category.id)
                        .snapshots(),
                    builder: (context, productSnapshot) {
                      if (productSnapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(8.0), child: Center(child: CircularProgressIndicator()));
                      if (!productSnapshot.hasData || productSnapshot.data!.docs.isEmpty) return const Padding(padding: EdgeInsets.all(16.0), child: Text('Nenhum produto nesta categoria.'));

                      final products = productSnapshot.data!.docs
                          .map((doc) => Product.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
                          .toList();

                      return Column(
                        children: products.map((product) => ListTile(
                          title: Text(product.name),
                          subtitle: Text(
                              'Custo: ${product.costPrice != null ? currencyFormatter.format(product.costPrice) : '-'} | Venda: ${currencyFormatter.format(product.salePrice)}'
                          ),                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Editar Produto',
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => AddEditProductPage(
                                    institutionId: _institutionId!,
                                    category: category,
                                    product: product,
                                  )));
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error.withOpacity(0.7)),
                                tooltip: 'Excluir Produto',
                                onPressed: () => _deleteProduct(product),
                              ),
                            ],
                          ),
                        )).toList(),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Adicionar Produto'),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => AddEditProductPage(
                            institutionId: _institutionId!,
                            category: category,
                          )));
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}