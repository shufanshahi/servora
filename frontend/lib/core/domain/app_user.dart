/// The signed-in user, as the API returns it. Never contains credentials.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String name;
  final String email;
  final DateTime createdAt;

  AppUser copyWith({String? name}) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.name == name &&
      other.email == email &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, email, createdAt);
}
