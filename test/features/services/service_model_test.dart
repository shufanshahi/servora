import 'package:flutter_test/flutter_test.dart';
import 'package:servora/features/services/domain/service.dart';
import 'package:servora/features/services/domain/service_filter.dart';

import '../../support/service_fixtures.dart';

void main() {
  group('Service.fromJson with the real API payload', () {
    final data = realServicesPage()['data'] as List<dynamic>;

    test('parses every one of the ten seeded services', () {
      final services = [
        for (final item in data) Service.fromJson(item as Map<String, dynamic>),
      ];
      expect(services, hasLength(10));
      expect(services.map((s) => s.id).toSet(), hasLength(10));
    });

    test('keeps every field the API sends', () {
      final first = Service.fromJson(data.first as Map<String, dynamic>);
      final json = data.first as Map<String, dynamic>;
      expect(first.id, json['id']);
      expect(first.name, json['name']);
      expect(first.description, json['description']);
      expect(first.price, (json['price'] as num).toDouble());
      expect(first.durationMinutes, json['durationMinutes']);
      expect(first.category, json['category']);
      expect(first.imageUrl, json['imageUrl']);
      expect(first.isFeatured, json['isFeatured']);
    });

    test('every real service has the data the screens need', () {
      for (final s in realServices()) {
        expect(s.name, isNotEmpty, reason: s.id);
        expect(s.description.length, greaterThan(20), reason: s.name);
        expect(s.price, greaterThan(0), reason: s.name);
        expect([30, 45, 60, 90], contains(s.durationMinutes), reason: s.name);
        expect(s.imageUrl, startsWith('http'), reason: s.name);
      }
    });

    test('exposes four categories and some featured services', () {
      final services = realServices();
      expect(services.map((s) => s.category).toSet(), hasLength(4));
      expect(services.where((s) => s.isFeatured), isNotEmpty);
    });

    test('the detail payload parses to the same service as the list entry', () {
      final detail = Service.fromJson(
        realServiceDetail()['data'] as Map<String, dynamic>,
      );
      final fromList = realServices().firstWhere((s) => s.id == detail.id);
      expect(detail, fromList);
    });
  });

  group('Service.fromJson edge cases', () {
    Map<String, dynamic> base() => {
      'id': 'x',
      'name': 'N',
      'description': 'D',
      'price': 65,
      'durationMinutes': 30,
      'category': 'C',
      'imageUrl': null,
      'isFeatured': false,
    };

    test('accepts whole-number and decimal prices', () {
      expect(Service.fromJson({...base(), 'price': 65}).price, 65.0);
      expect(Service.fromJson({...base(), 'price': 49.99}).price, 49.99);
    });

    test('a null image is allowed', () {
      expect(Service.fromJson(base()).imageUrl, isNull);
    });

    test('a missing required field fails loudly', () {
      for (final key in [
        'id',
        'name',
        'price',
        'durationMinutes',
        'category',
      ]) {
        final json = base()..remove(key);
        expect(() => Service.fromJson(json), throwsA(anything), reason: key);
      }
    });

    test('equality compares every field', () {
      expect(Service.fromJson(base()), Service.fromJson(base()));
      expect(
        Service.fromJson(base()),
        isNot(Service.fromJson({...base(), 'price': 66})),
      );
    });
  });

  group('ServiceFilter', () {
    test('an empty filter changes nothing', () {
      expect(const ServiceFilter().isEmpty, isTrue);
      expect(const ServiceFilter(query: '   ').isEmpty, isTrue);
      expect(const ServiceFilter(query: 'a').isEmpty, isFalse);
      expect(const ServiceFilter(category: 'Home').isEmpty, isFalse);
    });

    test('is a value object that ignores surrounding spaces in the query', () {
      expect(
        const ServiceFilter(query: 'yoga'),
        const ServiceFilter(query: ' yoga '),
      );
      expect(
        const ServiceFilter(query: 'yoga').hashCode,
        const ServiceFilter(query: ' yoga ').hashCode,
      );
      expect(
        const ServiceFilter(query: 'a'),
        isNot(const ServiceFilter(query: 'b')),
      );
    });

    test('withQuery and withCategory change one field and keep the other', () {
      const filter = ServiceFilter(query: 'a', category: 'Home');
      expect(filter.withQuery('b').category, 'Home');
      expect(filter.withCategory(null).query, 'a');
      expect(filter.withCategory(null).category, isNull);
    });
  });
}
