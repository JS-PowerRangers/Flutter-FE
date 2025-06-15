// Model class for Product, with helpers for SQLite mapping.
class Product {
  final String name;
  int quantity;
  double price;

  Product(this.name, this.quantity, this.price);

  // Convert object → Map<String, dynamic> for SQLite
  Map<String, dynamic> toMap() => {
    'name': name,
    'quantity': quantity,
    'price': price,
  };

  // Construct object ← Map<String, dynamic> from SQLite
  factory Product.fromMap(Map<String, dynamic> m) => Product(
    m['name'] as String,
    m['quantity'] as int,
    (m['price'] as num).toDouble(),
  );

  @override
  String toString() => 'Product{name: $name, qty: $quantity, price: $price}';
}
