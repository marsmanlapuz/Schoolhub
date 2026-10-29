import 'package:flutter/material.dart';
import '../services/payment_service.dart';

const _primaryNavy = Color(0xFF0F172A);
const _accentBlue = Color(0xFF2563EB);
const _emeraldGreen = Color(0xFF10B981);
const _bgCanvas = Color(0xFFF8FAFC);
const _cardBorder = Color(0xFFE2E8F0);
const _textMuted = Color(0xFF64748B);
const _imageBg = Color(0xFFF1F5F9);

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final PaymentService _paymentService = PaymentService();
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    setState(() {
      _ordersFuture = _paymentService.fetchOrders();
    });
  }

  String _formatPrice(dynamic orderData) {
    num amount = 0;
    if (orderData is Map) {
      amount = orderData['total_amount'] ??
          orderData['amount'] ??
          orderData['total'] ??
          0;
    }
    return '₱${amount.toDouble().toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Orders',
          style: TextStyle(
            color: _primaryNavy,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _primaryNavy),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _accentBlue),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load orders: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _textMuted),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadOrders,
                      style: FilledButton.styleFrom(backgroundColor: _accentBlue),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: _textMuted),
                  SizedBox(height: 16),
                  Text(
                    'No orders yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _primaryNavy,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your purchases will appear here after checkout.',
                    style: TextStyle(color: _textMuted),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = orders[index];
              final status = (order['status'] ?? 'PENDING').toString().toUpperCase();
              final isPaid = status == 'PAID';
              final externalId = order['external_id'] ?? order['id'] ?? '';
              final orderTitle = order['order_title'] ?? 'School supplies order';
              
              // Kunin ang imageUrl ng unang item kung meron man
              String itemImageUrl = '';
              final itemsList = order['items'];
              if (itemsList is List && itemsList.isNotEmpty) {
                itemImageUrl = itemsList[0]['imageUrl'] ?? '';
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryNavy.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Product Image thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 50,
                            height: 50,
                            color: _imageBg,
                            child: itemImageUrl.isNotEmpty
                                ? Image.network(
                                    itemImageUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.inventory_2_outlined,
                                      color: _accentBlue,
                                      size: 24,
                                    ),
                                  )
                                : const Icon(
                                    Icons.shopping_bag_rounded,
                                    color: _accentBlue,
                                    size: 24,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                orderTitle, // Eto na ang totoong pangalan ng item!
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _primaryNavy,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ref: $externalId',
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatPrice(order),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _primaryNavy,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: _cardBorder),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isPaid ? Icons.check_circle_rounded : Icons.access_time_filled_rounded,
                              size: 16,
                              color: isPaid ? _emeraldGreen : Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              status,
                              style: TextStyle(
                                color: isPaid ? _emeraldGreen : Colors.orange,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Addr: ${order['delivery_address'] ?? 'N/A'}',
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
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