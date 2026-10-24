import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/models/listing.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/requests_repository.dart';
import '../common/location_controller.dart';
import '../common/location_picker_screen.dart';
import 'my_requests_screen.dart';

Future<void> showRequestSheet(BuildContext context, Listing listing) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RequestSheet(listing: listing),
  );
}

class _RequestSheet extends ConsumerStatefulWidget {
  const _RequestSheet({required this.listing});
  final Listing listing;

  @override
  ConsumerState<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<_RequestSheet> {
  final _message = TextEditingController();
  DateTime? _date;
  late PickedLocation _location;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final loc = ref.read(locationControllerProvider);
    _location = PickedLocation(loc.point, loc.label);
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    setState(() => _date = DateTime(date.year, date.month, date.day, time?.hour ?? 10, time?.minute ?? 0));
  }

  Future<void> _changeLocation() async {
    final picked = await context.push<PickedLocation>(Routes.pickLocation, extra: _location);
    if (picked != null) setState(() => _location = picked);
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ref
          .read(requestsRepositoryProvider)
          .create(
            listingId: widget.listing.id,
            message: _message.text,
            preferredDate: _date,
            latitude: _location.point.latitude,
            longitude: _location.point.longitude,
            address: _location.label,
          );
      ref.invalidate(myRequestsProvider);
      if (!mounted) return;
      final router = GoRouter.of(context);
      Navigator.pop(context);
      showSnack(context, 'Request sent to ${widget.listing.provider?.displayName ?? 'the provider'}');
      router.go(Routes.requests);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = widget.listing;
    final distance = LocationRepository.distanceKm(_location.point, GeoPoint(l.latitude, l.longitude));
    final outside = distance > l.serviceRadiusKm;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Request service', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l.title, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.place_outlined, color: AppColors.primary),
                    title: Text(_location.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${Fmt.distance(distance)} from the provider'),
                    trailing: TextButton(onPressed: _changeLocation, child: const Text('Change')),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.event_outlined, color: AppColors.primary),
                    title: Text(_date == null ? 'As soon as possible' : Fmt.dateTime(_date!)),
                    subtitle: const Text('Preferred date'),
                    trailing: TextButton(onPressed: _pickDate, child: Text(_date == null ? 'Schedule' : 'Change')),
                  ),
                ],
              ),
            ),
            if (outside) ...[
              const SizedBox(height: 12),
              InfoBanner(
                color: AppColors.warning,
                icon: Icons.wrong_location_outlined,
                message: 'This address is outside the ${l.serviceRadiusKm} km service area.',
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _message,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Message to the provider (optional)',
                hintText: 'Floor, access instructions, details about the problem…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Quoted price', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(
                  Fmt.price(l.price, l.currency, l.priceUnit),
                  style: theme.textTheme.titleMedium?.copyWith(color: AppColors.accent),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LoadingButton(label: 'Send request', icon: Icons.send_rounded, loading: _sending, onPressed: _send),
          ],
        ),
      ),
    );
  }
}
