import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_model.dart';
import '../services/payment_service.dart';
import 'orders_screen.dart';
import 'xendit_webview_screen.dart';

// Premium Modern Color Palette (Elegant & Mobile-Optimized)
const _primaryNavy = Color(0xFF0F172A);
const _accentBlue = Color(0xFF2563EB);
const _vibrantIndigo = Color(0xFF4F46E5);
const _emeraldGreen = Color(0xFF10B981);
const _roseColor = Color(0xFFF43F5E);
const _bgCanvas = Color(0xFFF8FAFC);
const _cardBorder = Color(0xFFE2E8F0);
const _textMuted = Color(0xFF64748B);
const _imageBg = Color(0xFFF1F5F9);

class ProductListScreen extends StatefulWidget {
  final String? initialCategory;
  const ProductListScreen({super.key, this.initialCategory});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final PaymentService _paymentService = PaymentService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _productsSectionKey = GlobalKey();

  late Future<List<Product>> _productsFuture;

  bool _isProcessing = false;
  String _searchQuery = '';
  late String _selectedCategory;

  final Map<int, int> _cart = {};
  final Set<int> _favorites = {};

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'All';
    _loadProducts();
    _restoreCart();
  }

  static const String _cartStorageKey = 'schoolhub_saved_cart_v1';

  Future<void> _restoreCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_cartStorageKey);
      if (saved == null || saved.isEmpty || !mounted) return;
      final decoded = (jsonDecode(saved) as Map<String, dynamic>);
      setState(() {
        _cart
          ..clear()
          ..addAll(decoded.map((key, value) => MapEntry(
                int.parse(key),
                (value as num).toInt(),
              )));
      });
    } catch (_) {}
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cartStorageKey,
        jsonEncode(_cart.map((key, value) => MapEntry(key.toString(), value))),
      );
    } catch (_) {
      if (mounted) _notice('Cart could not be saved on this device.', isError: true);
    }
  }

  void _loadProducts() {
    setState(() {
      _productsFuture = _paymentService.fetchProducts();
    });
  }

  void _scrollToProducts() {
    final context = _productsSectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    } else if (_scrollController.hasClients) {
      _scrollController.animateTo(
        320,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int get _cartCount =>
      _cart.values.fold(0, (sum, quantity) => sum + quantity);

  String _money(num value) => '₱${value.toStringAsFixed(2)}';

  void _addToCart(Product product, {int quantity = 1}) {
    if (product.stock <= 0) {
      _notice(
        '${product.name} is currently out of stock.',
        isError: true,
      );
      return;
    }

    setState(() {
      final current = _cart[product.id] ?? 0;
      _cart[product.id] =
          (current + quantity).clamp(1, product.stock).toInt();
    });
    _saveCart();

    _notice('${product.name} added to cart.');
  }

  void _notice(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Colors.red.shade700 : _primaryNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  Future<void> _deductStockInFirestore(Map<Product, int> purchasedItems) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    for (var entry in purchasedItems.entries) {
      final product = entry.key;
      final quantityBought = entry.value;
      final updatedStock = (product.stock - quantityBought).clamp(0, 9999);

      final documentReference = firestore.collection('products').doc(product.id.toString());
      batch.update(documentReference, {'stock': updatedStock});
    }

    await batch.commit();
  }

  Future<void> _startCheckout(
    List<Product> products, {
    Product? buyNowProduct,
  }) async {
    final selectedItems = <Product, int>{};

    if (buyNowProduct != null) {
      selectedItems[buyNowProduct] = 1;
    } else {
      for (final product in products) {
        final quantity = _cart[product.id] ?? 0;
        if (quantity > 0) {
          selectedItems[product] = quantity;
        }
      }
    }

    if (selectedItems.isEmpty) {
      _notice(
        'Your cart is empty. Add school supplies first.',
        isError: true,
      );
      return;
    }

    for (final entry in selectedItems.entries) {
      if (entry.value > entry.key.stock) {
        _notice(
          'Only ${entry.key.stock} unit(s) of ${entry.key.name} are available.',
          isError: true,
        );
        return;
      }
    }

    final customer = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CheckoutDialog(
        itemCount:
            selectedItems.values.fold(0, (sum, quantity) => sum + quantity),
        total: selectedItems.entries.fold<num>(
          0,
          (sum, entry) => sum + entry.key.price * entry.value,
        ),
        money: _money,
      ),
    );

    if (customer == null || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final payloadItems = selectedItems.entries
          .map(
            (entry) => <String, dynamic>{
              'product_id': entry.key.id,
              'name': entry.key.name,
              'quantity': entry.value,
              'price': entry.key.price,
              'imageUrl': entry.key.imageUrl,
            },
          )
          .toList();

      final invoice = await _paymentService.createInvoiceForCart(
        items: payloadItems,
        customerName: customer['name']!,
        customerEmail: customer['email']!,
        customerPhone: customer['phone']!,
        deliveryAddress: customer['address']!,
      );

      final invoiceUrl = invoice['invoice_url'].toString();
      final externalId = invoice['external_id'].toString();

      if (!mounted) return;

      await _deductStockInFirestore(selectedItems);

      if (buyNowProduct == null) {
        setState(() => _cart.clear());
        await _saveCart();
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => XenditWebViewScreen(
            invoiceUrl: invoiceUrl,
          ),
        ),
      );

      final status = await _paymentService.checkOrderStatus(externalId);

      if (!mounted) return;

      _loadProducts();

      if (status.toUpperCase() == 'PAID') {
        _notice('Payment verified. Your order is PAID. Stock updated successfully.');
      } else {
        _notice('Order created. Current status: $status');
      }
    } catch (error) {
      _notice('Checkout failed: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _openCart(List<Product> products) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refreshCart) => _CartSheet(
          products: products,
          cart: Map<int, int>.from(_cart),
          money: _money,
          onQuantityChanged: (id, quantity) {
            setState(() {
              if (quantity <= 0) {
                _cart.remove(id);
              } else {
                Product? product;
                for (final candidate in products) {
                  if (candidate.id == id) {
                    product = candidate;
                    break;
                  }
                }
                _cart[id] = product == null
                    ? quantity
                    : quantity.clamp(1, product.stock).toInt();
              }
            });
            _saveCart();
            refreshCart(() {});
          },
          onRemove: (id) {
            setState(() => _cart.remove(id));
            _saveCart();
            refreshCart(() {});
          },
          onCheckout: () {
            Navigator.pop(dialogContext);
            _startCheckout(products);
          },
        ),
      ),
    );
  }

  void _showProductDetails(Product product) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screenHeight = MediaQuery.of(dialogContext).size.height;
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final imageHeight = (screenHeight * 0.25).clamp(140.0, 220.0);
        final isAvailable = product.stock > 0;

        return Center(
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              width: screenWidth > 600 ? 480 : screenWidth * 0.92,
              constraints: BoxConstraints(
                maxHeight: screenHeight * 0.85,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: _primaryNavy.withOpacity(0.2),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Material(
                  color: Colors.white,
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: imageHeight,
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _imageBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: _ProductImage(
                                url: product.imageUrl,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _accentBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    product.category.toUpperCase(),
                                    style: const TextStyle(
                                      color: _accentBlue,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAvailable
                                        ? _emeraldGreen.withOpacity(0.1)
                                        : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isAvailable
                                            ? Icons.check_circle_rounded
                                            : Icons.cancel_rounded,
                                        size: 14,
                                        color: isAvailable
                                            ? _emeraldGreen
                                            : Colors.red.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isAvailable
                                            ? 'In stock: ${product.stock}'
                                            : 'Out of stock',
                                        style: TextStyle(
                                          color: isAvailable
                                              ? _emeraldGreen
                                              : Colors.red.shade800,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: _primaryNavy,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _money(product.price),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900, 
                                color: _vibrantIndigo,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              product.description,
                              style: const TextStyle(
                                color: _textMuted,
                                height: 1.5,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: !isAvailable
                                        ? null
                                        : () {
                                            Navigator.pop(dialogContext);
                                            _addToCart(product);
                                          },
                                    icon: const Icon(
                                      Icons.add_shopping_cart_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Add to cart',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _accentBlue,
                                      side: const BorderSide(color: _accentBlue, width: 1.8),
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: !isAvailable
                                        ? null
                                        : () {
                                            Navigator.pop(dialogContext);
                                            _startCheckout(
                                              [product],
                                              buyNowProduct: product,
                                            );
                                          },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _accentBlue,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Buy now',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          color: _imageBg,
                          shape: const CircleBorder(),
                          child: IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: _primaryNavy,
                              size: 18,
                            ),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 72,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_accentBlue, _vibrantIndigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _accentBlue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SchoolHub',
                  style: TextStyle(
                    color: _primaryNavy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'PREMIUM SUPPLIES',
                  style: TextStyle(
                    color: _accentBlue,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'My orders',
            icon: const Icon(
              Icons.receipt_long_rounded,
              color: _primaryNavy,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OrdersScreen(),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Shopping cart',
              onPressed: () async {
                try {
                  final snapshot = await _productsFuture;
                  if (mounted) _openCart(snapshot);
                } catch (error) {
                  _notice(
                    'Could not load products for your cart.',
                    isError: true,
                  );
                }
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    color: _primaryNavy,
                    size: 26,
                  ),
                  if (_cartCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        decoration: const BoxDecoration(
                          color: _accentBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_cartCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<List<Product>>(
            future: _productsFuture,
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
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: _accentBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_off_rounded,
                            size: 36,
                            color: _accentBlue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Could not load school supplies',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: _primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _textMuted),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _loadProducts,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accentBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final allProducts = snapshot.data ?? [];

              final categoryList = allProducts
                  .map((product) => product.category.trim())
                  .where((category) => category.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();

              final categories = ['All', ...categoryList];

              final products = allProducts.where((product) {
                final matchesCategory = _selectedCategory == 'All' ||
                    product.category == _selectedCategory;

                final query = _searchQuery.trim().toLowerCase();

                final matchesSearch = query.isEmpty ||
                    product.name.toLowerCase().contains(query) ||
                    product.description.toLowerCase().contains(query) ||
                    product.category.toLowerCase().contains(query);

                return matchesCategory && matchesSearch;
              }).toList();

              return RefreshIndicator(
                color: _accentBlue,
                onRefresh: () async {
                  _loadProducts();
                  try {
                    await _productsFuture;
                  } catch (_) {}
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final horizontalPadding = width < 600 ? 16.0 : 28.0;

                    final columns = width >= 1100
                        ? 4
                        : width >= 750
                            ? 3
                            : 2;

                    final cardAspectRatio = width < 480 ? 0.62 : 0.72;

                    return ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        16,
                        horizontalPadding,
                        32,
                      ),
                      children: [
                        _buildHeroBanner(width),
                        const SizedBox(height: 20),

                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryNavy.withOpacity(0.03),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() => _searchQuery = value);
                            },
                            decoration: InputDecoration(
                              hintText: 'Search school supplies...',
                              hintStyle: const TextStyle(
                                color: _textMuted,
                                fontSize: 13.5,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: _accentBlue,
                                size: 22,
                              ),
                              suffixIcon: _searchQuery.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                      icon: const Icon(Icons.close_rounded, size: 20),
                                    ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Categories Horizontal Filter
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Categories',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: _primaryNavy,
                                ),
                              ),
                            ),
                            Text(
                              '${categories.length - 1} total',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: categories.map((category) {
                              final selected = category == _selectedCategory;

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(category),
                                  selected: selected,
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedCategory = category;
                                    });
                                  },
                                  selectedColor: _primaryNavy,
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: selected ? _primaryNavy : _cardBorder,
                                  ),
                                  labelStyle: TextStyle(
                                    color: selected ? Colors.white : _textMuted,
                                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  showCheckmark: false,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Product Heading
                        Row(
                          key: _productsSectionKey,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Our Products',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: _primaryNavy,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Find essential tools for learning.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _accentBlue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${products.length} ITEMS',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: _accentBlue,
                                  letterSpacing: .5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (products.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _cardBorder),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 44,
                                  color: _textMuted,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No matching school supplies',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: _primaryNavy,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Try another search or category.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: products.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: cardAspectRatio,
                            ),
                            itemBuilder: (context, index) {
                              final product = products[index];
                              final favorite =
                                  _favorites.contains(product.id);
                              final outOfStock = product.stock <= 0;

                              return _ProductCard(
                                product: product,
                                favorite: favorite,
                                outOfStock: outOfStock,
                                money: _money,
                                onOpen: () => _showProductDetails(product),
                                onFavorite: () {
                                  setState(() {
                                    if (favorite) {
                                      _favorites.remove(product.id);
                                    } else {
                                      _favorites.add(product.id);
                                    }
                                  });
                                },
                                onAddToCart: outOfStock
                                    ? null
                                    : () => _addToCart(product),
                                onBuy: outOfStock
                                    ? null
                                    : () => _startCheckout(
                                          products,
                                          buyNowProduct: product,
                                        ),
                              );
                            },
                          ),
                        const SizedBox(height: 28),

                        // Footer
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _cardBorder),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                color: _accentBlue,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SchoolHub',
                                      style: TextStyle(
                                        color: _primaryNavy,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Learn more. Create more.',
                                      style: TextStyle(
                                        color: _textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.favorite_rounded,
                                color: _roseColor,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),

          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(.88),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _accentBlue),
                      SizedBox(height: 16),
                      Text(
                        'Preparing secure checkout...',
                        style: TextStyle(
                          color: _primaryNavy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(double width) {
    final compact = width < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 20 : 30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF2563EB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _accentBlue.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  child: const Text(
                    'SCHOOL SUPPLIES STORE',
                    style: TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  compact
                      ? 'Ready, Set,\nLearn!'
                      : 'Everything you need\nto learn and create.',
                  style: TextStyle(
                    fontSize: compact ? 26 : 34,
                    height: 1.1,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Discover notebooks, pens, art materials and everyday school essentials.',
                  style: TextStyle(
                    color: Color(0xFFE2E8F0),
                    height: 1.4,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _scrollToProducts,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Explore products',
                          style: TextStyle(
                            color: _primaryNavy,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_downward_rounded,
                          color: _accentBlue,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (width >= 500) ...[
            const SizedBox(width: 16),
            Container(
              width: width >= 800 ? 130 : 90,
              height: width >= 800 ? 130 : 90,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
              child: Icon(
                Icons.backpack_rounded,
                size: width >= 800 ? 70 : 50,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool favorite;
  final bool outOfStock;
  final String Function(num) money;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback? onAddToCart;
  final VoidCallback? onBuy;

  const _ProductCard({
    required this.product,
    required this.favorite,
    required this.outOfStock,
    required this.money,
    required this.onOpen,
    required this.onFavorite,
    required this.onAddToCart,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: _primaryNavy.withOpacity(0.03),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Material(
                    color: _imageBg,
                    child: InkWell(
                      onTap: onOpen,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: _ProductImage(
                          url: product.imageUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white.withOpacity(0.9),
                    shape: const CircleBorder(),
                    child: IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      visualDensity: VisualDensity.compact,
                      tooltip: favorite ? 'Remove favorite' : 'Add favorite',
                      onPressed: onFavorite,
                      icon: Icon(
                        favorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: favorite ? _roseColor : _primaryNavy,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                if (outOfStock)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'OUT OF STOCK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.category.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: _textMuted,
                    letterSpacing: .6,
                  ),
                ),
                const SizedBox(height: 3),
                InkWell(
                  onTap: onOpen,
                  child: Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: _primaryNavy,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  outOfStock ? 'Unavailable' : '${product.stock} available',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: outOfStock ? Colors.red : _emeraldGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  money(product.price),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _vibrantIndigo,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          onPressed: onAddToCart,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: _accentBlue,
                            side: const BorderSide(color: _accentBlue, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: FilledButton(
                          onPressed: onBuy,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accentBlue,
                            disabledBackgroundColor: const Color(0xFFCBD5E1),
                            padding: EdgeInsets.zero,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Buy',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const _ProductImage({
    required this.url,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = url.trim();

    if (imageUrl.isEmpty) {
      return const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: _accentBlue,
          size: 40,
        ),
      );
    }

    // Always display the URL stored in Firestore. Do not silently substitute
    // another product image when the supplied URL fails to load.
    return Image.network(
      imageUrl,
      key: ValueKey(imageUrl),
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _accentBlue,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: _textMuted,
            size: 40,
          ),
        );
      },
    );
  }
}

class _CheckoutDialog extends StatefulWidget {
  final int itemCount;
  final num total;
  final String Function(num) money;

  const _CheckoutDialog({
    required this.itemCount,
    required this.total,
    required this.money,
  });

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
        ? 'This field is required'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: const Text(
        'Delivery & Checkout',
        style: TextStyle(
          color: _primaryNavy,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _accentBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        color: _accentBlue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${widget.itemCount} item(s)',
                          style: const TextStyle(
                            color: _primaryNavy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        widget.money(widget.total),
                        style: const TextStyle(
                          color: _accentBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _CheckoutField(
                  controller: _name,
                  label: 'Full name',
                  icon: Icons.person_outline_rounded,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                _CheckoutField(
                  controller: _email,
                  label: 'Email address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'This field is required';
                    }

                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(value.trim())) {
                      return 'Enter a valid email';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _CheckoutField(
                  controller: _phone,
                  label: 'Mobile number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                _CheckoutField(
                  controller: _address,
                  label: 'Complete delivery address',
                  icon: Icons.location_on_outlined,
                  maxLines: 3,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your order will be sent to Xendit for payment process.',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: _textMuted)),
        ),
        FilledButton.icon(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;

            Navigator.pop(context, {
              'name': _name.text.trim(),
              'email': _email.text.trim(),
              'phone': _phone.text.trim(),
              'address': _address.text.trim(),
            });
          },
          icon: const Icon(Icons.lock_outline_rounded, size: 16),
          label: const Text('Continue to payment'),
          style: FilledButton.styleFrom(
            backgroundColor: _accentBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckoutField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final int maxLines;

  const _CheckoutField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: _textMuted),
        filled: true,
        fillColor: _bgCanvas,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accentBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}

class _CartSheet extends StatelessWidget {
  final List<Product> products;
  final Map<int, int> cart;
  final String Function(num) money;
  final void Function(int id, int quantity) onQuantityChanged;
  final void Function(int id) onRemove;
  final VoidCallback onCheckout;

  const _CartSheet({
    required this.products,
    required this.cart,
    required this.money,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final entries = cart.entries
        .map((entry) {
          final matches = products.where((p) => p.id == entry.key);
          return matches.isEmpty
              ? null
              : MapEntry(matches.first, entry.value);
        })
        .whereType<MapEntry<Product, int>>()
        .toList();

    final total = entries.fold<num>(
      0,
      (sum, entry) => sum + entry.key.price * entry.value,
    );

    return Center(
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: screenWidth > 600 ? 500 : screenWidth * 0.92,
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.85,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _primaryNavy.withOpacity(0.2),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Material(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Shopping Cart',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _primaryNavy,
                            ),
                          ),
                        ),
                        Text(
                          '${entries.fold<int>(0, (sum, e) => sum + e.value)} item(s)',
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: _primaryNavy),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: _cardBorder),
                  Flexible(
                    child: entries.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(36),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 48,
                                  color: _textMuted,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Your cart is empty',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: _primaryNavy,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Add a few school essentials to get started.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(16),
                            itemCount: entries.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 20, color: _cardBorder),
                            itemBuilder: (context, index) {
                              final product = entries[index].key;
                              final quantity = entries[index].value;

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: Container(
                                        color: _imageBg,
                                        padding: const EdgeInsets.all(6),
                                        child: _ProductImage(
                                          url: product.imageUrl,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: _primaryNavy,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          money(product.price),
                                          style: const TextStyle(
                                            color: _vibrantIndigo,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            IconButton(
                                              onPressed: () =>
                                                  onQuantityChanged(
                                                product.id,
                                                quantity - 1,
                                              ),
                                              constraints: const BoxConstraints(),
                                              padding: EdgeInsets.zero,
                                              icon: const Icon(
                                                Icons.remove_circle_outline_rounded,
                                                size: 20,
                                                color: _textMuted,
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              child: Text(
                                                '$quantity',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: quantity >= product.stock
                                                  ? null
                                                  : () => onQuantityChanged(
                                                        product.id,
                                                        quantity + 1,
                                                      ),
                                              constraints: const BoxConstraints(),
                                              padding: EdgeInsets.zero,
                                              icon: const Icon(
                                                Icons.add_circle_outline_rounded,
                                                size: 20,
                                                color: _accentBlue,
                                              ),
                                            ),
                                            const Spacer(),
                                            IconButton(
                                              onPressed: () =>
                                                  onRemove(product.id),
                                              constraints: const BoxConstraints(),
                                              padding: EdgeInsets.zero,
                                              tooltip: 'Remove item',
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: Colors.redAccent,
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: _cardBorder)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Subtotal',
                                style: TextStyle(
                                  color: _textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              money(total),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _primaryNavy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: entries.isEmpty ? null : onCheckout,
                            icon: const Icon(Icons.lock_outline_rounded, size: 16),
                            label: const Text(
                              'Checkout Securely',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _accentBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}