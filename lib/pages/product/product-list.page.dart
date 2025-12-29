// lib/pages/products/products_list_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/enums/category-import-action.enum.dart';
import 'package:quadra_vendas/enums/plan-type.dart';
import 'package:quadra_vendas/models/product-category.model.dart';
import 'package:quadra_vendas/models/product.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/pages/product/add-edit-category.page.dart';
import 'package:quadra_vendas/pages/product/add-edit-product.page.dart';
import 'package:quadra_vendas/services/catalog_pdf.service.dart';
import 'package:quadra_vendas/services/product-import.service.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';

class ProductsListPage extends StatefulWidget {
  const ProductsListPage({super.key});

  @override
  State<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends State<ProductsListPage> {
  String? _institutionId;
  String _institutionName = "Minha Empresa";
  UserModel? _currentUserData;
  List<ProductCategory> _categories = [];
  bool _isGeneratingCatalog = false;
  bool isStartPlan = true;
  PlanType _activePlan = PlanType.start;

  @override
  initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final instId = userDoc.data()?['institutionId'];

      if (instId != null) {
        final instDoc =
            await FirebaseFirestore.instance
                .collection('institutions')
                .doc(instId)
                .get();
        if (mounted) {
          setState(() {
            _institutionId = instId;
            final data = instDoc.data();
            _institutionName = data?['name'] ?? "Minha Empresa";

            _activePlan = PlanType.fromString(data?['plan']);
            isStartPlan = _activePlan == PlanType.start;

            _currentUserData = UserModel.fromFirestore(userDoc);
          });
        }
      }
    }
  }

  Future<void> _generateCatalog() async {
    // ✨ 1. BLOQUEIO DE PLANO
    if (isStartPlan) {
      showDialog(
        context: context,
        builder:
            (c) => AlertDialog(
              title: const Text("Funcionalidade Premium"),
              content: const Text(
                "O Catálogo em PDF está disponível apenas nos planos Control e Elite.\n\nFaça um upgrade para enviar catálogos profissionais aos seus clientes!",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text("Entendi"),
                ),
              ],
            ),
      );
      return; // Para a execução aqui
    }

    if (_institutionId == null || _categories.isEmpty) {
      AppSnackBar.showError(
        context,
        message: 'Não há categorias/produtos para gerar.',
      );
      return;
    }

    setState(() => _isGeneratingCatalog = true);
    AppSnackBar.showInfo(context, message: 'Preparando catálogo PDF...');

    try {
      final allProductsSnapshot =
          await FirebaseFirestore.instance
              .collection('institutions')
              .doc(_institutionId)
              .collection('products')
              .orderBy('name')
              .get();

      final allProducts =
          allProductsSnapshot.docs
              .map((d) => Product.fromFirestore(d))
              .toList();
      final Map<String, List<Product>> productsMap = {};

      for (var cat in _categories) {
        final catProducts =
            allProducts.where((p) => p.categoryId == cat.id).toList();
        if (catProducts.isNotEmpty) {
          productsMap[cat.id!] = catProducts;
        }
      }

      if (productsMap.isEmpty) {
        if (mounted)
          AppSnackBar.showError(
            context,
            message: 'Nenhum produto cadastrado para exibir.',
          );
        return;
      }

      final service = CatalogPdfService(
        institutionName: _institutionName,
        categories: _categories,
        productsMap: productsMap,
      );

      await service.generateAndPrint();
    } catch (e) {
      if (mounted)
        AppSnackBar.showError(context, message: 'Erro ao gerar catálogo: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingCatalog = false);
    }
  }

  // ... (Mantenha _showCategoryPickerForSalesperson, _importFromExcel, _deleteCategoryAndProducts, _deleteProduct, _showCategoryConflictDialog iguais ao anterior) ...
  // Para economizar espaço, não vou repetir esses métodos pois eles não mudaram.
  // Apenas certifique-se de que eles estão presentes no seu arquivo final.

  Future<void> _showCategoryPickerForSalesperson() async {
    if (_categories.isEmpty) {
      AppSnackBar.showError(context, message: 'Nenhuma categoria disponível.');
      return;
    }
    final ProductCategory? selectedCategory = await showDialog<ProductCategory>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Selecione uma Categoria'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_categories[index].name),
                  onTap: () => Navigator.of(context).pop(_categories[index]),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
    if (selectedCategory != null && mounted)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => AddEditProductPage(
                institutionId: _institutionId!,
                category: selectedCategory,
              ),
        ),
      );
  }

  void _importFromExcel() async {
    if (_institutionId == null ||
        _currentUserData == null ||
        _currentUserData!.role != 'admin') {
      AppSnackBar.showError(
        context,
        message: 'Apenas administradores podem importar produtos.',
      );
      return;
    }
    AppSnackBar.showInfo(
      context,
      message: 'Processando arquivo...',
      duration: const Duration(seconds: 15),
    );
    final service = ProductImportService(institutionId: _institutionId!);
    final String? resultMessage = await service.importFromExcel(
      onConflict: _showCategoryConflictDialog,
      adminId: _currentUserData!.id,
    );
    if (mounted) {
      if (resultMessage == null) {
        AppSnackBar.showSuccess(
          context,
          message: 'Produtos importados com sucesso!',
        );
      } else {
        AppSnackBar.showError(
          context,
          message: resultMessage,
          duration: const Duration(seconds: 8),
        );
      }
    }
  }

  Future<void> _deleteCategoryAndProducts(ProductCategory category) async {
    if (_institutionId == null || category.id == null) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar Exclusão'),
            content: Text(
              'Tem certeza que deseja excluir a categoria "${category.name}"? TODOS os produtos dentro dela também serão apagados permanentemente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Excluir',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    AppSnackBar.showInfo(context, message: 'Excluindo categoria e produtos...');
    try {
      final firestore = FirebaseFirestore.instance;
      final institutionRef = firestore
          .collection('institutions')
          .doc(_institutionId);
      final WriteBatch batch = firestore.batch();
      final productsQuery =
          await institutionRef
              .collection('products')
              .where('categoryId', isEqualTo: category.id)
              .get();
      for (final doc in productsQuery.docs) {
        batch.delete(doc.reference);
      }
      final categoryRef = institutionRef
          .collection('productCategories')
          .doc(category.id);
      batch.delete(categoryRef);
      await batch.commit();
      if (mounted)
        AppSnackBar.showSuccess(
          context,
          message: 'Categoria e produtos excluídos.',
        );
    } catch (e) {
      if (mounted)
        AppSnackBar.showError(context, message: 'Erro ao excluir: $e');
    }
  }

  Future<void> _deleteProduct(Product product) async {
    if (_institutionId == null || product.id == null) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar Exclusão'),
            content: Text(
              'Tem certeza que deseja excluir o produto "${product.name}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Excluir',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('institutions')
          .doc(_institutionId)
          .collection('products')
          .doc(product.id)
          .delete();
      if (mounted)
        AppSnackBar.showSuccess(
          context,
          message: 'Produto excluído com sucesso.',
        );
    } catch (e) {
      if (mounted)
        AppSnackBar.showError(context, message: 'Erro ao excluir produto.');
    }
  }

  Future<CategoryImportAction?> _showCategoryConflictDialog(
    String categoryName,
  ) async {
    return await showDialog<CategoryImportAction>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Categoria Duplicada'),
          content: Text(
            'A categoria "$categoryName" já existe. O que deseja fazer?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar Importação'),
              onPressed:
                  () => Navigator.of(context).pop(CategoryImportAction.cancel),
            ),
            TextButton(
              child: const Text('Criar Nova Categoria'),
              onPressed:
                  () =>
                      Navigator.of(context).pop(CategoryImportAction.createNew),
            ),
            ElevatedButton(
              child: const Text('Substituir'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed:
                  () =>
                      Navigator.of(context).pop(CategoryImportAction.overwrite),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );
    final bool isAdmin = _currentUserData?.role == 'admin';
    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Produtos da Instituição' : 'Todos os Produtos'),
        actions: [
          if (_institutionId != null)
            IconButton(
              // ✨ Ícone muda se for plano start (Locked ou Cinza)
              icon:
                  _isGeneratingCatalog
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Icon(
                        isStartPlan ? Icons.lock_outline : Icons.picture_as_pdf,
                        color: isStartPlan ? Colors.grey : null,
                      ),
              tooltip:
                  isStartPlan ? 'Disponível no Premium' : 'Gerar Catálogo PDF',
              onPressed:
                  _isGeneratingCatalog
                      ? null
                      : _generateCatalog, // A verificação do plano está dentro da função
            ),

          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Importar de Excel',
              onPressed: _importFromExcel,
            ),
        ],
      ),
      floatingActionButton:
          isAdmin
              ? FloatingActionButton(
                onPressed: () {
                  if (_institutionId == null) return;
                  if (isAdmin) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => AddEditCategoryPage(
                              institutionId: _institutionId!,
                            ),
                      ),
                    );
                  } else {
                    _showCategoryPickerForSalesperson();
                  }
                },
                child: const Icon(Icons.add),
                tooltip: 'Nova Categoria',
              )
              : null,
      body:
          _currentUserData == null
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('institutions')
                        .doc(_institutionId)
                        .collection('productCategories')
                        .orderBy('name')
                        .snapshots(),
                builder: (context, categorySnapshot) {
                  if (categorySnapshot.hasError)
                    return Center(
                      child: Text(
                        "Erro ao carregar categorias: ${categorySnapshot.error}",
                      ),
                    );
                  if (categorySnapshot.connectionState ==
                      ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (!categorySnapshot.hasData ||
                      categorySnapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          isAdmin
                              ? 'Nenhuma categoria encontrada. Clique no botão "+" para criar a sua primeira categoria.'
                              : 'Nenhuma categoria foi criada pela instituição ainda.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  _categories =
                      categorySnapshot.data!.docs
                          .map(
                            (doc) => ProductCategory.fromFirestore(
                              doc as DocumentSnapshot<Map<String, dynamic>>,
                            ),
                          )
                          .toList();

                  return ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return ExpansionTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                category.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (isAdmin) ...[
                              IconButton(
                                icon: Icon(
                                  Icons.edit_note,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                                onPressed:
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => AddEditCategoryPage(
                                              institutionId: _institutionId!,
                                              category: category,
                                            ),
                                      ),
                                    ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_forever,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                onPressed:
                                    () => _deleteCategoryAndProducts(category),
                              ),
                            ],
                          ],
                        ),
                        children: [
                          StreamBuilder<QuerySnapshot>(
                            stream:
                                FirebaseFirestore.instance
                                    .collection('institutions')
                                    .doc(_institutionId)
                                    .collection('products')
                                    .where('categoryId', isEqualTo: category.id)
                                    .orderBy('name')
                                    .snapshots(),
                            builder: (context, productSnapshot) {
                              if (productSnapshot.hasError)
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    "Erro ao carregar produtos.",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                );
                              if (productSnapshot.connectionState ==
                                  ConnectionState.waiting)
                                return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              if (!productSnapshot.hasData ||
                                  productSnapshot.data!.docs.isEmpty)
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'Nenhum produto nesta categoria.',
                                  ),
                                );
                              final products =
                                  productSnapshot.data!.docs
                                      .map(
                                        (doc) => Product.fromFirestore(
                                          doc
                                              as DocumentSnapshot<
                                                Map<String, dynamic>
                                              >,
                                        ),
                                      )
                                      .toList();
                              return Column(
                                children:
                                    products.map((product) {
                                      final bool canManageProduct =
                                          isAdmin ||
                                          product.createdBy ==
                                              _currentUserData!.id;
                                      return ListTile(
                                        title: Text(product.name),
                                        subtitle: Text(
                                          'Venda: ${currencyFormatter.format(product.salePrice)}',
                                        ),
                                        trailing:
                                            canManageProduct
                                                ? Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.edit,
                                                      ),
                                                      tooltip: 'Editar Produto',
                                                      onPressed:
                                                          () => Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder:
                                                                  (
                                                                    context,
                                                                  ) => AddEditProductPage(
                                                                    institutionId:
                                                                        _institutionId!,
                                                                    category:
                                                                        category,
                                                                    product:
                                                                        product,
                                                                  ),
                                                            ),
                                                          ),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.delete,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .error
                                                            .withOpacity(0.7),
                                                      ),
                                                      tooltip:
                                                          'Excluir Produto',
                                                      onPressed:
                                                          () => _deleteProduct(
                                                            product,
                                                          ),
                                                    ),
                                                  ],
                                                )
                                                : null,
                                      );
                                    }).toList(),
                              );
                            },
                          ),
                          if (isAdmin)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: 16.0,
                                bottom: 8.0,
                              ),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Adicionar Produto'),
                                  onPressed:
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => AddEditProductPage(
                                                institutionId: _institutionId!,
                                                category: category,
                                              ),
                                        ),
                                      ),
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
