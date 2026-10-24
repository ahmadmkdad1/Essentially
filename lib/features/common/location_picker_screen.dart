import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/back_or_home.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/map_widgets.dart';
import '../../data/repositories/location_repository.dart';

class PickedLocation {
  const PickedLocation(this.point, this.label);
  final GeoPoint point;
  final String label;
}

/// Full-screen map: move the map under the centre pin, search an address,
/// or jump to the device location. Pops with a [PickedLocation].
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key, this.initial});
  final PickedLocation? initial;

  @override
  ConsumerState<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _map = MapController();
  final _search = TextEditingController();
  Timer? _geocodeDebounce;
  Timer? _searchDebounce;

  late GeoPoint _center;
  String? _label;
  bool _resolving = false;
  bool _locating = false;
  List<({GeoPoint point, String label})> _results = const [];

  LocationRepository get _repo => ref.read(locationRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _center = widget.initial?.point ?? const GeoPoint(AppConfig.defaultLatitude, AppConfig.defaultLongitude);
    _label = widget.initial?.label;
    if (widget.initial == null) {
      _resolving = true;
      _scheduleGeocode();
      WidgetsBinding.instance.addPostFrameCallback((_) => _useDevice(silent: true));
    }
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _searchDebounce?.cancel();
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onMoved(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    _center = GeoPoint(camera.center.latitude, camera.center.longitude);
    setState(() {
      _label = null;
      _resolving = true;
    });
    _scheduleGeocode();
  }

  void _scheduleGeocode() {
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 700), () async {
      final point = _center;
      final label = await _repo.describe(point);
      if (!mounted || point != _center) return;
      setState(() {
        _label = label;
        _resolving = false;
      });
    });
  }

  void _moveTo(GeoPoint point, {String? label, double zoom = 15}) {
    _center = point;
    _map.move(LatLng(point.latitude, point.longitude), zoom);
    setState(() {
      _label = label;
      _resolving = label == null;
      _results = const [];
    });
    if (label == null) _scheduleGeocode();
  }

  Future<void> _useDevice({bool silent = false}) async {
    setState(() => _locating = true);
    try {
      _moveTo(await _repo.currentPosition());
    } on LocationException catch (e) {
      if (!silent && mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (!silent && mounted) showSnack(context, 'Could not get your location', error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _repo.search(value);
      if (mounted && _search.text == value) setState(() => _results = results);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canConfirm = !_resolving && _label != null;

    return Scaffold(
      appBar: AppBar(leading: const BackOrHomeButton(), title: const Text('Choose location')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: LatLng(_center.latitude, _center.longitude),
              initialZoom: 14,
              minZoom: 3,
              maxZoom: 18,
              onPositionChanged: _onMoved,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: const [DarkTileLayer()],
          ),
          // Fixed pin in the middle of the map.
          const IgnorePointer(
            child: Center(child: Padding(padding: EdgeInsets.only(bottom: 44), child: MapPin(size: 48))),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  color: AppColors.surface,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(14),
                  child: TextField(
                    controller: _search,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search an address or area',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon:
                          _search.text.isEmpty
                              ? null
                              : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed:
                                    () => setState(() {
                                      _search.clear();
                                      _results = const [];
                                    }),
                              ),
                    ),
                  ),
                ),
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = _results[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(r.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            _moveTo(r.point, label: r.label);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const Positioned(left: 14, bottom: 196, child: MapAttribution()),
          Positioned(
            right: 16,
            bottom: 190,
            child: FloatingActionButton(
              heroTag: 'locate',
              backgroundColor: AppColors.surfaceHigh,
              foregroundColor: AppColors.primary,
              tooltip: 'Use my current location',
              onPressed: _locating ? null : _useDevice,
              child:
                  _locating
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                      : const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child:
                                _resolving || _label == null
                                    ? Text('Finding address…', style: theme.textTheme.bodyMedium)
                                    : Text(
                                      _label!,
                                      style: theme.textTheme.titleSmall,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 34),
                        child: Text(_center.shortLabel, style: theme.textTheme.bodySmall),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: canConfirm ? () => context.pop(PickedLocation(_center, _label!)) : null,
                        child: const Text('Confirm location'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
