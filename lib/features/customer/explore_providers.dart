import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../data/models/json_utils.dart';
import '../../data/models/listing.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../common/location_controller.dart';

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(marketplaceRepositoryProvider).categories(),
);

class ExploreFilters {
  const ExploreFilters({
    this.categoryId,
    this.search = '',
    this.radiusKm = 25,
    this.sort = ListingSort.distance,
    this.limit = 20,
  });

  final String? categoryId;
  final String search;
  final double radiusKm;
  final ListingSort sort;
  final int limit;

  ExploreFilters copyWith({
    String? Function()? categoryId,
    String? search,
    double? radiusKm,
    ListingSort? sort,
    int? limit,
  }) => ExploreFilters(
    categoryId: categoryId != null ? categoryId() : this.categoryId,
    search: search ?? this.search,
    radiusKm: radiusKm ?? this.radiusKm,
    sort: sort ?? this.sort,
    // Any filter change resets pagination.
    limit: limit ?? 20,
  );
}

class ExploreFiltersController extends Notifier<ExploreFilters> {
  @override
  ExploreFilters build() => const ExploreFilters();

  void setCategory(String? id) => state = state.copyWith(categoryId: () => id);
  void setSearch(String q) => state = state.copyWith(search: q.trim());
  void setRadius(double km) => state = state.copyWith(radiusKm: km);
  void setSort(ListingSort sort) => state = state.copyWith(sort: sort);
  void loadMore() => state = state.copyWith(limit: (state.limit + 20).clamp(20, 100));
}

final exploreFiltersProvider = NotifierProvider<ExploreFiltersController, ExploreFilters>(ExploreFiltersController.new);

/// Nearby services for the current location + filters.
final exploreResultsProvider = FutureProvider.autoDispose<Paginated<Listing>>((ref) {
  final location = ref.watch(locationControllerProvider.select((s) => s.point));
  final filters = ref.watch(exploreFiltersProvider);
  return ref
      .watch(marketplaceRepositoryProvider)
      .search(
        ListingQuery(
          latitude: location.latitude,
          longitude: location.longitude,
          radiusKm: filters.radiusKm,
          categoryId: filters.categoryId,
          search: filters.search.isEmpty ? null : filters.search,
          sort: filters.sort,
          limit: filters.limit,
        ),
      );
});
