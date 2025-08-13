import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  final String? id;
  final String companyName;
  final String cnpj;
  final String? stateRegistration;
  final String address;
  final String city;
  final String district;
  final String houseNumber;
  final String phone;
  final String? email;
  final String paymentMethod;
  final String contactName;
  final String salespersonId;

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
    required this.salespersonId,
  });

  factory Client.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Client(
      id: doc.id,
      companyName: data['companyName'] ?? '',
      cnpj: data['cnpj'] ?? '',
      stateRegistration: data['stateRegistration'],
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      district: data['district'] ?? '',
      houseNumber: data['houseNumber'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'],
      paymentMethod: data['paymentMethod'] ?? '',
      contactName: data['contactName'] ?? '',
      salespersonId: data['salespersonId'] ?? '',
    );
  }

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
      'salespersonId': salespersonId,
    };
  }

  Client copyWith({
    String? id,
    String? companyName,
    String? cnpj,
    String? stateRegistration,
    String? address,
    String? city,
    String? district,
    String? houseNumber,
    String? phone,
    String? email,
    String? paymentMethod,
    String? contactName,
    String? salespersonId,
  }) {
    return Client(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      cnpj: cnpj ?? this.cnpj,
      stateRegistration: stateRegistration ?? this.stateRegistration,
      address: address ?? this.address,
      city: city ?? this.city,
      district: district ?? this.district,
      houseNumber: houseNumber ?? this.houseNumber,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      contactName: contactName ?? this.contactName,
      salespersonId: salespersonId ?? this.salespersonId,
    );
  }
}