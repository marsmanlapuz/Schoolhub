
class Product {
  final int id;
  final String name;
  final num price;
  final String imageUrl;
  final String category;
  final String description;
  final int stock;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.category = 'General',
    this.description = 'Quality school supply for students.',
    this.stock = 100,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    final dynamic rawId = map['id'];
    final dynamic rawPrice = map['price'];
    final dynamic rawStock = map['stock'];

    return Product(
      id: rawId is num
          ? rawId.toInt()
          : int.tryParse(rawId?.toString() ?? '') ?? 0,
      name: map['name']?.toString() ?? 'Unnamed Item',
      price: rawPrice is num
          ? rawPrice
          : num.tryParse(rawPrice?.toString() ?? '') ?? 0,
      imageUrl: (
        map['imageUrl'] ?? map['image_url'] ?? ''
      ).toString().trim(),
      category: map['category']?.toString() ?? 'General',
      description: map['description']?.toString() ??
          'Quality school supply for students.',
      stock: rawStock is num
          ? rawStock.toInt()
          : int.tryParse(rawStock?.toString() ?? '') ?? 100,
    );
  }
}
