import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String userId;
  final String name;
  final String description;
  final double price;
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Product({
    required this.id,
    required this.userId,
    required this.name,
    this.description = '',
    this.price = 0,
    this.currency = 'TND',
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      userId: d['userId'] ?? '',
      name: d['name'] ?? '',
      description: d['description'] ?? '',
      price: (d['price'] as num?)?.toDouble() ?? 0,
      currency: d['currency'] ?? 'TND',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap(String userId) => {
        'userId': userId,
        'name': name,
        'description': description,
        'price': price,
        'currency': currency,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
