import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/models/enums.dart';
import '../../data/models/json_utils.dart';
import '../../data/models/service_request.dart';
import '../../data/repositories/requests_repository.dart';
import '../common/report_sheet.dart';
import '../common/request_card.dart';
import 'review_sheet.dart';

final myRequestsProvider = FutureProvider.autoDispose<Paginated<ServiceRequest>>(
  (ref) => ref.watch(requestsRepositoryProvider).list(),
);

class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myRequestsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My requests'),
          bottom: const TabBar(tabs: [Tab(text: 'Active'), Tab(text: 'History')]),
        ),
        body: requests.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(myRequestsProvider)),
          data: (page) {
            final active = page.items.where((r) => r.status.isOpen).toList();
            final history = page.items.where((r) => !r.status.isOpen).toList();
            return TabBarView(
              children: [
                _RequestList(
                  requests: active,
                  empty: EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No active requests',
                    message: 'Find a service near you and send your first request.',
                    action: FilledButton(
                      onPressed: () => context.go(Routes.explore),
                      child: const Text('Explore services'),
                    ),
                  ),
                ),
                _RequestList(
                  requests: history,
                  empty: const EmptyState(
                    icon: Icons.history_rounded,
                    title: 'Nothing here yet',
                    message: 'Completed, cancelled and declined requests will appear here.',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RequestList extends ConsumerWidget {
  const _RequestList({required this.requests, required this.empty});
  final List<ServiceRequest> requests;
  final Widget empty;

  Future<void> _cancel(BuildContext context, WidgetRef ref, ServiceRequest r) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel request?',
      message: 'The provider will be notified that you no longer need "${r.title}".',
      confirmLabel: 'Cancel request',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(requestsRepositoryProvider).cancel(r.id);
      ref.invalidate(myRequestsProvider);
      if (context.mounted) showSnack(context, 'Request cancelled');
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (requests.isEmpty) return empty;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(myRequestsProvider.future),
      child: ContentWidth(
        maxWidth: 860,
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: requests.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final r = requests[i];
            final providerName = r.provider?.displayName ?? 'Provider';
            return RequestCard(
              request: r,
              counterpartName: providerName,
              messageLabel: 'Your note',
              counterpartPhone: r.status == RequestStatus.accepted ? r.provider?.phone : null,
              onTap: r.listing == null ? null : () => context.push(Routes.service(r.listingId)),
              actions: [
                if (r.status.isOpen)
                  CardAction(
                    label: 'Cancel',
                    icon: Icons.close_rounded,
                    color: AppColors.danger,
                    onPressed: () => _cancel(context, ref, r),
                  ),
                if (r.status == RequestStatus.completed && !r.hasReview)
                  CardAction(
                    label: 'Leave a review',
                    icon: Icons.star_outline_rounded,
                    primary: true,
                    onPressed: () async {
                      final done = await showReviewSheet(context, r);
                      if (done) ref.invalidate(myRequestsProvider);
                    },
                  ),
                if (r.status == RequestStatus.completed && r.hasReview)
                  const StatusPill(label: 'Reviewed', color: AppColors.accent, icon: Icons.star_rounded),
                CardAction(
                  label: 'Report',
                  icon: Icons.flag_outlined,
                  onPressed:
                      () => showReportSheet(
                        context,
                        targetType: ReportTargetType.user,
                        targetId: r.providerId,
                        targetLabel: '$providerName — ${r.title}',
                      ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
