import 'package:essentially/core/router/routes.dart';
import 'package:essentially/core/utils/formatters.dart';
import 'package:essentially/core/utils/validators.dart';
import 'package:essentially/data/models/enums.dart';
import 'package:essentially/data/models/listing.dart';
import 'package:essentially/data/models/moderation.dart';
import 'package:essentially/data/models/service_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('role-based route access', () {
    test('customers can only reach customer and shared screens', () {
      expect(Routes.allowed(Role.user, Routes.explore), isTrue);
      expect(Routes.allowed(Role.user, Routes.service('abc')), isTrue);
      expect(Routes.allowed(Role.user, Routes.dashboard), isFalse);
      expect(Routes.allowed(Role.user, Routes.adminReports), isFalse);
    });

    test('providers cannot open the admin area', () {
      expect(Routes.allowed(Role.provider, Routes.newService), isTrue);
      expect(Routes.allowed(Role.provider, Routes.editService('1')), isTrue);
      expect(Routes.allowed(Role.provider, Routes.adminUser('1')), isFalse);
      expect(Routes.allowed(Role.provider, Routes.explore), isFalse);
    });

    test('admins reach every moderation screen', () {
      expect(Routes.allowed(Role.admin, Routes.adminReport('r1')), isTrue);
      expect(Routes.allowed(Role.admin, Routes.adminAudit), isTrue);
      expect(Routes.allowed(Role.admin, Routes.requests), isFalse);
    });

    test('prefixes do not leak across similar paths', () {
      expect(Routes.allowed(Role.user, '/requests-admin'), isFalse);
    });
  });

  group('validators mirror API rules', () {
    test('password requires 8+ chars with a letter and a digit', () {
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('onlyletters'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password('Secret123'), isNull);
    });

    test('email and phone', () {
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email('a@b.co'), isNull);
      expect(Validators.optionalPhone(''), isNull);
      expect(Validators.optionalPhone('+961 70 123 456'), isNull);
      expect(Validators.optionalPhone('abc'), isNotNull);
    });
  });

  group('formatters', () {
    test('distance switches units', () {
      expect(Fmt.distance(0.35), '350 m');
      expect(Fmt.distance(2.345), '2.3 km');
      expect(Fmt.distance(42.6), '43 km');
    });

    test('prices include billing unit', () {
      expect(Fmt.price(45, 'USD', PriceUnit.monthly), r'$45/mo');
      expect(Fmt.price(12.5, 'USD', PriceUnit.fixed), r'$12.50');
    });
  });

  group('JSON parsing', () {
    test('listing parses decimals sent as strings and nested provider', () {
      final l = Listing.fromJson({
        'id': 'l1',
        'title': 'Gas refill',
        'description': 'desc',
        'price': '12.50',
        'priceUnit': 'FIXED',
        'currency': 'USD',
        'categoryId': 'c1',
        'category': {'id': 'c1', 'name': 'Gas', 'slug': 'gas', 'icon': 'gas'},
        'providerId': 'p1',
        'provider': {'id': 'p1', 'fullName': 'Karim', 'businessName': 'Cedar Gas'},
        'latitude': 33.89,
        'longitude': 35.5,
        'address': 'Beirut',
        'serviceRadiusKm': 12,
        'status': 'ACTIVE',
        'ratingAverage': '4.50',
        'ratingCount': 2,
        'distanceKm': 1.2,
        'withinServiceArea': true,
        'createdAt': '2026-10-01T10:00:00.000Z',
      });
      expect(l.price, 12.5);
      expect(l.ratingAverage, 4.5);
      expect(l.provider!.displayName, 'Cedar Gas');
      expect(l.category!.slug, 'gas');
    });

    test('request parses status and counterpart', () {
      final r = ServiceRequest.fromJson({
        'id': 'r1',
        'listingId': 'l1',
        'customerId': 'u1',
        'providerId': 'p1',
        'status': 'ACCEPTED',
        'address': 'Hamra',
        'latitude': 33.9,
        'longitude': 35.48,
        'quotedPrice': 40,
        'createdAt': '2026-10-01T10:00:00.000Z',
        'customer': {'id': 'u1', 'fullName': 'Lina', 'phone': '+961'},
        'hasReview': false,
      });
      expect(r.status, RequestStatus.accepted);
      expect(r.status.isOpen, isTrue);
      expect(r.customer!.name, 'Lina');
      expect(r.title, 'Removed service');
    });

    test('moderation enums round-trip their API names', () {
      for (final a in ModerationAction.values) {
        expect(ModerationAction.parse(a.api), a);
      }
      for (final r in ReportReason.values) {
        expect(ReportReason.parse(r.api), r);
      }
    });

    test('admin stats default missing buckets to zero', () {
      final s = AdminStats.fromJson({
        'users': {
          'byRole': {'USER': 3},
          'byStatus': {},
          'newThisWeek': 1,
        },
        'listings': {
          'byStatus': {'ACTIVE': 5},
        },
        'requests': {'byStatus': {}, 'newThisWeek': 0},
        'reports': {
          'byStatus': {'OPEN': 2},
          'newThisWeek': 2,
        },
      });
      expect(s.usersByRole[Role.provider], 0);
      expect(s.totalUsers, 3);
      expect(s.reportsByStatus[ReportStatus.open], 2);
    });
  });
}
