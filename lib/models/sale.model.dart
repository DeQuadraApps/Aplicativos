// lib/models/sale.model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/models/product.model.dart';

class SaleItem {
  final Product product;
  int quantity;
  double unitPrice;

  SaleItem({required this.product, this.quantity = 1})
      : unitPrice = product.salePrice;

  double get totalPrice => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
    'productId': product.id,
    'productName': product.name,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'totalPrice': totalPrice,
  };

  // 💡 MELHORIA: Lógica simplificada e mais direta.
  factory SaleItem.fromMap(Map<String, dynamic> map) {
    // Cria um objeto 'Product' apenas com os dados que foram salvos na venda (um "snapshot").
    final productSnapshot = Product(
      id: map['productId'],
      name: map['productName'] ?? 'Produto não encontrado',
      salePrice: (map['unitPrice'] as num? ?? 0).toDouble(), // O preço de venda é o preço unitário da época.
      categoryId: '', // Dados não essenciais para o histórico da venda.
      categoryName: '',
    );

    return SaleItem(
      product: productSnapshot,
      quantity: (map['quantity'] as num? ?? 1).toInt(),
    );
  }
}

class Sale {
  final String? id;
  final Client? client; // Objeto completo, usado opcionalmente na criação da venda.
  final String clientId; // ID do cliente, sempre salvo.
  final String clientName; // Nome do cliente, sempre salvo.
  final List<SaleItem> items;
  final double totalAmount;
  final String paymentMethod;
  final bool withInvoice;
  final bool newClient;
  final String? observations;
  final DateTime saleDate;
  final String userId;
  final String? salespersonName; // ✨ NOVO: Campo para o nome do vendedor.

  Sale({
    this.id,
    this.client, // Opcional
    required this.clientId,
    required this.clientName,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    required this.withInvoice,
    required this.newClient,
    this.observations,
    required this.saleDate,
    required this.userId,
    this.salespersonName, // ✨ NOVO
  });

  Map<String, dynamic> toFirestore() {
    return {
      // ✨ CORREÇÃO: Usando os campos garantidos do modelo, em vez de `client!`.
      'clientId': clientId,
      'clientName': clientName,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'withInvoice': withInvoice,
      'newClient': newClient,
      'observations': observations,
      'saleDate': Timestamp.fromDate(saleDate),
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
      'salespersonName': salespersonName, // ✨ NOVO
    };
  }

  factory Sale.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Sale(
      id: doc.id,
      // ✨ CORREÇÃO: O objeto 'client' não é montado aqui, pois não temos todos os dados dele.
      // Apenas o ID e o nome são lidos. Se precisar do objeto completo, ele deve ser buscado separadamente.
      client: null,
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? 'Cliente não encontrado',
      items: (data['items'] as List<dynamic>? ?? [])
          .map((itemData) => SaleItem.fromMap(itemData as Map<String, dynamic>))
          .toList(),
      totalAmount: (data['totalAmount'] as num? ?? 0).toDouble(),
      paymentMethod: data['paymentMethod'] ?? 'Não informada',
      withInvoice: data['withInvoice'] ?? false,
      newClient: data['newClient'] ?? false,
      observations: data['observations'],
      saleDate: (data['saleDate'] as Timestamp).toDate(),
      userId: data['userId'] ?? '',
      salespersonName: data['salespersonName'], // ✨ NOVO
    );
  }
}