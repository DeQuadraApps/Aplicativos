import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/models/sale.model.dart';
import 'package:quadra_vendas/pages/sales/edit-sale.page.dart';
import 'package:quadra_vendas/services/pdf-sale.service.dart';
import 'package:quadra_vendas/widgets/animated-snackbar.widget.dart';
import 'package:share_plus/share_plus.dart';

class SalesListPage extends StatefulWidget {
  const SalesListPage({super.key});

  @override
  State<SalesListPage> createState() => _SalesListPageState();
}

class _SalesListPageState extends State<SalesListPage> {
  String? _institutionId;
  String _institutionName = '';

  @override
  void initState() {
    super.initState();
    _fetchInstitutionId();
  }

  void _deleteSale(String saleId) {
    if (_institutionId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza que deseja excluir esta venda? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('institutions').doc(_institutionId)
                    .collection('sales').doc(saleId)
                    .delete();
                if (mounted) {
                  Navigator.pop(context);
                  AppSnackBar.showSuccess(context, message: 'Venda excluída com sucesso.');
                }
              } catch (e) {
                if (mounted) {
                  AppSnackBar.showError(context, message: 'Erro ao excluir venda.');
                }
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }


  Future<void> _fetchInstitutionId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final instId = userDoc.data()?['institutionId'];
      if(instId != null) {
        final instDoc = await FirebaseFirestore.instance.collection('institutions').doc(instId).get();
        if(mounted) {
          setState(() {
            _institutionId = instId;
            _institutionName = instDoc.data()?['name'] ?? '';
          });
        }
      }
    }
  }

  // Função para buscar os detalhes completos do cliente
  Future<Client?> _fetchFullClient(String clientId) async {
    if (_institutionId == null) return null;
    final clientDoc = await FirebaseFirestore.instance
        .collection('institutions').doc(_institutionId!)
        .collection('clients').doc(clientId).get();
    return clientDoc.exists ? Client.fromFirestore(clientDoc as DocumentSnapshot<Map<String, dynamic>>) : null;
  }

  // Função para mostrar o preview do PDF
  Future<void> _showPdfPreview(Sale sale) async {
    final client = await _fetchFullClient(sale.clientId);
    if(client == null) {
      if(mounted) AppSnackBar.showError(context, message: 'Cliente desta venda não encontrado.');
      return;
    }

    // CORREÇÃO: Passando o paymentMethod para o novo objeto Sale
    final fullSaleData = Sale(client: client, id: sale.id, clientName: sale.clientName, clientId: sale.clientId, items: sale.items, totalAmount: sale.totalAmount, withInvoice: sale.withInvoice, newClient: sale.newClient, observations: sale.observations, saleDate: sale.saleDate, userId: sale.userId, paymentMethod: sale.paymentMethod);
    final pdfService = PdfSaleService(sale: fullSaleData, institutionName: _institutionName);
    final pdfBytes = await pdfService.generatePdf();
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }

  /// =======================================================
  /// FUNÇÃO DE PARTILHA CORRIGIDA
  /// =======================================================
  Future<void> _shareSale(Sale sale) async {
    AppSnackBar.showInfo(context, message: "A preparar documento para partilha...");
    final client = await _fetchFullClient(sale.clientId);
    if (client == null) {
      if(mounted) AppSnackBar.showError(context, message: 'Cliente desta venda não encontrado.');
      return;
    }

    try {
      // CORREÇÃO: Passando o paymentMethod para o novo objeto Sale
      final fullSaleData = Sale(client: client, id: sale.id, clientName: sale.clientName, clientId: sale.clientId, items: sale.items, totalAmount: sale.totalAmount, withInvoice: sale.withInvoice, newClient: sale.newClient, observations: sale.observations, saleDate: sale.saleDate, userId: sale.userId, paymentMethod: sale.paymentMethod);
      final pdfService = PdfSaleService(sale: fullSaleData, institutionName: _institutionName);
      final pdfBytes = await pdfService.generatePdf();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/venda_${sale.id}.pdf').create();
      await file.writeAsBytes(pdfBytes);

      final xfile = XFile(file.path);
      await Share.shareXFiles([xfile], text: 'Segue em anexo a ordem de venda para o cliente ${sale.clientName}.');

    } catch (e) {
      if(mounted) AppSnackBar.showError(context, message: 'Erro ao partilhar a venda.');
    }
  }


  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de Vendas')),
      body: _institutionId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('institutions').doc(_institutionId)
            .collection('sales').orderBy('saleDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('Erro ao carregar vendas.'));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Nenhuma venda registrada ainda.'));

          final sales = snapshot.data!.docs.map((doc) => Sale.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: sales.length,
            itemBuilder: (context, index) {
              final sale = sales[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ExpansionTile(
                  title: Text(sale.clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  // CORREÇÃO: Exibindo o método de pagamento no subtítulo
                  subtitle: Text('Data: ${dateFormatter.format(sale.saleDate)} • Pgto: ${sale.paymentMethod}'),
                  trailing: Text(
                    currencyFormatter.format(sale.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  children: [
                    const Divider(height: 1),
                    for (final item in sale.items)
                      ListTile(
                        dense: true,
                        title: Text(item.product.name),
                        leading: Text('${item.quantity}x'),
                        trailing: Text(currencyFormatter.format(item.totalPrice)),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.edit,
                                size: 20, color: Colors.blueGrey),
                            label: const Text('Editar'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EditSalePage(sale: sale),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.delete_forever, size: 20, color: Colors.red),
                            label: const Text('Excluir'),
                            onPressed: () => _deleteSale(sale.id!),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Ver PDF'),
                            onPressed: () => _showPdfPreview(sale),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('Partilhar'),
                            onPressed: () => _shareSale(sale),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}