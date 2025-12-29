// lib/pages/sales/edit-sale.page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/models/product.model.dart';
import 'package:quadra_vendas/models/sale.model.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';

class EditSalePage extends StatefulWidget {
  final Sale sale;
  const EditSalePage({super.key, required this.sale});

  @override
  State<EditSalePage> createState() => _EditSalePageState();
}

class _EditSalePageState extends State<EditSalePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String? _institutionId;

  // Controladores e Variáveis de Estado
  Client? _selectedClient;
  late List<SaleItem> _cart;
  final _paymentMethodController = TextEditingController();
  final _observationsController = TextEditingController();
  bool _withInvoice = false;

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  final _productSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _paymentMethodController.dispose();
    _observationsController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) AppSnackBar.showError(context, message: 'Utilizador não autenticado.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      _institutionId = userDoc.data()?['institutionId'];
      if (_institutionId == null) throw Exception('Instituição não encontrada.');

      // Carregar todos os produtos da instituição
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('institutions').doc(_institutionId!)
          .collection('products').orderBy('name').get();
      _allProducts = productsSnapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
      _filteredProducts = _allProducts;

      // Carregar os dados completos do cliente da venda
      final clientDoc = await FirebaseFirestore.instance
          .collection('institutions').doc(_institutionId!)
          .collection('clients').doc(widget.sale.clientId).get();

      if(clientDoc.exists) {
        _selectedClient = Client.fromFirestore(clientDoc as DocumentSnapshot<Map<String, dynamic>>);
      } else {
        throw Exception('Cliente da venda não encontrado.');
      }

      // Preencher os campos com os dados da venda existente
      _cart = List<SaleItem>.from(widget.sale.items);
      _paymentMethodController.text = widget.sale.paymentMethod;
      _observationsController.text = widget.sale.observations ?? '';
      _withInvoice = widget.sale.withInvoice;

    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: 'Erro ao carregar dados da venda: ${e.toString()}');
      Navigator.pop(context);
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // +++ FUNÇÃO ADICIONADA: Exibe diálogo para editar o preço do item +++
  Future<void> _showEditPriceDialog(SaleItem item) async {
    final priceController = TextEditingController(text: item.unitPrice.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    final newPrice = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Preço de ${item.product.name}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: priceController,
            decoration: const InputDecoration(labelText: 'Novo Preço Unitário', prefixText: 'R\$ '),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Campo obrigatório';
              if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Valor inválido';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final price = double.parse(priceController.text.replaceAll(',', '.'));
                Navigator.pop(context, price);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (newPrice != null) {
      setState(() {
        item.unitPrice = newPrice;
      });
    }
  }


  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = _allProducts.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  void _addToCart(Product product) {
    setState(() {
      final existingItem = _cart.firstWhere((item) => item.product.id == product.id, orElse: () => SaleItem(product: product, quantity: 0));
      if (existingItem.quantity == 0) {
        _cart.add(existingItem);
      }
      existingItem.quantity++;
    });
    _productSearchController.clear();
    FocusScope.of(context).unfocus();
  }

  void _updateQuantity(SaleItem item, int newQuantity) {
    setState(() {
      if(newQuantity > 0) item.quantity = newQuantity;
      else _cart.remove(item);
    });
  }

  Future<void> _updateSale() async {
    if(!_formKey.currentState!.validate()){
      AppSnackBar.showError(context, message: "Por favor, preencha os campos obrigatórios.");
      return;
    }

    setState(() => _isLoading = true);

    final updatedSale = Sale(
      id: widget.sale.id,
      client: _selectedClient!,
      clientId: _selectedClient!.id!,
      clientName: _selectedClient!.companyName,
      items: _cart,
      totalAmount: _cart.fold(0.0, (sum, item) => sum + item.totalPrice),
      paymentMethod: _paymentMethodController.text.trim(),
      withInvoice: _withInvoice,
      newClient: widget.sale.newClient,
      observations: _observationsController.text.trim(),
      saleDate: widget.sale.saleDate,
      userId: widget.sale.userId,
    );

    try {
      await FirebaseFirestore.instance
          .collection('institutions').doc(_institutionId!)
          .collection('sales').doc(updatedSale.id!)
          .update(updatedSale.toFirestore());

      final financialQuery = await FirebaseFirestore.instance
          .collection('institutions')
          .doc(_institutionId)
          .collection('financial_transactions')
          .where('relatedSaleId', isEqualTo: widget.sale.id)
          .limit(1)
          .get();

      if (financialQuery.docs.isNotEmpty) {
        final transactionDoc = financialQuery.docs.first;
        await transactionDoc.reference.update({
          'amount': updatedSale.totalAmount,
          'description': 'Venda Editada - ${updatedSale.clientName}',
        });
      }

      if(mounted){
        AppSnackBar.showSuccess(context, message: 'Venda atualizada com sucesso!');
        Navigator.pop(context);
      }
    } catch (e) {
      if(mounted) AppSnackBar.showError(context, message: 'Erro ao atualizar a venda: ${e.toString()}');
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final total = _isLoading ? 0.0 : _cart.fold<double>(0, (sum, item) => sum + item.totalPrice);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Venda'),
        actions: [
          if(!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text("Total: ${currencyFormatter.format(total)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Cliente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Card(
                child: ListTile(
                  title: Text(_selectedClient?.companyName ?? "N/A"),
                  subtitle: Text(_selectedClient?.cnpj ?? "N/A"),
                  leading: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 24),

              const Text("Itens da Venda", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildCartList(currencyFormatter),
              const Divider(height: 20),
              _buildProductSearch(currencyFormatter),
              const SizedBox(height: 24),

              const Text("Detalhes do Pagamento e Fiscais", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _paymentMethodController,
                decoration: const InputDecoration(labelText: 'Forma de Pagamento', border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observationsController,
                decoration: const InputDecoration(labelText: 'Observações (Opcional)', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              SwitchListTile(
                title: const Text('Emitir Nota Fiscal?'),
                value: _withInvoice,
                onChanged: (val) => setState(() => _withInvoice = val),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: _isLoading ? null : FloatingActionButton.extended(
        onPressed: _updateSale,
        label: const Text('SALVAR ALTERAÇÕES'),
        icon: const Icon(Icons.save),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // +++ MÉTODO MODIFICADO: Lista de itens no carrinho agora permite editar o preço +++
  Widget _buildCartList(NumberFormat currencyFormatter) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _cart.length,
      itemBuilder: (context, index) {
        final item = _cart[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(item.product.name),
            subtitle: InkWell(
              onTap: () => _showEditPriceDialog(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  'Preço Unit.: ${currencyFormatter.format(item.unitPrice)} (Toque para editar)',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _updateQuantity(item, item.quantity - 1)),
                Text(item.quantity.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _updateQuantity(item, item.quantity + 1)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductSearch(NumberFormat currencyFormatter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Adicionar mais produtos", style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: _productSearchController,
          decoration: const InputDecoration(labelText: 'Pesquisar Produto...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          onChanged: _filterProducts,
        ),
        SizedBox(
          height: _filteredProducts.isEmpty ? 0 : 200,
          child: ListView.builder(
            itemCount: _filteredProducts.length,
            itemBuilder: (context, index) {
              final product = _filteredProducts[index];
              return ListTile(
                title: Text(product.name),
                subtitle: Text(currencyFormatter.format(product.salePrice)),
                trailing: IconButton(
                  icon: const Icon(Icons.add_shopping_cart),
                  onPressed: () => _addToCart(product),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}