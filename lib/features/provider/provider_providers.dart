import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/models/enums.dart';
import '../../data/models/json_utils.dart';
import '../../data/models/listing.dart';
import '../../data/models/service_request.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/repositories/requests_repository.dart';
import '../common/report_sheet.dart';
import '../common/request_card.dart';

final providerStatsProvider = FutureProvider.autoDispose<ProviderStats>(
  (ref) => ref.watch(requestsRepositoryProvider).stats(),
);

final incomingRequestsProvider = FutureProvider.autoDispose<Paginated<ServiceRequest>>(
  (ref) => ref.watch(requestsRepositoryProvider).list(),
);

final myListingsProvider = FutureProvider.autoDispose<List<Listing>>(
  (ref) => ref.watch(marketplaceRepositoryProvider).myListings(),
);

void refreshProviderData(WidgetRef ref) {
  ref.invalidate(providerStatsProvider);
  ref.invalidate(incomingRequestsProvider);
}

/// Accept / reject / complete / cancel buttons for a provider's request.
List<Widget> providerRequestActions(BuildContext context, WidgetRef ref, ServiceRequest r) {
  final repo = ref.read(requestsRepositoryProvider);

  Future<void> run(Future<void> Function() action, String success) async {
    try {
      await action();
      refreshProviderData(ref);
      if (context.mounted) showSnack(context, success);
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  final customerName = r.customer?.name ?? 'Customer';
  return [
    if (r.status == RequestStatus.pending) ...[
      CardAction(
        label: 'Decline',
        icon: Icons.close_rounded,
        color: AppColors.danger,
        onPressed: () async {
          final reason = await promptText(
            context,
            title: 'Decline request',
            label: 'Reason shown to the customer',
            message: 'Let $customerName know why you cannot take this job.',
            confirmLabel: 'Decline',
            destructive: true,
          );
          if (reason != null) await run(() => repo.reject(r.id, reason), 'Request declined');
        },
      ),
      CardAction(
        label: 'Accept',
        icon: Icons.check_rounded,
        primary: true,
        onPressed: () async {
          final note = await promptText(
            context,
            title: 'Accept request',
            label: 'Note for the customer (optional)',
            message: 'e.g. when you will arrive or what to prepare.',
            confirmLabel: 'Accept',
            required: false,
          );
          if (note != null) await run(() => repo.accept(r.id, note: note), 'Request accepted');
        },
      ),
    ],
    if (r.status == RequestStatus.accepted) ...[
      CardAction(
        label: 'Cancel job',
        icon: Icons.event_busy_outlined,
        color: AppColors.danger,
        onPressed: () async {
          final reason = await promptText(
            context,
            title: 'Cancel this job?',
            label: 'Reason shown to the customer',
            confirmLabel: 'Cancel job',
            destructive: true,
          );
          if (reason != null) await run(() => repo.cancel(r.id, note: reason), 'Job cancelled');
        },
      ),
      CardAction(
        label: 'Mark completed',
        icon: Icons.task_alt_rounded,
        primary: true,
        onPressed: () async {
          final ok = await confirmDialog(
            context,
            title: 'Mark as completed?',
            message: 'The customer will be able to leave a review.',
            confirmLabel: 'Complete',
          );
          if (ok) await run(() => repo.complete(r.id), 'Job completed');
        },
      ),
    ],
    CardAction(
      label: 'Report',
      icon: Icons.flag_outlined,
      onPressed:
          () => showReportSheet(
            context,
            targetType: ReportTargetType.user,
            targetId: r.customerId,
            targetLabel: '$customerName — ${r.title}',
          ),
    ),
  ];
}
