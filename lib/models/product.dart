class Product {
  final int id;
  final String name;
  final double price;
  final int stockQuantity;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stockQuantity,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      price: double.parse(json['price'].toString()),
      stockQuantity: json['stock_quantity'],
    );
  }

  Product copyWith({
    String? name,
    double? price,
    int? stockQuantity,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      stockQuantity: stockQuantity ?? this.stockQuantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'stock_quantity': stockQuantity,
    };
  }
}
