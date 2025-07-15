// lib/pages/clients/add_edit_client_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';

class AddEditClientPage extends StatefulWidget {
  final String institutionId;
  final Client? client;

  const AddEditClientPage({super.key, required this.institutionId, this.client});

  @override
  State<AddEditClientPage> createState() => _AddEditClientPageState();
}

class _AddEditClientPageState extends State<AddEditClientPage> {
  final _pageController = PageController();
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

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

  final _cnpjMask = MaskTextInputFormatter(mask: '##.###.###/####-##');
  final _phoneMask = MaskTextInputFormatter(mask: '(##) #####-####');

  bool _isLoading = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _companyNameCtrl.text = widget.client!.companyName;
      _cnpjCtrl.text = widget.client!.cnpj;
      _stateRegistrationCtrl.text = widget.client!.stateRegistration ?? '';
      _addressCtrl.text = widget.client!.address;
      _cityCtrl.text = widget.client!.city;
      _districtCtrl.text = widget.client!.district;
      _houseNumberCtrl.text = widget.client!.houseNumber;
      _phoneCtrl.text = widget.client!.phone;
      if (widget.client?.email != null) {
        _emailCtrl.text = widget.client!.email!;
      }
      _paymentMethodCtrl.text = widget.client!.paymentMethod;
      _contactNameCtrl.text = widget.client!.contactName;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  Future<void> _saveClient() async {
    // A validação é feita no botão "onPressed", não aqui.
    // A linha que causava o erro foi removida.

    setState(() => _isLoading = true);

    Client clientToSave = Client(
      id: widget.client?.id,
      companyName: _companyNameCtrl.text.trim(),
      cnpj: _cnpjCtrl.text.trim(),
      stateRegistration: _stateRegistrationCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      district: _districtCtrl.text.trim(),
      houseNumber: _houseNumberCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      paymentMethod: _paymentMethodCtrl.text.trim(),
      contactName: _contactNameCtrl.text.trim(),
    );

    try {
      final collectionRef = FirebaseFirestore.instance
          .collection('institutions').doc(widget.institutionId)
          .collection('clients');

      if (widget.client == null) {
        final docRef = collectionRef.add(clientToSave.toFirestore());
        clientToSave = Client(
          id: widget.client?.id,
          companyName: clientToSave.companyName, cnpj: clientToSave.cnpj, stateRegistration: clientToSave.stateRegistration,
          address: clientToSave.address, city: clientToSave.city, district: clientToSave.district, houseNumber: clientToSave.houseNumber, phone: clientToSave.phone, email: clientToSave.email,
          paymentMethod: clientToSave.paymentMethod, contactName: clientToSave.contactName
        );
      } else {
        if (clientToSave.id != null) {
          collectionRef.doc(clientToSave.id).update(clientToSave.toFirestore());
        }
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
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.client == null ? 'Adicionar Cliente' : 'Editar Cliente')),
        body: PageView(
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
                child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_currentPage == 0 ? 'Próximo' : 'Salvar'),
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
          children: [
            Text('Dados da Empresa', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(controller: _companyNameCtrl, decoration: const InputDecoration(labelText: 'Razão Social'), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _cnpjCtrl, decoration: const InputDecoration(labelText: 'CNPJ'), inputFormatters: [_cnpjMask], validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _stateRegistrationCtrl, decoration: const InputDecoration(labelText: 'Inscrição Estadual (Opcional)')),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Endereço',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
            ),

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
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
