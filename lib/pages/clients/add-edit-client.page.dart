import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/models/user.model.dart';
import 'package:quadra_vendas/services/cnpj.service.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';

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

  // ... Controladores ...
  final _companyNameCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _stateRegistrationCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _houseNumberCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _paymentMethodCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();

  // ... Máscaras ...
  final _cnpjMask = MaskTextInputFormatter(mask: '##.###.###/####-##');
  final _phoneMask = MaskTextInputFormatter(mask: '(##) #####-####');

  // ... Estado da UI ...
  bool _isLoading = false;
  int _currentPage = 0;
  bool _isLoadingInitialData = true;
  bool _isFetchingCnpj = false; // ✨ 2. NOVO ESTADO PARA O CARREGAMENTO DO CNPJ

  // ... Estado dos Dados ...
  List<UserModel> _salespeople = [];
  String? _selectedSalespersonId;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    // ✨ 3. ADICIONAR UM OUVINTE AO CONTROLLER DO CNPJ
    _cnpjCtrl.addListener(_onCnpjChanged);
  }

  @override
  void dispose() {
    // ✨ 4. REMOVER O OUVINTE NO DISPOSE
    _cnpjCtrl.removeListener(_onCnpjChanged);
    _pageController.dispose();
    // ... outros controllers ...
    _companyNameCtrl.dispose();
    _cnpjCtrl.dispose();
    _stateRegistrationCtrl.dispose();
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

  // ✨ 5. FUNÇÃO QUE É CHAMADA QUANDO O CNPJ MUDA
  Future<void> _onCnpjChanged() async {
    final cleanCnpj = _cnpjMask.getUnmaskedText();
    // Só faz a chamada se o CNPJ tiver 14 dígitos
    if (cleanCnpj.length == 14) {
      setState(() => _isFetchingCnpj = true);
      try {
        final cnpjData = await CnpjService().fetchCnpjData(cleanCnpj);
        if (cnpjData != null && mounted) {
          // Preenche os controllers com os dados da API
          _companyNameCtrl.text = cnpjData['razao_social'] ?? '';
          _addressCtrl.text = cnpjData['logradouro'] ?? '';
          _cityCtrl.text = cnpjData['municipio'] ?? '';
          _districtCtrl.text = cnpjData['bairro'] ?? '';
          _houseNumberCtrl.text = cnpjData['numero'] ?? '';
          _phoneCtrl.text = _phoneMask.maskText(cnpjData['ddd_telefone_1'] ?? '');
          _emailCtrl.text = cnpjData['email'] ?? '';

          AppSnackBar.showSuccess(context, message: 'Dados do CNPJ preenchidos!');
        } else if (mounted) {
          AppSnackBar.showError(context, message: 'CNPJ não encontrado ou inválido.');
        }
      } catch (e) {
        if(mounted) AppSnackBar.showError(context, message: 'Erro ao consultar CNPJ.');
      } finally {
        if(mounted) setState(() => _isFetchingCnpj = false);
      }
    }
  }

  // ... (funções _loadInitialData e _saveClient permanecem as mesmas) ...
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
        // Apenas vendedores, não outros admins
            .where('role', whereIn: ['salesperson', 'employee'])
            .get();

        if(mounted){
          setState(() {
            _salespeople = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
          });
        }
      }

      if (widget.client != null) {
        _companyNameCtrl.text = widget.client!.companyName;
        _cnpjCtrl.text = widget.client!.cnpj;
        _stateRegistrationCtrl.text = widget.client!.stateRegistration ?? '';
        _addressCtrl.text = widget.client!.address;
        _cityCtrl.text = widget.client!.city;
        _districtCtrl.text = widget.client!.district;
        _houseNumberCtrl.text = widget.client!.houseNumber;
        _phoneCtrl.text = widget.client!.phone;
        _emailCtrl.text = widget.client!.email ?? '';
        _paymentMethodCtrl.text = widget.client!.paymentMethod;
        _contactNameCtrl.text = widget.client!.contactName;
        _selectedSalespersonId = widget.client!.salespersonId;
      } else if (widget.salespersonId != null) {
        _selectedSalespersonId = widget.salespersonId;
      }

      setState(() {
        _isLoadingInitialData = false;
      });
    }
  }

  Future<void> _saveClient() async {
    setState(() => _isLoading = true);

    String salespersonToAssign;

    if(_isAdmin) {
      if(_selectedSalespersonId == null) {
        AppSnackBar.showError(context, message: 'Por favor, selecione um vendedor para vincular a este cliente.');
        setState(() => _isLoading = false);
        return;
      }
      salespersonToAssign = _selectedSalespersonId!;
    } else {
      salespersonToAssign = FirebaseAuth.instance.currentUser!.uid;
    }

    final cnpj = _cnpjCtrl.text.trim();

    final query = await FirebaseFirestore.instance
        .collection('institutions').doc(widget.institutionId)
        .collection('clients')
        .where('cnpj', isEqualTo: cnpj)
        .limit(1).get();

    if(query.docs.isNotEmpty && query.docs.first.id != widget.client?.id) {
      AppSnackBar.showError(context, message: 'Este CNPJ já está cadastrado.');
      setState(() => _isLoading = false);
      return;
    }

    Client clientToSave = Client(
      id: widget.client?.id,
      companyName: _companyNameCtrl.text.trim(),
      cnpj: cnpj,
      stateRegistration: _stateRegistrationCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      district: _districtCtrl.text.trim(),
      houseNumber: _houseNumberCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      paymentMethod: _paymentMethodCtrl.text.trim(),
      contactName: _contactNameCtrl.text.trim(),
      salespersonId: salespersonToAssign,
    );

    try {
      final collectionRef = FirebaseFirestore.instance
          .collection('institutions').doc(widget.institutionId)
          .collection('clients');

      if (widget.client == null) {
        final docRef = await collectionRef.add(clientToSave.toFirestore());
        // Atualiza o objeto local com o ID gerado para poder retorná-lo
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
    // ... (build principal permanece o mesmo) ...
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
              if (_currentPage > 0) TextButton(onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease), child: const Text('Voltar')),
              const Spacer(),
              ElevatedButton(
                onPressed: _isLoading ? null : () {
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
            // ... (Dropdown do admin permanece o mesmo) ...
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

            Text('Dados da Empresa', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cnpjCtrl,
              decoration: InputDecoration(
                labelText: 'CNPJ',
                suffixIcon: _isFetchingCnpj
                    ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                      height: 10,
                      width: 10,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
                    : null,
              ),
              inputFormatters: [_cnpjMask],
              validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _companyNameCtrl, decoration: const InputDecoration(labelText: 'Razão Social'), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
            // ✨ 6. ATUALIZAR O CAMPO DE CNPJ PARA MOSTRAR O ÍCONE DE CARREGAMENTO
            const SizedBox(height: 16),
            TextFormField(controller: _stateRegistrationCtrl, decoration: const InputDecoration(labelText: 'Inscrição Estadual (Opcional)')),
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

  // ... (buildStep2 permanece o mesmo)
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