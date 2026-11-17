/// A bookable service, as the API returns it.
class Service {
  const Service({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMinutes,
    required this.category,
    required this.isFeatured,
    this.imageUrl,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      // The API sends a plain number (65 or 49.99), which can arrive as int or double.
      price: (json['price'] as num).toDouble(),
      durationMinutes: json['durationMinutes'] as int,
      category: json['category'] as String,
      imageUrl: json['imageUrl'] as String?,
      isFeatured: json['isFeatured'] as bool,
    );
  }

  final String id;
  final String name;
  final String description;

  /// Price in the shop's currency, for example 65 or 49.99.
  final double price;
  final int durationMinutes;
  final String category;

  /// Absolute URL of the picture, or null when the service has none.
  final String? imageUrl;
  final bool isFeatured;

  @override
  bool operator ==(Object other) =>
      other is Service &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.price == price &&
      other.durationMinutes == durationMinutes &&
      other.category == category &&
      other.imageUrl == imageUrl &&
      other.isFeatured == isFeatured;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    price,
    durationMinutes,
    category,
    imageUrl,
    isFeatured,
  );
}
