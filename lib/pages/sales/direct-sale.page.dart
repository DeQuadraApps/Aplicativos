// lib/pages/sales/direct_sale_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quadra_vendas/services/pdf-sale.service.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/models/product.model.dart';
import 'package:quadra_vendas/models/sale.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/pages/clients/add-edit-client.page.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';
import 'package:share_plus/share_plus.dart';

class DirectSalePage extends StatefulWidget {
  const DirectSalePage({super.key});

  @override
  State<DirectSalePage> createState() => _DirectSalePageState();
}

class _DirectSalePageState extends State<DirectSalePage> {
  int _currentStep = 0;
  String? _institutionId;
  String _institutionName = '';

  Client? _selectedClient;
  final _clientSearchController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  final _clientFormKey = GlobalKey<FormState>();

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  final _productSearchController = TextEditingController();
  final Map<String, SaleItem> _saleItemsMap = {};

  bool _withInvoice = false;
  bool _newClient = false;
  final _observationsController = TextEditingController();
  bool _isLoading = true;

  // ✨ ESTADOS DO USUÁRIO
  UserModel? _currentUserData; // Armazena o objeto completo para verificar permissões
  String _currentUserRole = '';
  String _currentUserName = '';
  List<UserModel> _salespeopleList = [];
  UserModel? _selectedSalespersonForSale;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _clientSearchController.dispose();
    _paymentMethodController.dispose();
    _productSearchController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  // +++ HELPER: Verifica Permissão de Alterar Preço +++
  bool get _canChangePrice {
    if (_currentUserData == null) return false;
    if (_currentUserData!.role == 'admin') return true;
    return _currentUserData!.permissions['canChangePrice'] == true;
  }

  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if(mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = UserModel.fromFirestore(userDoc);
      final institutionId = userData.institutionId;

      if(institutionId == null) {
        if(mounted) setState(() => _isLoading = false);
        return;
      }

      final instDoc = await FirebaseFirestore.instance.collection('institutions').doc(institutionId).get();
      final adminId = instDoc.data()?['ownerId'];

      if (userData.role == 'admin') {
        final salespeopleSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('institutionId', isEqualTo: institutionId)
            .get();

        _salespeopleList = salespeopleSnapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();

        _selectedSalespersonForSale = userData;
      }

      final salespersonProductsQuery = FirebaseFirestore.instance.collection('institutions').doc(institutionId).collection('products').where('createdBy', isEqualTo: user.uid).get();
      final institutionProductsQuery = FirebaseFirestore.instance.collection('institutions').doc(institutionId).collection('products').where('createdBy', isEqualTo: adminId).get();

      final results = await Future.wait([salespersonProductsQuery, institutionProductsQuery]);
      final salespersonProducts = results[0].docs.map((doc) => Product.fromFirestore(doc)).toList();
      final institutionProducts = results[1].docs.map((doc) => Product.fromFirestore(doc)).toList();

      final allProductsMap = <String, Product>{};
      for (var product in institutionProducts) { allProductsMap[product.id!] = product; }
      for (var product in salespersonProducts) { allProductsMap[product.id!] = product; }
      final combinedProducts = allProductsMap.values.toList();
      combinedProducts.sort((a, b) => a.name.compareTo(b.name));

      if (mounted) {
        setState(() {
          _institutionId = institutionId;
          _institutionName = instDoc.data()?['name'] ?? '';
          _allProducts = combinedProducts;
          _filteredProducts = _allProducts;

          // ✨ SALVAR DADOS DO USUÁRIO ATUAL
          _currentUserData = userData; // Salva o objeto completo
          _currentUserRole = userData.role;
          _currentUserName = userData.fullName;
          _isLoading = false;
        });
      }
    } catch(e) {
      if (mounted) {
        debugPrint("Erro ao carregar dados iniciais para venda: $e");
        AppSnackBar.showError(context, message: 'Erro ao carregar dados da página.');
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
      _filteredProducts = _allProducts
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _updateSaleItem(Product product, int quantity, double price) {
    setState(() {
      if (quantity > 0) {
        if (_saleItemsMap.containsKey(product.id)) {
          _saleItemsMap[product.id]!.quantity = quantity;
          _saleItemsMap[product.id]!.unitPrice = price;
        } else {
          final newItem = SaleItem(product: product, quantity: quantity);
          newItem.unitPrice = price;
          _saleItemsMap[product.id!] = newItem;
        }
      } else {
        _saleItemsMap.remove(product.id);
      }
    });
  }

  double get _currentTotal {
    if (_saleItemsMap.isEmpty) return 0.0;
    return _saleItemsMap.values.map((item) => item.totalPrice).reduce((a, b) => a + b);
  }

  Future<void> _finalizeSale() async {
    if (_currentUserRole == 'admin' && _selectedSalespersonForSale == null) {
      AppSnackBar.showError(context, message: 'Como administrador, você deve selecionar um vendedor.');
      return;
    }

    if (_selectedClient == null || _saleItemsMap.isEmpty) {
      AppSnackBar.showError(context, message: 'Selecione um cliente e adicione produtos para continuar.');
      return;
    }

    setState(() => _isLoading = true);

    String? finalSalespersonName;
    String finalUserId;
    if (_currentUserRole == 'admin') {
      finalSalespersonName = _selectedSalespersonForSale!.fullName;
      finalUserId = _selectedSalespersonForSale!.id!;
    } else {
      finalSalespersonName = _currentUserName;
      finalUserId = FirebaseAuth.instance.currentUser!.uid;
    }

    final sale = Sale(
      client: _selectedClient!,
      clientId: _selectedClient!.id!,
      clientName: _selectedClient!.companyName,
      items: _saleItemsMap.values.toList(),
      totalAmount: _currentTotal,
      paymentMethod: _paymentMethodController.text.trim(),
      withInvoice: _withInvoice,
      newClient: _newClient,
      observations: _observationsController.text.trim(),
      saleDate: DateTime.now(),
      userId: finalUserId,
      salespersonName: finalSalespersonName,
    );

    try {
      final saleDocRef = await FirebaseFirestore.instance.collection('institutions').doc(_institutionId!).collection('sales').add(sale.toFirestore());
      final saleWithId = Sale(
        id: saleDocRef.id,
        client: sale.client,
        clientId: sale.clientId,
        clientName: sale.clientName,
        items: sale.items,
        totalAmount: sale.totalAmount,
        paymentMethod: sale.paymentMethod,
        withInvoice: sale.withInvoice,
        newClient: sale.newClient,
        observations: sale.observations,
        saleDate: sale.saleDate,
        userId: sale.userId,
        salespersonName: sale.salespersonName,
      );

      final pdfService = PdfSaleService(sale: saleWithId, institutionName: _institutionName);
      final pdfBytes = await pdfService.generatePdf();

      if(mounted) {
        await _showPostSaleDialog(pdfBytes, saleWithId);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: 'Erro ao finalizar a venda: ${e.toString()}');
      print(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleNextStep() {
    if (_isLoading) return;

    bool isValid = true;
    if (_currentStep == 0) {
      if (_selectedClient == null || !_clientFormKey.currentState!.validate()) {
        isValid = false;
        AppSnackBar.showError(context, message: 'Selecione um cliente e defina a forma de pagamento.');
      }
    } else if (_currentStep == 1) {
      if (_saleItemsMap.isEmpty) {
        isValid = false;
        AppSnackBar.showError(context, message: 'Adicione pelo menos um produto à venda.');
      }
    } else if (_currentStep == 2) {
      if (_currentUserRole == 'admin' && _selectedSalespersonForSale == null) {
        isValid = false;
        AppSnackBar.showError(context, message: 'Como administrador, você deve selecionar um vendedor.');
      }
    }

    if (isValid) {
      if (_currentStep < 2) {
        setState(() => _currentStep += 1);
      } else {
        _finalizeSale();
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Venda Direta'),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text('Total: ${currencyFormatter.format(_currentTotal)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepTapped: (step) => setState(() => _currentStep = step),
        controlsBuilder: (context, details) {
          return Container();
        },
        onStepContinue: _handleNextStep,
        onStepCancel: () {
          if (_isLoading) return;
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        steps: [
          Step(title: const Text('1. Cliente e Pagamento'), content: _buildClientStep(), isActive: _currentStep >= 0),
          Step(title: const Text('2. Adicionar Produtos'), content: _buildProductsStep(), isActive: _currentStep >= 1),
          Step(title: const Text('3. Revisar e Finalizar'), content: _buildFinalizeStep(), isActive: _currentStep >= 2),
        ],
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
        onPressed: _handleNextStep,
        label: Text(_currentStep == 2 ? 'FINALIZAR VENDA' : 'PRÓXIMO PASSO'),
        icon: _isLoading && _currentStep == 2
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,))
            : Icon(_currentStep == 2 ? Icons.check_circle_outline : Icons.arrow_forward),
      ),
    );
  }

  Widget _buildClientStep() {
    return Form(
      key: _clientFormKey,
      child: Column(
        children: [
          if (_selectedClient != null)
            Card(
              child: ListTile(
                title: Text(_selectedClient!.companyName),
                subtitle: Text(_selectedClient!.cnpj),
                trailing: IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _selectedClient = null; _clientSearchController.clear(); _paymentMethodController.clear(); })),
              ),
            ),
          const SizedBox(height: 10),
          if (_selectedClient == null)
            Autocomplete<Client>(
              displayStringForOption: (client) => '${client.companyName} (${client.city})',
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  onFieldSubmitted: (_) => onFieldSubmitted(),
                  decoration: const InputDecoration(labelText: 'Pesquisar Cliente...'),
                );
              },
              optionsBuilder: (textEditingValue) async {
                final queryText = textEditingValue.text;
                if (queryText.isEmpty) return const Iterable.empty();

                final clientsRef = FirebaseFirestore.instance
                    .collection('institutions').doc(_institutionId!)
                    .collection('clients');

                final searchEnd = '$queryText\uf8ff';

                final nameQuery = clientsRef
                    .where('companyName', isGreaterThanOrEqualTo: queryText)
                    .where('companyName', isLessThanOrEqualTo: searchEnd)
                    .get();

                final cityQuery = clientsRef
                    .where('city', isGreaterThanOrEqualTo: queryText)
                    .where('city', isLessThanOrEqualTo: searchEnd)
                    .get();

                final cnpjQuery = clientsRef
                    .where('cnpj', isGreaterThanOrEqualTo: queryText)
                    .where('cnpj', isLessThanOrEqualTo: searchEnd)
                    .get();

                final results = await Future.wait([nameQuery, cityQuery, cnpjQuery]);

                final allDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};
                for (final snapshot in results) {
                  for (final doc in snapshot.docs) {
                    allDocs[doc.id] = doc;
                  }
                }

                var clients = allDocs.values.map((doc) => Client.fromFirestore(doc));

                if (_currentUserRole != 'admin') {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser != null) {
                    clients = clients.where((client) => client.salespersonId == currentUser.uid).toList();
                  }
                }

                return clients;
              },
              onSelected: (client) => _onClientSelected(client),
            ),
          const SizedBox(height: 10),
          SwitchListTile(title: const Text('Cliente novo?'), value: _newClient, onChanged: (val) => setState(() => _newClient = val)),
          const SizedBox(height: 10),
          TextFormField(
            controller: _paymentMethodController,
            decoration: const InputDecoration(labelText: 'Forma de Pagamento'),
            validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Cadastrar Novo Cliente'),
            onPressed: () async {
              final newClient = await Navigator.push<Client?>(context, MaterialPageRoute(builder: (context) => AddEditClientPage(institutionId: _institutionId!)));
              if (newClient != null && mounted) _onClientSelected(newClient);
            },
          ),
        ],
      ),
    );
  }


  Widget _buildProductsStep() {
    return Column(
      children: [
        const SizedBox(height: 8,),
        TextField(controller: _productSearchController, decoration: const InputDecoration(labelText: 'Pesquisar Produto...', prefixIcon: Icon(Icons.search)), onChanged: _filterProducts),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredProducts.length,
          itemBuilder: (context, index) {
            final product = _filteredProducts[index];
            return ProductSaleItem(
              product: product,
              key: ValueKey(product.id),
              initialItem: _saleItemsMap[product.id],
              // ✨ PASSAMOS A PERMISSÃO PARA O WIDGET FILHO
              canChangePrice: _canChangePrice,
              onChanged: (quantity, price) {
                _updateSaleItem(product, quantity, price);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildFinalizeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        if (_currentUserRole == 'admin') ...[
          DropdownButtonFormField<UserModel>(
            value: _selectedSalespersonForSale,
            decoration: const InputDecoration(labelText: 'Atribuir Venda a', border: OutlineInputBorder()),
            items: _salespeopleList.map((UserModel salesperson) {
              return DropdownMenuItem<UserModel>(
                value: salesperson,
                child: Text(salesperson.fullName),
              );
            }).toList(),
            onChanged: (UserModel? newValue) {
              setState(() {
                _selectedSalespersonForSale = newValue;
              });
            },
            validator: (value) => value == null ? 'Selecione um vendedor' : null,
          ),
          const SizedBox(height: 16),
        ],
        SwitchListTile(title: const Text('Emitir Nota Fiscal?'), value: _withInvoice, onChanged: (val) => setState(() => _withInvoice = val)),
        TextFormField(controller: _observationsController, decoration: const InputDecoration(labelText: 'Observações (Opcional)'), maxLines: 3),
      ],
    );
  }
}

class ProductSaleItem extends StatefulWidget {
  final Product product;
  final SaleItem? initialItem;
  // ✨ NOVO PARÂMETRO
  final bool canChangePrice;
  final Function(int quantity, double price) onChanged;

  const ProductSaleItem({
    super.key,
    required this.product,
    this.initialItem,
    required this.onChanged,
    this.canChangePrice = false, // Default false por segurança
  });

  @override
  State<ProductSaleItem> createState() => _ProductSaleItemState();
}

class _ProductSaleItemState extends State<ProductSaleItem> {
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  bool _isSelected = false;

  @override
  void initState() {
    super.initState();
    _isSelected = widget.initialItem != null;
    _quantityController = TextEditingController(text: _isSelected ? widget.initialItem!.quantity.toString() : '');
    _priceController = TextEditingController(text: _isSelected ? widget.initialItem!.unitPrice.toStringAsFixed(2) : widget.product.salePrice.toStringAsFixed(2));
  }

  @override
  void didUpdateWidget(covariant ProductSaleItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(widget.initialItem != null && !_isSelected) {
      setState(() {
        _isSelected = true;
      });
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _triggerChange() {
    final quantity = int.tryParse(_quantityController.text) ?? (_isSelected ? 1 : 0);
    final price = double.tryParse(_priceController.text.replaceAll(',', '.')) ?? widget.product.salePrice;
    widget.onChanged(quantity, price);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          children: [
            ListTile(
              title: Text(widget.product.name),
              onTap: () {
                setState(() {
                  _isSelected = !_isSelected;
                  if (_isSelected && _quantityController.text.isEmpty) {
                    _quantityController.text = '1';
                  } else if (!_isSelected) {
                    _quantityController.text = '0';
                  }
                  _triggerChange();
                });
              },
              trailing: Checkbox(
                value: _isSelected,
                onChanged: (value) {
                  setState(() {
                    _isSelected = value ?? false;
                    if (_isSelected && _quantityController.text.isEmpty) {
                      _quantityController.text = '1';
                    } else if (!_isSelected) {
                      _quantityController.text = '0';
                    }
                    _triggerChange();
                  });
                },
              ),
            ),
            if (_isSelected)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(labelText: 'Qtd.', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => _triggerChange(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _priceController,
                        // ✨ APLICAÇÃO DA PERMISSÃO
                        readOnly: !widget.canChangePrice,
                        decoration: InputDecoration(
                          labelText: 'Preço Unit.',
                          prefixText: 'R\$ ',
                          border: const OutlineInputBorder(),
                          // Mostra cadeado se não puder editar
                          suffixIcon: !widget.canChangePrice ? const Icon(Icons.lock, size: 16) : null,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _triggerChange(),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}