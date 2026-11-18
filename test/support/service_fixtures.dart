import 'dart:convert';
import 'dart:io';

import 'package:servora/features/services/domain/service.dart';

/// The real JSON the backend returned for GET /services?limit=50 (10 seeded services).
Map<String, dynamic> realServicesPage() =>
    jsonDecode(File('test/fixtures/services_page.json').readAsStringSync())
        as Map<String, dynamic>;

/// The real JSON the backend returned for GET /services/:id.
Map<String, dynamic> realServiceDetail() =>
    jsonDecode(File('test/fixtures/service_detail.json').readAsStringSync())
        as Map<String, dynamic>;

/// The ten real services, parsed.
List<Service> realServices() => [
  for (final item in realServicesPage()['data'] as List<dynamic>)
    Service.fromJson(item as Map<String, dynamic>),
];

/// A small hand-made service for tests that need exact, readable values.
Service makeService({
  String id = 's-1',
  String name = 'Test Service',
  String description = 'A service used in a test.',
  double price = 50,
  int durationMinutes = 60,
  String category = 'Wellness',
  String? imageUrl = 'https://img.test/s-1.jpg',
  bool isFeatured = false,
}) => Service(
  id: id,
  name: name,
  description: description,
  price: price,
  durationMinutes: durationMinutes,
  category: category,
  imageUrl: imageUrl,
  isFeatured: isFeatured,
);
