import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/back_or_home.dart';
import '../../core/utils/category_style.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/map_widgets.dart';
import '../../data/models/enums.dart';
import '../../data/models/listing.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../auth/auth_controller.dart';
import '../common/location_picker_screen.dart';
import '../customer/explore_providers.dart';
import 'provider_providers.dart';

/// Create a new service, or edit [existing] when given.
class ServiceFormScreen extends ConsumerStatefulWidget {
  const ServiceFormScreen({super.key, this.existing});
  final Listing? existing;

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _description = TextEditingController(text: widget.existing?.description);
  late final _price = TextEditingController(
    text: widget.existing == null ? '' : widget.existing!.price.toStringAsFixed(2),
  );
  late PriceUnit _unit = widget.existing?.priceUnit ?? PriceUnit.fixed;
  late String? _categoryId = widget.existing?.categoryId;
  late double _radius = (widget.existing?.serviceRadiusKm ?? 15).toDouble();
  PickedLocation? _location;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _location = PickedLocation(GeoPoint(e.latitude, e.longitude), e.address);
    } else {
      final user = ref.read(currentUserProvider);
      if (user != null && user.hasLocation) {
        _location = PickedLocation(GeoPoint(user.latitude!, user.longitude!), user.address ?? 'Business location');
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final picked = await context.push<PickedLocation>(Routes.pickLocation, extra: _location);
    if (picked != null) setState(() => _location = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      showSnack(context, 'Choose a category', error: true);
      return;
    }
    if (_location == null) {
      showSnack(context, 'Choose where you offer this service', error: true);
      return;
    }
    setState(() => _saving = true);
    final input = ListingInput(
      title: _title.text,
      description: _description.text,
      price: double.parse(_price.text.replaceAll(',', '.')),
      priceUnit: _unit,
      categoryId: _categoryId!,
      latitude: _location!.point.latitude,
      longitude: _location!.point.longitude,
      address: _location!.label,
      serviceRadiusKm: _radius.round(),
    );
    try {
      final repo = ref.read(marketplaceRepositoryProvider);
      if (_editing) {
        await repo.updateListing(widget.existing!.id, input);
      } else {
        await repo.createListing(input);
      }
      ref.invalidate(myListingsProvider);
      ref.invalidate(providerStatsProvider);
      if (!mounted) return;
      showSnack(context, _editing ? 'Service updated' : 'Service published');
      context.pop();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(leading: const BackOrHomeButton(), title: Text(_editing ? 'Edit service' : 'New service')),
      body: ContentWidth(
        maxWidth: 760,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text('Category', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              categories.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(categoriesProvider)),
                data:
                    (list) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in list)
                          ChoiceChip(
                            showCheckmark: false,
                            avatar: Icon(
                              CategoryStyle.of(c.icon).icon,
                              size: 18,
                              color: CategoryStyle.of(c.icon).color,
                            ),
                            label: Text(c.name),
                            selected: _categoryId == c.id,
                            onSelected: (_) => setState(() => _categoryId = c.id),
                          ),
                      ],
                    ),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _title,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Gas cylinder delivery (10 kg)'),
                validator: (v) => Validators.minLength(v, 3, 'Title'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                maxLines: 5,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What is included, how long it takes, any conditions…',
                  alignLabelWithHint: true,
                ),
                validator: (v) => Validators.minLength(v, 10, 'Description'),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(labelText: 'Price', prefixText: r'$ '),
                      validator: Validators.price,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<PriceUnit>(
                      value: _unit,
                      decoration: const InputDecoration(labelText: 'Billing'),
                      items: [for (final u in PriceUnit.values) DropdownMenuItem(value: u, child: Text(u.label))],
                      onChanged: (u) => setState(() => _unit = u ?? PriceUnit.fixed),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              SectionHeader(
                'Service location',
                subtitle: 'Customers within your radius see this service first',
                trailing: TextButton.icon(
                  onPressed: _pickLocation,
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                  label: Text(_location == null ? 'Choose' : 'Change'),
                ),
              ),
              if (_location != null) ...[
                MapPreview(
                  latitude: _location!.point.latitude,
                  longitude: _location!.point.longitude,
                  radiusKm: _radius,
                  height: 190,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_location!.label, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ] else
                InfoBanner(
                  message: 'No location selected yet.',
                  color: AppColors.warning,
                  action: TextButton(onPressed: _pickLocation, child: const Text('Choose')),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text('Service radius', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  Text('${_radius.round()} km', style: theme.textTheme.titleSmall?.copyWith(color: AppColors.primary)),
                ],
              ),
              Slider(
                value: _radius,
                min: 1,
                max: 100,
                divisions: 99,
                label: '${_radius.round()} km',
                onChanged: (v) => setState(() => _radius = v),
              ),
              const SizedBox(height: 18),
              LoadingButton(label: _editing ? 'Save changes' : 'Publish service', loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
