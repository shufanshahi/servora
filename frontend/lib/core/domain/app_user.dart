/// The signed-in user, as the API returns it. Never contains credentials.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
    this.phone,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      // Absent in sessions saved by an older version of the app.
      phone: json['phone'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String name;
  final String email;

  /// Contact number, or null when none is set.
  final String? phone;
  final DateTime createdAt;

  /// A copy with a new name and/or phone. Pass [clearPhone] to remove the phone.
  AppUser copyWith({String? name, String? phone, bool clearPhone = false}) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: clearPhone ? null : (phone ?? this.phone),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.name == name &&
      other.email == email &&
      other.phone == phone &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, email, phone, createdAt);
}
