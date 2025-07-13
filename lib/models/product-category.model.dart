// lib/models/product_category_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductCategory {
  final String id;
  final String name;

  ProductCategory({required this.id, required this.name});

  factory ProductCategory.fromFirestore(DocumentSnapshot doc) {
    return ProductCategory(
      id: doc.id,
      name: doc['name'] ?? '',
    );
  }
}