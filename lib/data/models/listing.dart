import 'enums.dart';
import 'json_utils.dart';
import 'user.dart';

class Category {
  const Category({required this.id, required this.name, required this.slug, required this.icon, this.description = ''});

  final String id;
  final String name;
  final String slug;
  final String icon;
  final String description;

  factory Category.fromJson(Json json) => Category(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    icon: json['icon'] as String? ?? '',
    description: json['description'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) => other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class Listing {
  const Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.priceUnit,
    required this.currency,
    required this.categoryId,
    required this.providerId,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.serviceRadiusKm,
    required this.status,
    required this.ratingAverage,
    required this.ratingCount,
    required this.createdAt,
    this.category,
    this.provider,
    this.removalReason,
    this.distanceKm,
    this.withinServiceArea,
    this.openReports = 0,
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final PriceUnit priceUnit;
  final String currency;
  final String categoryId;
  final Category? category;
  final String providerId;
  final PublicProvider? provider;
  final double latitude;
  final double longitude;
  final String address;
  final int serviceRadiusKm;
  final ListingStatus status;
  final String? removalReason;
  final double ratingAverage;
  final int ratingCount;
  final double? distanceKm;
  final bool? withinServiceArea;
  final DateTime createdAt;

  /// Admin views only.
  final int openReports;

  factory Listing.fromJson(Json json) => Listing(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    price: toDouble(json['price']),
    priceUnit: PriceUnit.parse(json['priceUnit']),
    currency: json['currency'] as String? ?? 'USD',
    categoryId: json['categoryId'] as String? ?? '',
    category: json['category'] is Map ? Category.fromJson(json['category'] as Json) : null,
    providerId: json['providerId'] as String? ?? '',
    provider: json['provider'] is Map ? PublicProvider.fromJson(json['provider'] as Json) : null,
    latitude: toDouble(json['latitude']),
    longitude: toDouble(json['longitude']),
    address: json['address'] as String? ?? '',
    serviceRadiusKm: toInt(json['serviceRadiusKm'], 15),
    status: ListingStatus.parse(json['status']),
    removalReason: json['removalReason'] as String?,
    ratingAverage: toDouble(json['ratingAverage']),
    ratingCount: toInt(json['ratingCount']),
    distanceKm: toDoubleOrNull(json['distanceKm']),
    withinServiceArea: json['withinServiceArea'] as bool?,
    createdAt: toDate(json['createdAt']),
    openReports: toInt(json['openReports']),
  );
}

class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.authorName,
    required this.listingId,
    this.listingTitle,
  });

  final String id;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final String authorName;
  final String listingId;
  final String? listingTitle;

  factory Review.fromJson(Json json) => Review(
    id: json['id'] as String,
    rating: toInt(json['rating']),
    comment: json['comment'] as String? ?? '',
    createdAt: toDate(json['createdAt']),
    authorName: (json['author'] as Json?)?['fullName'] as String? ?? 'Customer',
    listingId: json['listingId'] as String? ?? '',
    listingTitle: json['listingTitle'] as String?,
  );
}

class ProviderProfile {
  const ProviderProfile({
    required this.provider,
    required this.listings,
    required this.reviews,
    required this.completedJobs,
    required this.ratingAverage,
    required this.ratingCount,
  });

  final PublicProvider provider;
  final List<Listing> listings;
  final List<Review> reviews;
  final int completedJobs;
  final double? ratingAverage;
  final int ratingCount;

  factory ProviderProfile.fromJson(Json json) {
    final stats = json['stats'] as Json? ?? const {};
    return ProviderProfile(
      provider: PublicProvider.fromJson(json['provider'] as Json),
      listings: (json['listings'] as List? ?? const []).map((e) => Listing.fromJson(e as Json)).toList(),
      reviews: (json['reviews'] as List? ?? const []).map((e) => Review.fromJson(e as Json)).toList(),
      completedJobs: toInt(stats['completedJobs']),
      ratingAverage: toDoubleOrNull(stats['ratingAverage']),
      ratingCount: toInt(stats['ratingCount']),
    );
  }
}
