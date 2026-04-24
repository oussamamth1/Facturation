import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceLine {
  final String desc;
  final int qty;
  final double price;

  const InvoiceLine({
    required this.desc,
    required this.qty,
    required this.price,
  });

  double get amount => qty * price;

  factory InvoiceLine.fromMap(Map<String, dynamic> m) => InvoiceLine(
        desc: m['desc'] ?? '',
        qty: (m['qty'] as num?)?.toInt() ?? 1,
        price: (m['price'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {'desc': desc, 'qty': qty, 'price': price};

  InvoiceLine copyWith({String? desc, int? qty, double? price}) => InvoiceLine(
        desc: desc ?? this.desc,
        qty: qty ?? this.qty,
        price: price ?? this.price,
      );
}

class Invoice {
  final String id;
  final String userId;
  final String number;
  final String date;
  final String? clientId;
  final String clientName;
  final String clientMf;
  final String clientDetails;
  final List<InvoiceLine> lines;
  final double subtotal;
  final double taxRate;
  final double discountRate;
  final double taxAmount;
  final double discountAmount;
  final double stampDuty;
  final double total;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Invoice({
    required this.id,
    required this.userId,
    required this.number,
    required this.date,
    this.clientId,
    this.clientName = '',
    this.clientMf = '',
    this.clientDetails = '',
    this.lines = const [],
    this.subtotal = 0,
    this.taxRate = 0,
    this.discountRate = 0,
    this.taxAmount = 0,
    this.discountAmount = 0,
    this.stampDuty = 0,
    this.total = 0,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  factory Invoice.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawLines = (d['lines'] as List<dynamic>?) ?? [];
    return Invoice(
      id: doc.id,
      userId: d['userId'] ?? '',
      number: d['number'] ?? '',
      date: d['date'] ?? '',
      clientId: d['clientId'],
      clientName: d['clientName'] ?? '',
      clientMf: d['clientMf'] ?? '',
      clientDetails: d['clientDetails'] ?? '',
      lines: rawLines.map((l) => InvoiceLine.fromMap(l as Map<String, dynamic>)).toList(),
      subtotal: (d['subtotal'] as num?)?.toDouble() ?? 0,
      taxRate: (d['taxRate'] as num?)?.toDouble() ?? 0,
      discountRate: (d['discountRate'] as num?)?.toDouble() ?? 0,
      taxAmount: (d['taxAmount'] as num?)?.toDouble() ?? 0,
      discountAmount: (d['discountAmount'] as num?)?.toDouble() ?? 0,
      stampDuty: (d['stampDuty'] as num?)?.toDouble() ?? 0,
      total: (d['total'] as num?)?.toDouble() ?? 0,
      notes: d['notes'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap(String userId) => {
        'userId': userId,
        'number': number,
        'date': date,
        'clientId': clientId,
        'clientName': clientName,
        'clientMf': clientMf,
        'clientDetails': clientDetails,
        'lines': lines.map((l) => l.toMap()).toList(),
        'subtotal': subtotal,
        'taxRate': taxRate,
        'discountRate': discountRate,
        'taxAmount': taxAmount,
        'discountAmount': discountAmount,
        'stampDuty': stampDuty,
        'total': total,
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
