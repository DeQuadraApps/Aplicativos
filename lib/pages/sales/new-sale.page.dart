// lib/pages/sales/new-sale.page.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:quadra_vendas/enums/plan-type.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/models/product.model.dart';
import 'package:quadra_vendas/models/sale.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/pages/clients/add-edit-client.page.dart';
import 'package:quadra_vendas/services/pdf-sale.service.dart';
import 'package:quadra_vendas/services/whatsapp.service.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';
import 'package:share_plus/share_plus.dart';

class NewSalePage extends StatefulWidget {
  // ✨ NOVOS PARÂMETROS PARA O HISTÓRICO
  final Client? preSelectedClient;
  final List<SaleItem>? preSelectedItems;

  const NewSalePage({
    super.key,
    this.preSelectedClient,
    this.preSelectedItems,
  });

  @override
  State<NewSalePage> createState() => _NewSalePageState();
}

class _NewSalePageState extends State<NewSalePage> {
  int _currentStep = 0;
  String? _institutionId;
  String _institutionName = '';
  PlanType _activePlan = PlanType.start;

  Client? _selectedClient;
  final _clientSearchController = TextEditingController();
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  // AQUI É UMA LISTA, DIFERENTE DA DIRECT SALES
  final List<SaleItem> _cart = [];

  final _productSearchController = TextEditingController();
  bool _withInvoice = false;
  bool _newClient = false;
  final _observationsController = TextEditingController();
  bool _isLoading = true;
  final _paymentMethodController = TextEditingController();
  final _finalizeFormKey = GlobalKey<FormState>();

  // ESTADOS DO USUÁRIO
  UserModel? _currentUserData;
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
    _productSearchController.dispose();
    _observationsController.dispose();
    _paymentMethodController.dispose();
    super.dispose();
  }

  // HELPER: Verifica Permissão de Alterar Preço
  bool get _canChangePrice {
    if (_currentUserData == null) return false;
    if (_currentUserData!.role == 'admin') return true;
    return _currentUserData!.permissions['canChangePrice'] == true;
  }

  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = UserModel.fromFirestore(userDoc);
      final institutionId = userData.institutionId;

      if (institutionId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final instDoc = await FirebaseFirestore.instance.collection('institutions').doc(institutionId).get();
      final data = instDoc.data();
      final adminId = data?['ownerId'];

      final plan = (data?['plan'] ?? 'start').toString().toLowerCase();

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
          _institutionName = data?['name'] ?? '';
          _activePlan = PlanType.fromString(plan);
          _allProducts = combinedProducts;
          _filteredProducts = _allProducts;
          _currentUserData = userData;
          _currentUserRole = userData.role;
          _currentUserName = userData.fullName;
          _isLoading = false;
        });
      }

      // ✨ LÓGICA DO HISTÓRICO (Repetir Pedido)
      if (widget.preSelectedClient != null) {
        _selectedClient = widget.preSelectedClient;
        _paymentMethodController.text = widget.preSelectedClient!.paymentMethod;
      }

      if (widget.preSelectedItems != null) {
        // Como _cart é uma Lista, nós apenas adicionamos tudo
        _cart.addAll(widget.preSelectedItems!);
      }

    } catch (e) {
      if (mounted) {
        debugPrint("Erro ao carregar dados iniciais: $e");
        AppSnackBar.showError(context, message: 'Erro ao carregar dados iniciais.');
        setState(() => _isLoading = false);
      }
    }
  }

  // ✨ DIALOG DE UPGRADE
  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Funcionalidade Premium"),
        content: const Text("O envio rápido via WhatsApp é exclusivo dos planos Control e Elite.\n\nFaça um upgrade para agilizar seu atendimento!"),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Entendi"))],
      ),
    );
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
      // Verifica se já existe na lista
      final existingItem = _cart.firstWhere(
              (item) => item.product.id == product.id,
          orElse: () => SaleItem(product: product, quantity: 0)
      );

      // Se a quantidade for 0, significa que veio do orElse (não estava na lista)
      if (existingItem.quantity == 0) {
        existingItem.quantity = 1; // Começa com 1
        _cart.add(existingItem);
      } else {
        existingItem.quantity++; // Incrementa
      }
    });
  }

  void _updateQuantity(SaleItem item, int newQuantity) {
    setState(() {
      if (newQuantity > 0) {
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
      if (mounted) AppSnackBar.showError(context, message: 'Erro ao preparar partilha.');
    }
  }

  // ✨ DIÁLOGO ATUALIZADO (Validado WhatsApp)
  Future<void> _showPostSaleDialog(Uint8List pdfBytes, Sale sale) async {
    final bool isStartPlan = _activePlan == PlanType.start;

    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 50),
              SizedBox(height: 10),
              Text('Venda Salva!'),
            ],
          ),
          content: const Text('O que deseja fazer agora?', textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowButtonSpacing: 8,
          actions: [
            // BOTÃO WHATSAPP (Validado)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isStartPlan ? Colors.grey : Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
              ),
              icon: Icon(isStartPlan ? Icons.lock_outline : Icons.share, size: 18),
              label: Text(isStartPlan ? 'WhatsApp (Premium)' : 'Enviar WhatsApp (Texto)'),
              onPressed: () {
                if (isStartPlan) {
                  _showUpgradeDialog();
                } else {
                  Navigator.of(context).pop();
                  WhatsAppService.sendSaleText(
                    context: context,
                    sale: sale,
                    institutionName: _institutionName,
                  );
                }
              },
            ),

            // BOTÃO VER PDF (Liberado)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Ver PDF Formal'),
              onPressed: () {
                Navigator.of(context).pop();
                Printing.layoutPdf(onLayout: (format) async => pdfBytes);
              },
            ),

            // BOTÃO FECHAR
            TextButton(
              child: const Text('Fechar', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ));
  }

  Future<void> _finalizeSale() async {
    if (!_finalizeFormKey.currentState!.validate()) return;

    if (_currentUserRole == 'admin' && _selectedSalespersonForSale == null) {
      AppSnackBar.showError(context, message: 'Como administrador, você deve selecionar um vendedor.');
      return;
    }

    if (_selectedClient == null) {
      AppSnackBar.showError(context, message: 'Selecione um cliente para continuar.');
      return;
    }
    if (_cart.isEmpty) {
      AppSnackBar.showError(context, message: 'Adicione produtos ao carrinho.');
      return;
    }

    setState(() => _isLoading = true);

    String? finalSalespersonName;
    if (_currentUserRole == 'admin') {
      finalSalespersonName = _selectedSalespersonForSale!.fullName;
    } else {
      finalSalespersonName = _currentUserName;
    }

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
      userId: _currentUserRole == 'admin' ? _selectedSalespersonForSale!.id! : FirebaseAuth.instance.currentUser!.uid,
      paymentMethod: _paymentMethodController.text.trim(),
      salespersonName: finalSalespersonName,
    );

    try {
      final saleDocRef = await FirebaseFirestore.instance
          .collection('institutions').doc(_institutionId!)
          .collection('sales').add(sale.toFirestore());

      final saleWithId = Sale(
        id: saleDocRef.id,
        client: sale.client,
        clientId: sale.clientId,
        clientName: sale.clientName,
        items: sale.items,
        totalAmount: sale.totalAmount,
        withInvoice: sale.withInvoice,
        newClient: sale.newClient,
        observations: sale.observations,
        saleDate: sale.saleDate,
        userId: sale.userId,
        paymentMethod: sale.paymentMethod,
        salespersonName: sale.salespersonName,
      );

      await FirebaseFirestore.instance
          .collection('institutions')
          .doc(_institutionId)
          .collection('financial_transactions')
          .add({
        'institutionId': _institutionId,
        'description': 'Venda - ${_selectedClient!.companyName}',
        'amount': sale.totalAmount,
        'type': 'income',
        'status': 'paid',
        'dueDate': Timestamp.fromDate(DateTime.now()),
        'paidAt': Timestamp.fromDate(DateTime.now()),
        'category': 'Vendas',
        'paymentMethod': _paymentMethodController.text,
        'relatedSaleId': saleDocRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // GERAÇÃO DE PDF (Sempre liberado)
      final pdfService = PdfSaleService(sale: saleWithId, institutionName: _institutionName, activePlan: _activePlan);
      final pdfBytes = await pdfService.generatePdf();

      if (mounted) {
        await _showPostSaleDialog(pdfBytes, saleWithId);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: 'Erro ao finalizar a venda: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showEditPriceDialog(SaleItem item) async {
    if (!_canChangePrice) {
      AppSnackBar.showError(context, message: 'Você não tem permissão para alterar preços.');
      return;
    }

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
      onTap: () => FocusScope.of(context).unfocus(),
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
              // Validação ao finalizar
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
                MaterialPageRoute(builder: (context) => AddEditClientPage(institutionId: _institutionId!)));
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
                    // Só abre o dialog se tiver permissão
                    onTap: () => _showEditPriceDialog(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${currencyFormatter.format(item.unitPrice)} ',
                            style: TextStyle(color: Theme.of(context).colorScheme.primary),
                          ),
                          if (_canChangePrice)
                            const Icon(Icons.edit, size: 14, color: Colors.grey)
                          else
                            const Icon(Icons.lock, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  trailing: SizedBox(
                    width: 180,
                    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
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
              }),
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

          if (_currentUserRole == 'admin') ...[
            DropdownButtonFormField<UserModel>(
              value: _selectedSalespersonForSale,
              decoration: const InputDecoration(labelText: 'Atribuir Venda a'),
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