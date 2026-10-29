import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../models/product_model.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _xenditSecretKey = 'xnd_development_YKpE2qzDkEis6kPWwAflMYlRmb6V3qbWQ6BL59PQ3vwrveIl6x2nbe9FgcjTnZBE';

  Future<List<Product>> fetchProducts() async {
    final snapshot = await _firestore
        .collection('products')
        .orderBy('id')
        .get();

    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      final productId = data['id'];
      data['id'] = productId is num
          ? productId.toInt()
          : int.tryParse(doc.id) ?? 0;
      
      // Siguraduhing direktang kinukuha ang imageUrl mula sa Firestore
      data['imageUrl'] = data['imageUrl'] ?? '';
      
      return Product.fromMap(data);
    }).toList();
  }

  Future<Map<String, dynamic>> createInvoiceForCart({
    required List<Map<String, dynamic>> items,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String deliveryAddress,
  }) async {
    try {
      final String externalId = 'order_${DateTime.now().millisecondsSinceEpoch}';

      double calculatedTotal = 0.0;
      for (var item in items) {
        final price = (item['price'] ?? item['amount'] ?? 0).toDouble();
        final quantity = (item['quantity'] ?? item['qty'] ?? 1) as int;
        calculatedTotal += price * quantity;
      }

      if (calculatedTotal <= 0) {
        calculatedTotal = 100.0;
      }

      String orderTitle = 'School supplies order';
      if (items.isNotEmpty) {
        final firstName = items[0]['name'] ?? 'School Supply';
        if (items.length >  1) {
          orderTitle = '$firstName (+ ${items.length - 1} other item/s)';
        } else {
          orderTitle = firstName;
        }
      }

      String basicAuth = 'Basic ' + base64Encode(utf8.encode('$_xenditSecretKey:'));

      final response = await http.post(
        Uri.parse('https://api.xendit.co/v2/invoices'),
        headers: <String, String>{
          'authorization': basicAuth,
          'content-type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'external_id': externalId,
          'amount': calculatedTotal,
          'payer_email': customerEmail,
          'description': orderTitle,
          'customer': {
            'given_names': customerName,
            'email': customerEmail,
            'mobile_number': customerPhone,
          },
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        for (var item in items) {
          final productId = item['product_id']?.toString();
          final int quantityBought = (item['quantity'] ?? 1) as int;

          if (productId != null) {
            final productRef = _firestore.collection('products').doc(productId);
            final productDoc = await productRef.get();

            if (productDoc.exists) {
              final currentStock = (productDoc.data()?['stock'] ?? 100) as num;
              final newStock = (currentStock - quantityBought).clamp(0, 999999);
              await productRef.update({'stock': newStock});
            }
          }
        }

        await _firestore.collection('orders').add({
          'external_id': externalId,
          'order_title': orderTitle,
          'customer_name': customerName,
          'customer_email': customerEmail,
          'customer_phone': customerPhone,
          'delivery_address': deliveryAddress,
          'total_amount': calculatedTotal,
          'amount': calculatedTotal,
          'total': calculatedTotal,
          'status': 'PENDING',
          'items': items,
          'invoice_url': data['invoice_url'],
          'created_at': FieldValue.serverTimestamp(),
        });

        return {
          'invoice_url': data['invoice_url'],
          'external_id': externalId,
        };
      } else {
        throw Exception('Xendit Error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Unable to create Xendit invoice: $e');
    }
  }

  Future<String> checkOrderStatus(String externalId) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('external_id', isEqualTo: externalId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return 'PENDING';

      final doc = snapshot.docs.first;
      String basicAuth = 'Basic ' + base64Encode(utf8.encode('$_xenditSecretKey:'));

      final response = await http.get(
        Uri.parse('https://api.xendit.co/v2/invoices?external_id=$externalId'),
        headers: <String, String>{
          'authorization': basicAuth,
        },
      );

      if (response.statusCode == 200) {
        final List invoices = jsonDecode(response.body);
        if (invoices.isNotEmpty) {
          final String xenditStatus = invoices[0]['status']?.toString().toUpperCase() ?? 'PENDING';

          await _firestore.collection('orders').doc(doc.id).update({
            'status': xenditStatus,
          });

          return xenditStatus;
        }
      }

      return doc.data()['status']?.toString() ?? 'PENDING';
    } catch (e) {
      return 'PENDING';
    }
  }

  Future<List<Map<String, dynamic>>> fetchOrders() async {
    final snapshot = await _firestore
        .collection('orders')
        .orderBy('created_at', descending: true)
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final String status = (data['status'] ?? '').toString().toUpperCase();
      final String externalId = data['external_id'] ?? '';

      if (status == 'PENDING' && externalId.isNotEmpty) {
        try {
          String basicAuth = 'Basic ' + base64Encode(utf8.encode('$_xenditSecretKey:'));
          final response = await http.get(
            Uri.parse('https://api.xendit.co/v2/invoices?external_id=$externalId'),
            headers: {'authorization': basicAuth},
          );
          if (response.statusCode == 200) {
            final List invoices = jsonDecode(response.body);
            if (invoices.isNotEmpty) {
              final String freshStatus = invoices[0]['status']?.toString().toUpperCase() ?? 'PENDING';
              if (freshStatus != status) {
                await _firestore.collection('orders').doc(doc.id).update({'status': freshStatus});
              }
            }
          }
        } catch (_) {}
      }
    }

    final updatedSnapshot = await _firestore
        .collection('orders')
        .orderBy('created_at', descending: true)
        .get();

    return updatedSnapshot.docs.map((doc) {
      final data = doc.data();
      final num priceValue = data['total_amount'] ?? data['amount'] ?? data['total'] ?? 0;

      return <String, dynamic>{
        ...data,
        'id': doc.id,
        'total_amount': priceValue,
        'amount': priceValue,
        'total': priceValue,
      };
    }).toList();
  }
}