// lib/pages/sales/new_sale_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/models/product.model.dart';
import 'package:quadra_vendas/models/sale.model.dart';
import 'package:quadra_vendas/pages/clients/add-edit-client.page.dart';
import 'package:quadra_vendas/services/pdf-sale.service.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';
import 'package:share_plus/share_plus.dart';

class NewSalePage extends StatefulWidget {
  const NewSalePage({super.key});

  @override
  State<NewSalePage> createState() => _NewSalePageState();
}

class _NewSalePageState extends State<NewSalePage> {
  int _currentStep = 0;
  String? _institutionId;
  String _institutionName = '';
  Client? _selectedClient;
  final _clientSearchController = TextEditingController();
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<SaleItem> _cart = [];
  final _productSearchController = TextEditingController();
  bool _withInvoice = false;
  bool _newClient = false;
  final _observationsController = TextEditingController();
  bool _isLoading = true;
  final _paymentMethodController = TextEditingController();
  final _finalizeFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _clientSearchController.dispose();
    _productSearchController.dispose();
    _observationsController.dispose();
    _paymentMethodController.dispose();
    super.dispose();
  }

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

  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final institutionId = userDoc.data()?['institutionId'];
      if(institutionId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final instDoc = await FirebaseFirestore.instance.collection('institutions').doc(institutionId).get();
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('institutions').doc(institutionId)
          .collection('products').orderBy('name').get();

      if (mounted) {
        setState(() {
          _institutionId = institutionId;
          _institutionName = instDoc.data()?['name'] ?? '';
          _allProducts = productsSnapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
          _filteredProducts = _allProducts;
          _isLoading = false;
        });
      }
    } catch(e) {
      if (mounted) {
        AppSnackBar.showError(context, message: 'Erro ao carregar dados iniciais.');
        setState(() => _isLoading = false);
      }
    }
  }

  void _onClientSelected(Client client) {
    setState(() {
      _selectedClient = client;
      _paymentMethodController.text = client.paymentMethod;
      _clientSearchController.clear();
      FocusScope.of(context).unfocus();
    });
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
  }

  void _updateQuantity(SaleItem item, int newQuantity) {
    setState(() {
      if(newQuantity > 0) {
        item.quantity = newQuantity;
      } else {
        _cart.remove(item);
      }
    });
  }

  Future<void> _sharePdf(Uint8List pdfBytes, Sale sale) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/venda_${sale.id ?? DateTime.now().millisecondsSinceEpoch}.pdf').create();
      await file.writeAsBytes(pdfBytes);
      final xfile = XFile(file.path);
      await Share.shareXFiles([xfile], text: 'Segue em anexo a ordem de venda para o cliente ${sale.clientName}.');
    } catch (e) {
      if(mounted) AppSnackBar.showError(context, message: 'Erro ao preparar partilha.');
    }
  }

  Future<void> _showPostSaleDialog(Uint8List pdfBytes, Sale sale) async {
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Venda Salva com Sucesso!'),
          content: const Text('O que deseja fazer agora?'),
          actions: [
            TextButton(
              child: const Text('Fechar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Ver PDF'),
              onPressed: () {
                Navigator.of(context).pop();
                Printing.layoutPdf(onLayout: (format) async => pdfBytes);
              },
            ),
            ElevatedButton(
              child: const Text('Partilhar'),
              onPressed: () {
                Navigator.of(context).pop();
                _sharePdf(pdfBytes, sale);
              },
            )
          ],
        )
    );
  }

  Future<void> _finalizeSale() async {
    if (!_finalizeFormKey.currentState!.validate()) return;
    if (_selectedClient == null) {
      AppSnackBar.showError(context, message: 'Selecione um cliente para continuar.');
      return;
    }
    if (_cart.isEmpty) {
      AppSnackBar.showError(context, message: 'Adicione produtos ao carrinho.');
      return;
    }

    setState(() => _isLoading = true);

    final total = _cart.fold<double>(0, (sum, item) => sum + item.totalPrice);
    final sale = Sale(
      client: _selectedClient!,
      clientId: _selectedClient!.id ?? 'offline_${DateTime.now().millisecondsSinceEpoch}',
      clientName: _selectedClient!.companyName,
      items: _cart,
      totalAmount: total,
      withInvoice: _withInvoice,
      newClient: _newClient,
      observations: _observationsController.text.trim(),
      saleDate: DateTime.now(),
      userId: FirebaseAuth.instance.currentUser!.uid,
      paymentMethod: _paymentMethodController.text.trim(),
    );

    // 1. "Dispara" a operação de salvar sem esperar (sem await)
    FirebaseFirestore.instance
        .collection('institutions').doc(_institutionId!)
        .collection('sales').add(sale.toFirestore());

    // 2. Continua imediatamente para a geração do PDF e feedback
    try {
      final pdfService = PdfSaleService(sale: sale, institutionName: _institutionName);
      final pdfBytes = await pdfService.generatePdf();

      if(mounted) {
        await _showPostSaleDialog(pdfBytes, sale);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: 'Erro ao gerar o PDF: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showEditQuantityDialog(SaleItem item) async {
    final quantityController = TextEditingController(text: item.quantity.toString());

    final newQuantity = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterar Quantidade'),
        content: TextFormField(
          controller: quantityController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nova Quantidade'),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text);
              if (quantity != null && quantity > 0) {
                Navigator.pop(context, quantity);
              } else {
                // Se o utilizador digitar 0 ou um valor inválido, removemos o item.
                Navigator.pop(context, 0);
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (newQuantity != null) {
      _updateQuantity(item, newQuantity);
    }
  }
  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Nova Venda')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stepper(
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 40.0),
              child: Row(
                children: <Widget>[
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: Text(_currentStep == 2 ? 'FINALIZAR' : 'PRÓXIMO'),
                  ),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('VOLTAR'),
                    ),
                ],
              ),
            );
          },
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepContinue: () {
            bool isStepValid = true;
            if (_currentStep == 0 && _selectedClient == null) {
              AppSnackBar.showError(context, message: 'Por favor, selecione um cliente.');
              isStepValid = false;
            } else if (_currentStep == 1 && _cart.isEmpty) {
              AppSnackBar.showError(context, message: 'Adicione pelo menos um produto ao carrinho.');
              isStepValid = false;
            } else if (_currentStep == 2) {
              if (!_finalizeFormKey.currentState!.validate()) {
                isStepValid = false;
              }
            }

            if (isStepValid) {
              if (_currentStep < 2) {
                setState(() => _currentStep += 1);
              } else {
                _finalizeSale();
              }
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
            }
          },
          steps: [
            Step(title: const Text('Cliente'), isActive: _currentStep >= 0, content: _buildClientStep()),
            Step(title: const Text('Produtos'), isActive: _currentStep >= 1, content: _buildProductsStep(currencyFormatter)),
            Step(title: const Text('Finalizar'), isActive: _currentStep >= 2, content: _buildFinalizeStep(currencyFormatter)),
          ],
        ),
      ),
    );
  }

  Widget _buildClientStep() {
    return Column(
      children: [
        if (_selectedClient != null)
          Card(
            child: ListTile(
              title: Text(_selectedClient!.companyName),
              subtitle: Text(_selectedClient!.cnpj),
              trailing: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _selectedClient = null;
                    _clientSearchController.clear();
                    _paymentMethodController.clear();
                  });
                },
              ),
            ),
          ),
        const SizedBox(height: 10),
        Autocomplete<Client>(
          displayStringForOption: (client) => client.companyName,
          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              onFieldSubmitted: (_) => onFieldSubmitted(),
              decoration: const InputDecoration(labelText: 'Pesquisar Cliente...'),
            );
          },
          optionsBuilder: (textEditingValue) async {
            if (textEditingValue.text.isEmpty) return const Iterable.empty();
            final snapshot = await FirebaseFirestore.instance
                .collection('institutions').doc(_institutionId!)
                .collection('clients')
                .where('companyName', isGreaterThanOrEqualTo: textEditingValue.text)
                .where('companyName', isLessThanOrEqualTo: '${textEditingValue.text}\uf8ff')
                .get();
            return snapshot.docs.map((doc) => Client.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>));
          },
          onSelected: (client) => _onClientSelected(client),
        ),
        SwitchListTile(
          title: const Text('Cliente novo?'),
          value: _newClient,
          onChanged: (val) => setState(() => _newClient = val),
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Cadastrar Novo Cliente'),
          onPressed: () async {
            final newClient = await Navigator.push<Client?>(
                context,
                MaterialPageRoute(builder: (context) => AddEditClientPage(institutionId: _institutionId!))
            );
            if (newClient != null && mounted) {
              _onClientSelected(newClient);
            }
          },
        )
      ],
    );
  }

  Widget _buildProductsStep(NumberFormat currencyFormatter) {
    return Column(
      children: [
        TextField(
          controller: _productSearchController,
          decoration: const InputDecoration(labelText: 'Pesquisar Produto...', prefixIcon: Icon(Icons.search)),
          onChanged: _filterProducts,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: _filteredProducts.isEmpty
              ? const Center(child: Text("Nenhum produto encontrado."))
              : ListView.builder(
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
        const Divider(),
        const Text('Carrinho', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(
          height: 200,
          child: _cart.isEmpty
              ? const Center(child: Text("O carrinho está vazio."))
              : ListView.builder(
              itemCount: _cart.length,
              itemBuilder: (context, index) {
                final item = _cart[index];
                return ListTile(
                  title: Text(item.product.name),
                  subtitle: InkWell(
                    onTap: () => _showEditPriceDialog(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        '${currencyFormatter.format(item.unitPrice)} (Toque para editar)',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ),
                  trailing: SizedBox(
                    width: 180,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                      IconButton(icon: const Icon(Icons.remove), onPressed: () => _updateQuantity(item, item.quantity - 1)),
                      InkWell(
                        onTap: () => _showEditQuantityDialog(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            item.quantity.toString(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.add), onPressed: () => _updateQuantity(item, item.quantity + 1)),
                    ]),
                  ),
                );
              }
          ),
        ),
      ],
    );
  }

  Widget _buildFinalizeStep(NumberFormat currencyFormatter) {
    final total = _cart.fold<double>(0, (sum, item) => sum + item.totalPrice);
    return Form(
      key: _finalizeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total da Venda: ${currencyFormatter.format(total)}', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          TextFormField(
            controller: _paymentMethodController,
            decoration: const InputDecoration(labelText: 'Forma de Pagamento'),
            validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Emitir Nota Fiscal?'),
            value: _withInvoice,
            onChanged: (val) => setState(() => _withInvoice = val),
          ),
          TextFormField(
            controller: _observationsController,
            decoration: const InputDecoration(labelText: 'Observações (Opcional)'),
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

