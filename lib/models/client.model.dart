// lib/models/client_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  final String? id;
  final String companyName; // Razão Social
  final String cnpj;
  final String? stateRegistration; // Inscrição Estadual (opcional)
  final String address;
  final String city;
  final String district;
  final String houseNumber;
  final String phone;
  final String? email;
  final String paymentMethod;
  final String contactName; // Nome Completo do Contato

  Client({
    this.id,
    required this.companyName,
    required this.cnpj,
    this.stateRegistration,
    required this.address,
    required this.city,
    required this.district,
    required this.houseNumber,
    required this.phone,
    this.email,
    required this.paymentMethod,
    required this.contactName,
  });

  // Converte um Documento do Firestore para um objeto Client
  factory Client.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return Client(
      id: snapshot.id,
      companyName: data['companyName'] ?? '',
      cnpj: data['cnpj'] ?? '',
      stateRegistration: data['stateRegistration'],
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      district: data['district'] ?? '',
      houseNumber: data['houseNumber'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      paymentMethod: data['paymentMethod'] ?? '',
      contactName: data['contactName'] ?? '',
    );
  }

  // Converte um objeto Client para um Map para o Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'companyName': companyName,
      'cnpj': cnpj,
      'stateRegistration': stateRegistration,
      'address': address,
      'city': city,
      'district': district,
      'houseNumber': houseNumber,
      'phone': phone,
      'email': email,
      'paymentMethod': paymentMethod,
      'contactName': contactName,
    };
  }
}