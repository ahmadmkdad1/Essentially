import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/category_style.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/map_widgets.dart';
import '../../data/models/enums.dart';
import '../../data/models/listing.dart';
import '../auth/auth_controller.dart';
import '../common/location_controller.dart';
import '../common/location_picker_screen.dart';
import '../shell/role_shell.dart';
import 'explore_providers.dart';
import 'listing_card.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  bool _mapView = false;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(exploreFiltersProvider).search;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(locationControllerProvider.notifier).autoLocateIfNeeded(),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => ref.read(exploreFiltersProvider.notifier).setSearch(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(locationControllerProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        ref.read(locationControllerProvider.notifier).clearError();
      }
    });

    final results = ref.watch(exploreResultsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GreetingHeader(subtitle: 'What do you need at home today?'),
          const SizedBox(height: 16),
          const _LocationChip(),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: _onSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search gas, water, internet, repairs…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon:
                  _search.text.isEmpty
                      ? null
                      : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          _onSearch('');
                          setState(() {});
                        },
                      ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 1200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const _CategoryStrip(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: _FilterBar(
                  mapView: _mapView,
                  onToggleView: (v) => setState(() => _mapView = v),
                  total: results.value?.total,
                ),
              ),
              Expanded(
                child: results.when(
                  skipLoadingOnReload: true,
                  loading: () => const LoadingState(),
                  error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(exploreResultsProvider)),
                  data: (page) {
                    if (page.items.isEmpty) {
                      return EmptyState(
                        icon: Icons.travel_explore_rounded,
                        title: 'No services found nearby',
                        message: 'Try a wider radius, another category, or change your location.',
                        action: OutlinedButton(
                          onPressed: () => ref.read(exploreFiltersProvider.notifier).setRadius(100),
                          child: const Text('Search within 100 km'),
                        ),
                      );
                    }
                    if (_mapView) return _ResultsMap(listings: page.items);
                    return _ResultsList(
                      listings: page.items,
                      hasMore: page.hasMore && page.limit < 100,
                      columns: wide ? 2 : 1,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationChip extends ConsumerWidget {
  const _LocationChip();

  Future<void> _openOptions(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    final controller = ref.read(locationControllerProvider.notifier);
    final current = ref.read(locationControllerProvider);
    await showModalBottomSheet<void>(
      context: context,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.my_location_rounded, color: AppColors.primary),
                    title: const Text('Use my current location'),
                    subtitle: const Text('Uses your device GPS'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      controller.useDeviceLocation();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.map_outlined),
                    title: const Text('Pick on the map'),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final picked = await context.push<PickedLocation>(
                        Routes.pickLocation,
                        extra: PickedLocation(current.point, current.label),
                      );
                      if (picked != null) controller.setManual(picked.point, picked.label);
                    },
                  ),
                  if (user != null && user.hasLocation)
                    ListTile(
                      leading: const Icon(Icons.home_outlined),
                      title: const Text('My saved address'),
                      subtitle: Text(user.address ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        ref.invalidate(locationControllerProvider);
                      },
                    ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(locationControllerProvider);
    final icon = switch (loc.source) {
      LocationSource.device => Icons.my_location_rounded,
      LocationSource.saved => Icons.home_rounded,
      LocationSource.manual => Icons.push_pin_rounded,
      LocationSource.fallback => Icons.location_searching_rounded,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openOptions(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: loc.isApproximate ? AppColors.warning.withValues(alpha: 0.5) : AppColors.border),
        ),
        child: Row(
          children: [
            if (loc.loading)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(icon, size: 18, color: loc.isApproximate ? AppColors.warning : AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Showing services near',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                  ),
                  Text(
                    loc.loading ? 'Locating you…' : loc.label,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _CategoryStrip extends ConsumerWidget {
  const _CategoryStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final selected = ref.watch(exploreFiltersProvider.select((f) => f.categoryId));
    final notifier = ref.read(exploreFiltersProvider.notifier);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              avatar: const Icon(Icons.apps_rounded, size: 18),
              showCheckmark: false,
              selected: selected == null,
              onSelected: (_) => notifier.setCategory(null),
            ),
          ),
          for (final c in categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c.name),
                avatar: Icon(CategoryStyle.of(c.icon).icon, size: 18, color: CategoryStyle.of(c.icon).color),
                showCheckmark: false,
                selected: selected == c.id,
                onSelected: (on) => notifier.setCategory(on ? c.id : null),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.mapView, required this.onToggleView, this.total});
  final bool mapView;
  final ValueChanged<bool> onToggleView;
  final int? total;

  static const _radii = [5.0, 10.0, 25.0, 50.0, 100.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(exploreFiltersProvider);
    final notifier = ref.read(exploreFiltersProvider.notifier);
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (total != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text('$total result${total == 1 ? '' : 's'}', style: theme.textTheme.bodySmall),
                  ),
                PopupMenuButton<double>(
                  tooltip: 'Search radius',
                  initialValue: filters.radiusKm,
                  onSelected: notifier.setRadius,
                  itemBuilder:
                      (_) => [for (final r in _radii) PopupMenuItem(value: r, child: Text('Within ${r.round()} km'))],
                  child: _FilterButton(icon: Icons.radar_rounded, label: '${filters.radiusKm.round()} km'),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<ListingSort>(
                  tooltip: 'Sort',
                  initialValue: filters.sort,
                  onSelected: notifier.setSort,
                  itemBuilder:
                      (_) => [for (final s in ListingSort.values) PopupMenuItem(value: s, child: Text(s.label))],
                  child: _FilterButton(icon: Icons.sort_rounded, label: filters.sort.label),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.view_list_rounded, size: 18), tooltip: 'List'),
            ButtonSegment(value: true, icon: Icon(Icons.map_outlined, size: 18), tooltip: 'Map'),
          ],
          selected: {mapView},
          onSelectionChanged: (s) => onToggleView(s.first),
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textMuted),
      ],
    ),
  );
}

class _ResultsList extends ConsumerWidget {
  const _ResultsList({required this.listings, required this.hasMore, required this.columns});
  final List<Listing> listings;
  final bool hasMore;
  final int columns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = <Widget>[];
    for (var i = 0; i < listings.length; i += columns) {
      final slice = listings.sublist(i, (i + columns).clamp(0, listings.length));
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: 12),
                Expanded(
                  child:
                      j < slice.length
                          ? ListingCard(listing: slice[j], onTap: () => context.push(Routes.service(slice[j].id)))
                          : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(exploreResultsProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          ...rows,
          if (hasMore)
            Center(
              child: OutlinedButton.icon(
                onPressed: () => ref.read(exploreFiltersProvider.notifier).loadMore(),
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('Show more'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultsMap extends ConsumerStatefulWidget {
  const _ResultsMap({required this.listings});
  final List<Listing> listings;

  @override
  ConsumerState<_ResultsMap> createState() => _ResultsMapState();
}

class _ResultsMapState extends ConsumerState<_ResultsMap> {
  Listing? _selected;

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(locationControllerProvider);
    final radius = ref.watch(exploreFiltersProvider.select((f) => f.radiusKm));
    final me = LatLng(loc.point.latitude, loc.point.longitude);
    final zoom = switch (radius) {
      <= 5 => 13.0,
      <= 10 => 12.0,
      <= 25 => 10.5,
      <= 50 => 9.5,
      _ => 8.5,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey('${loc.point.latitude},${loc.point.longitude},$radius'),
              options: MapOptions(
                initialCenter: me,
                initialZoom: zoom,
                onTap: (_, _) => setState(() => _selected = null),
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                const DarkTileLayer(),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: me,
                      radius: radius * 1000,
                      useRadiusInMeter: true,
                      color: AppColors.info.withValues(alpha: 0.05),
                      borderColor: AppColors.info.withValues(alpha: 0.4),
                      borderStrokeWidth: 1.2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(point: me, width: 20, height: 20, child: const UserDot()),
                    for (final l in widget.listings)
                      Marker(
                        point: LatLng(l.latitude, l.longitude),
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = l),
                          child: MapPin(
                            color: _selected?.id == l.id ? AppColors.accent : CategoryStyle.of(l.category?.icon).color,
                            size: _selected?.id == l.id ? 44 : 36,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const Positioned(right: 8, top: 6, child: MapAttribution()),
            if (_selected != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: ListingCard(listing: _selected!, onTap: () => context.push(Routes.service(_selected!.id))),
              )
            else
              Positioned(
                left: 12,
                bottom: 12,
                child: StatusPill(
                  label: '${widget.listings.length} services within ${Fmt.distance(radius)}',
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
