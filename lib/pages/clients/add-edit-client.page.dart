// lib/pages/client/add_edit_client_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/services/cnpj.service.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';

enum ClientType { pj, pf }

class AddEditClientPage extends StatefulWidget {
  final String institutionId;
  final Client? client;
  final String? salespersonId;

  const AddEditClientPage({
    super.key,
    required this.institutionId,
    this.client,
    this.salespersonId,
  });

  @override
  State<AddEditClientPage> createState() => _AddEditClientPageState();
}

class _AddEditClientPageState extends State<AddEditClientPage> {
  final _pageController = PageController();
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _documentCtrl = TextEditingController();
  final _secondaryDocumentCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _houseNumberCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _paymentMethodCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();

  final _cnpjMask = MaskTextInputFormatter(mask: '##.###.###/####-##');
  final _cpfMask = MaskTextInputFormatter(mask: '###.###.###-##');
  final _phoneMask = MaskTextInputFormatter(mask: '(##) #####-####');

  bool _isLoading = false;
  int _currentPage = 0;
  bool _isLoadingInitialData = true;
  bool _isFetchingCnpj = false;
  // ✨ 1. NOVO ESTADO PARA CONTROLAR A VERIFICAÇÃO DO DOCUMENTO
  bool _isCheckingDocument = false;
  bool _isDocumentDuplicate = false;

  List<UserModel> _salespeople = [];
  String? _selectedSalespersonId;
  bool _isAdmin = false;
  ClientType _selectedClientType = ClientType.pj;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _documentCtrl.addListener(_onDocumentChanged);
  }

  @override
  void dispose() {
    _documentCtrl.removeListener(_onDocumentChanged);
    _pageController.dispose();
    _nameCtrl.dispose();
    _documentCtrl.dispose();
    _secondaryDocumentCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _houseNumberCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _paymentMethodCtrl.dispose();
    _contactNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDocumentChanged() async {
    if (_isDocumentDuplicate) {
      setState(() {
        _isDocumentDuplicate = false;
      });
    }

    final isPj = _selectedClientType == ClientType.pj;
    final mask = isPj ? _cnpjMask : _cpfMask;
    final cleanDocument = mask.getUnmaskedText();
    final requiredLength = isPj ? 14 : 11;

    if (cleanDocument.length != requiredLength) return;

    setState(() => _isCheckingDocument = true);
    bool isDuplicate = false; // Variável de controle

    try {
      // --- ETAPA 1: Validação de duplicidade (sempre ocorre primeiro) ---
      final query = await FirebaseFirestore.instance
          .collection('institutions').doc(widget.institutionId)
          .collection('clients')
          .where('cnpj', isEqualTo: _documentCtrl.text)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        isDuplicate = true; // Marca como duplicado
        if (mounted) {
          setState(() {
            _isDocumentDuplicate = true;
          });
          AppSnackBar.showError(context, message: 'Este documento já está cadastrado!');
        }
      }

      // --- ETAPA 2: Autocomplete (SÓ ocorre se NÃO for duplicado e for PJ) ---
      if (!isDuplicate && isPj) {
        setState(() => _isFetchingCnpj = true); // Ativa o loading da API
        final cnpjData = await CnpjService().fetchCnpjData(cleanDocument);
        if (cnpjData != null && mounted) {
          _nameCtrl.text = cnpjData['razao_social'] ?? '';
          _addressCtrl.text = cnpjData['logradouro'] ?? '';
          _cityCtrl.text = cnpjData['municipio'] ?? '';
          _districtCtrl.text = cnpjData['bairro'] ?? '';
          _houseNumberCtrl.text = cnpjData['numero'] ?? '';
          _phoneCtrl.text = _phoneMask.maskText(cnpjData['ddd_telefone_1'] ?? '');
          _emailCtrl.text = cnpjData['email'] ?? '';
          AppSnackBar.showSuccess(context, message: 'Dados do CNPJ preenchidos!');
        } else if (mounted) {
          // Se a API não retornar dados, informa o usuário
          AppSnackBar.showError(context, message: 'CNPJ não encontrado ou inválido.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: 'Erro ao verificar documento.');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingDocument = false;
          _isFetchingCnpj = false;
        });
      }
    }
  }

  Future<void> _loadInitialData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();

    if (mounted) {
      final userRole = userDoc.data()?['role'];
      setState(() {
        _isAdmin = userRole == 'admin';
      });

      if (_isAdmin) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('institutionId', isEqualTo: widget.institutionId)
            .where('role', whereIn: ['salesperson', 'employee'])
            .get();
        if (mounted) {
          setState(() {
            _salespeople = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
          });
        }
      }

      if (widget.client != null) {
        _nameCtrl.text = widget.client!.companyName;
        _documentCtrl.text = widget.client!.cnpj;
        _secondaryDocumentCtrl.text = widget.client!.stateRegistration ?? '';
        _addressCtrl.text = widget.client!.address;
        _cityCtrl.text = widget.client!.city;
        _districtCtrl.text = widget.client!.district;
        _houseNumberCtrl.text = widget.client!.houseNumber;
        _phoneCtrl.text = widget.client!.phone;
        _emailCtrl.text = widget.client!.email ?? '';
        _paymentMethodCtrl.text = widget.client!.paymentMethod;
        _contactNameCtrl.text = widget.client!.contactName;
        _selectedSalespersonId = widget.client!.salespersonId;
        _selectedClientType = widget.client!.clientType == 'PF' ? ClientType.pf : ClientType.pj;
      } else if (widget.salespersonId != null) {
        _selectedSalespersonId = widget.salespersonId;
      }

      setState(() {
        _isLoadingInitialData = false;
      });
    }
  }

  Future<void> _saveClient() async {
    if (_isDocumentDuplicate) {
      AppSnackBar.showError(context, message: 'Não é possível salvar. O documento informado já está cadastrado.');
      return;
    }

    setState(() => _isLoading = true);
    String salespersonToAssign;

    if (_isAdmin) {
      if (_selectedSalespersonId == null) {
        AppSnackBar.showError(context, message: 'Por favor, selecione um vendedor para vincular a este cliente.');
        setState(() => _isLoading = false);
        return;
      }
      salespersonToAssign = _selectedSalespersonId!;
    } else {
      salespersonToAssign = FirebaseAuth.instance.currentUser!.uid;
    }

    // ✨ 3. REMOVIDA A VERIFICAÇÃO DE DUPLICIDADE DAQUI
    // A verificação agora é feita em tempo real no _onDocumentChanged

    Client clientToSave = Client(
      id: widget.client?.id,
      companyName: _nameCtrl.text.trim(),
      cnpj: _documentCtrl.text.trim(),
      stateRegistration: _secondaryDocumentCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      district: _districtCtrl.text.trim(),
      houseNumber: _houseNumberCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      paymentMethod: _paymentMethodCtrl.text.trim(),
      contactName: _contactNameCtrl.text.trim(),
      salespersonId: salespersonToAssign,
      clientType: _selectedClientType == ClientType.pf ? 'PF' : 'PJ',
    );

    try {
      final collectionRef = FirebaseFirestore.instance
          .collection('institutions').doc(widget.institutionId)
          .collection('clients');

      if (widget.client == null) {
        final docRef = await collectionRef.add(clientToSave.toFirestore());
        clientToSave = clientToSave.copyWith(id: docRef.id);
      } else {
        await collectionRef.doc(clientToSave.id).update(clientToSave.toFirestore());
      }

      if (mounted) {
        AppSnackBar.showSuccess(context, message: 'Cliente salvo com sucesso!');
        Navigator.pop(context, clientToSave);
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: 'Erro ao salvar cliente.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.client == null ? 'Adicionar Cliente' : 'Editar Cliente')),
        body: _isLoadingInitialData
            ? const Center(child: CircularProgressIndicator())
            : PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (page) => setState(() => _currentPage = page),
          children: [_buildStep1(), _buildStep2()],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentPage > 0)
                TextButton(
                  onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease),
                  child: const Text('Voltar'),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: (_isLoading || _isDocumentDuplicate)
                    ? null
                    : () {
                  if (_currentPage == 0) {
                    if (_formKeyStep1.currentState!.validate()) {
                      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
                    }
                  } else {
                    if (_formKeyStep2.currentState!.validate()) {
                      _saveClient();
                    }
                  }
                },
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_currentPage == 0 ? 'Próximo' : 'Salvar'),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeyStep1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isAdmin && widget.salespersonId == null) ...[
              Text('Vendedor Responsável', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedSalespersonId,
                hint: const Text('Selecione um Vendedor'),
                isExpanded: true,
                items: _salespeople.map((UserModel user) {
                  return DropdownMenuItem<String>(
                    value: user.id,
                    child: Text(user.fullName),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedSalespersonId = newValue;
                  });
                },
                validator: (value) => value == null ? 'Campo obrigatório' : null,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
            ],
            Text('Tipo de Cadastro', style: Theme.of(context).textTheme.titleMedium),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<ClientType>(
                    title: const Text('Pessoa Jurídica'),
                    value: ClientType.pj,
                    groupValue: _selectedClientType,
                    onChanged: (ClientType? value) {
                      if (_isLoadingInitialData || _isCheckingDocument) return;
                      setState(() {
                        _selectedClientType = value!;
                        _documentCtrl.clear();
                        _nameCtrl.clear();
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<ClientType>(
                    title: const Text('Pessoa Física'),
                    value: ClientType.pf,
                    groupValue: _selectedClientType,
                    onChanged: (ClientType? value) {
                      if (_isLoadingInitialData || _isCheckingDocument) return;
                      setState(() {
                        _selectedClientType = value!;
                        _documentCtrl.clear();
                        _nameCtrl.clear();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Dados Principais', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _documentCtrl,
              decoration: InputDecoration(
                labelText: _selectedClientType == ClientType.pj ? 'CNPJ' : 'CPF',
                // ✨ 4. ATUALIZADO O SUFFIXICON PARA MOSTRAR O LOADING EM AMBAS AS OPERAÇÕES
                suffixIcon: (_isCheckingDocument || _isFetchingCnpj)
                    ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(height: 10, width: 10, child: CircularProgressIndicator(strokeWidth: 2)),
                )
                    : null,
              ),
              inputFormatters: [_selectedClientType == ClientType.pj ? _cnpjMask : _cpfMask],
              validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: _selectedClientType == ClientType.pj ? 'Razão Social' : 'Nome Completo'),
              validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _secondaryDocumentCtrl,
              decoration: InputDecoration(labelText: _selectedClientType == ClientType.pj ? 'Inscrição Estadual (Opcional)' : 'RG (Opcional)'),
            ),
            const Divider(height: 48),
            Text('Endereço', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'Cidade'), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _districtCtrl, decoration: const InputDecoration(labelText: 'Bairro'), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Rua / Avenida'), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _houseNumberCtrl, decoration: const InputDecoration(labelText: 'Número'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeyStep2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contato e Pagamento', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Telefone'), inputFormatters: [_phoneMask], validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email (Opcional)'), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            TextFormField(controller: _paymentMethodCtrl, decoration: const InputDecoration(labelText: 'Forma de Pagamento Padrão'), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _contactNameCtrl, decoration: const InputDecoration(labelText: 'Nome Completo (Contato)'), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
          ],
        ),
      ),
    );
  }
}