import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/enums.dart';
import '../models/json_utils.dart';
import '../models/listing.dart';
import '../models/moderation.dart';

class ListingQuery {
  const ListingQuery({
    this.latitude,
    this.longitude,
    this.radiusKm = 25,
    this.categoryId,
    this.search,
    this.sort = ListingSort.distance,
    this.page = 1,
    this.limit = 20,
  });

  final double? latitude;
  final double? longitude;
  final double radiusKm;
  final String? categoryId;
  final String? search;
  final ListingSort sort;
  final int page;
  final int limit;

  Map<String, dynamic> toQuery() => {
    'lat': latitude,
    'lng': longitude,
    'radiusKm': radiusKm.round(),
    'categoryId': categoryId,
    'q': search,
    'sort': sort.api,
    'page': page,
    'limit': limit,
  };

  @override
  bool operator ==(Object other) =>
      other is ListingQuery &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.radiusKm == radiusKm &&
      other.categoryId == categoryId &&
      other.search == search &&
      other.sort == sort &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(latitude, longitude, radiusKm, categoryId, search, sort, page, limit);
}

class ListingInput {
  const ListingInput({
    required this.title,
    required this.description,
    required this.price,
    required this.priceUnit,
    required this.categoryId,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.serviceRadiusKm,
    this.currency = 'USD',
  });

  final String title;
  final String description;
  final double price;
  final PriceUnit priceUnit;
  final String currency;
  final String categoryId;
  final double latitude;
  final double longitude;
  final String address;
  final int serviceRadiusKm;

  Json toJson() => {
    'title': title.trim(),
    'description': description.trim(),
    'price': double.parse(price.toStringAsFixed(2)),
    'priceUnit': priceUnit.api,
    'currency': currency,
    'categoryId': categoryId,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'serviceRadiusKm': serviceRadiusKm,
  };
}

class MarketplaceRepository {
  MarketplaceRepository(this._api);
  final ApiClient _api;

  Future<List<Category>> categories() async {
    final list = await _api.get<List<dynamic>>('/categories');
    return list.map((e) => Category.fromJson(e as Json)).toList();
  }

  Future<Paginated<Listing>> search(ListingQuery query) async {
    final json = await _api.get<Json>('/services', query: query.toQuery());
    return Paginated.fromJson(json, Listing.fromJson);
  }

  Future<Listing> listing(String id, {double? latitude, double? longitude}) async {
    final json = await _api.get<Json>('/services/$id', query: {'lat': latitude, 'lng': longitude});
    return Listing.fromJson(json);
  }

  Future<ProviderProfile> providerProfile(String id) async =>
      ProviderProfile.fromJson(await _api.get<Json>('/providers/$id'));

  Future<Paginated<Review>> reviews({String? listingId, String? providerId, int page = 1}) async {
    final json = await _api.get<Json>(
      '/reviews',
      query: {'listingId': listingId, 'providerId': providerId, 'page': page, 'limit': 20},
    );
    return Paginated.fromJson(json, Review.fromJson);
  }

  Future<void> createReview(String requestId, int rating, String comment) async {
    await _api.post<Json>(
      '/reviews',
      body: {'requestId': requestId, 'rating': rating, if (comment.trim().isNotEmpty) 'comment': comment.trim()},
    );
  }

  // Provider-side ------------------------------------------------------------

  Future<List<Listing>> myListings() async {
    final list = await _api.get<List<dynamic>>('/services/mine');
    return list.map((e) => Listing.fromJson(e as Json)).toList();
  }

  Future<Listing> createListing(ListingInput input) async =>
      Listing.fromJson(await _api.post<Json>('/services', body: input.toJson()));

  Future<Listing> updateListing(String id, ListingInput input) async =>
      Listing.fromJson(await _api.patch<Json>('/services/$id', body: input.toJson()));

  Future<Listing> setListingStatus(String id, ListingStatus status) async =>
      Listing.fromJson(await _api.patch<Json>('/services/$id/status', body: {'status': status.api}));

  Future<void> deleteListing(String id) => _api.delete<dynamic>('/services/$id');

  // Reports --------------------------------------------------------------------

  Future<void> report({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    required String details,
  }) async {
    await _api.post<Json>(
      '/reports',
      body: {'targetType': targetType.api, 'targetId': targetId, 'reason': reason.api, 'details': details.trim()},
    );
  }

  Future<Paginated<MyReport>> myReports() async {
    final json = await _api.get<Json>('/reports/mine', query: {'limit': 50});
    return Paginated.fromJson(json, MyReport.fromJson);
  }
}

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>(
  (ref) => MarketplaceRepository(ref.watch(apiClientProvider)),
);
