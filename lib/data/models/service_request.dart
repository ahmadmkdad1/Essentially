import 'enums.dart';
import 'json_utils.dart';
import 'user.dart';

class RequestListingSummary {
  const RequestListingSummary({
    required this.id,
    required this.title,
    required this.price,
    required this.priceUnit,
    required this.currency,
    required this.address,
    this.categoryName,
  });

  final String id;
  final String title;
  final double price;
  final PriceUnit priceUnit;
  final String currency;
  final String address;
  final String? categoryName;

  factory RequestListingSummary.fromJson(Json json) => RequestListingSummary(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    price: toDouble(json['price']),
    priceUnit: PriceUnit.parse(json['priceUnit']),
    currency: json['currency'] as String? ?? 'USD',
    address: json['address'] as String? ?? '',
    categoryName: json['categoryName'] as String?,
  );
}

class RequestParty {
  const RequestParty({required this.id, required this.name, this.phone});
  final String id;
  final String name;
  final String? phone;
}

class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.listingId,
    required this.customerId,
    required this.providerId,
    required this.status,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.quotedPrice,
    required this.createdAt,
    required this.hasReview,
    this.message,
    this.preferredDate,
    this.providerNote,
    this.respondedAt,
    this.completedAt,
    this.cancelledAt,
    this.listing,
    this.customer,
    this.provider,
    this.distanceKm,
  });

  final String id;
  final String listingId;
  final String customerId;
  final String providerId;
  final RequestStatus status;
  final String? message;
  final DateTime? preferredDate;
  final String address;
  final double latitude;
  final double longitude;
  final double quotedPrice;
  final String? providerNote;
  final DateTime? respondedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final RequestListingSummary? listing;
  final RequestParty? customer;
  final PublicProvider? provider;
  final double? distanceKm;
  final bool hasReview;

  String get title => listing?.title ?? 'Removed service';
  String get currency => listing?.currency ?? 'USD';
  PriceUnit get priceUnit => listing?.priceUnit ?? PriceUnit.fixed;

  factory ServiceRequest.fromJson(Json json) {
    final customer = json['customer'] as Json?;
    return ServiceRequest(
      id: json['id'] as String,
      listingId: json['listingId'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      providerId: json['providerId'] as String? ?? '',
      status: RequestStatus.parse(json['status']),
      message: json['message'] as String?,
      preferredDate: toDateOrNull(json['preferredDate']),
      address: json['address'] as String? ?? '',
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
      quotedPrice: toDouble(json['quotedPrice']),
      providerNote: json['providerNote'] as String?,
      respondedAt: toDateOrNull(json['respondedAt']),
      completedAt: toDateOrNull(json['completedAt']),
      cancelledAt: toDateOrNull(json['cancelledAt']),
      createdAt: toDate(json['createdAt']),
      listing: json['listing'] is Map ? RequestListingSummary.fromJson(json['listing'] as Json) : null,
      customer:
          customer == null
              ? null
              : RequestParty(
                id: customer['id'] as String,
                name: customer['fullName'] as String? ?? 'Customer',
                phone: customer['phone'] as String?,
              ),
      provider: json['provider'] is Map ? PublicProvider.fromJson(json['provider'] as Json) : null,
      distanceKm: toDoubleOrNull(json['distanceKm']),
      hasReview: json['hasReview'] as bool? ?? false,
    );
  }
}

class ProviderStats {
  const ProviderStats({
    required this.requests,
    required this.totalRequests,
    required this.completedRevenue,
    required this.activeListings,
    required this.totalListings,
    required this.ratingCount,
    this.acceptanceRate,
    this.ratingAverage,
  });

  final Map<RequestStatus, int> requests;
  final int totalRequests;
  final double completedRevenue;
  final double? acceptanceRate;
  final int activeListings;
  final int totalListings;
  final double? ratingAverage;
  final int ratingCount;

  int count(RequestStatus s) => requests[s] ?? 0;

  factory ProviderStats.fromJson(Json json) {
    final raw = json['requests'] as Json? ?? const {};
    return ProviderStats(
      requests: {for (final s in RequestStatus.values) s: toInt(raw[s.api])},
      totalRequests: toInt(json['totalRequests']),
      completedRevenue: toDouble(json['completedRevenue']),
      acceptanceRate: toDoubleOrNull(json['acceptanceRate']),
      activeListings: toInt(json['activeListings']),
      totalListings: toInt(json['totalListings']),
      ratingAverage: toDoubleOrNull(json['ratingAverage']),
      ratingCount: toInt(json['ratingCount']),
    );
  }
}
