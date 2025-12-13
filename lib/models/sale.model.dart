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

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    final productSnapshot = Product(
      id: map['productId'],
      name: map['productName'] ?? 'Produto não encontrado',
      salePrice: (map['unitPrice'] as num? ?? 0).toDouble(),
      categoryId: '',
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
  final Client? client;
  final String clientId;
  final String clientName;
  final List<SaleItem> items;
  final double totalAmount;
  final String paymentMethod;
  final bool withInvoice;
  final bool newClient;
  final String? observations;
  final DateTime saleDate;
  final String userId;
  final String? salespersonName;
  final bool isDelivered; // ✨ NOVO: Campo para status de entrega

  Sale({
    this.id,
    this.client,
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
    this.salespersonName,
    this.isDelivered = false, // ✨ NOVO: Padrão é false (Pendente)
  });

  Map<String, dynamic> toFirestore() {
    return {
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
      'salespersonName': salespersonName,
      'isDelivered': isDelivered, // ✨ NOVO
    };
  }

  factory Sale.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Sale(
      id: doc.id,
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
      salespersonName: data['salespersonName'],
      isDelivered: data['isDelivered'] ?? false, // ✨ NOVO: Se for null, assume false
    );
  }
}