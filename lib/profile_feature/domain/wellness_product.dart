/// A product a wellness centre sells (`users/{id}/products/{productId}`).
class WellnessProduct {
  final String id;
  final String name;

  /// As the owner typed it, e.g. "1499".
  final String price;
  final String imageUrl;

  const WellnessProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
  });

  factory WellnessProduct.fromMap(String id, Map<String, dynamic> map) {
    String text(Object? v) => v == null ? '' : v.toString().trim();
    return WellnessProduct(
      id: id,
      name: text(map['name']),
      price: text(map['price']),
      imageUrl: text(map['imageUrl']),
    );
  }
}
