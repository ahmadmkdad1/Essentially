import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/service_request.dart';
import '../common/request_card.dart';
import 'provider_providers.dart';

class ProviderRequestsScreen extends ConsumerWidget {
  const ProviderRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(incomingRequestsProvider);
    final items = requests.value?.items ?? const <ServiceRequest>[];
    final pending = items.where((r) => r.status == RequestStatus.pending).toList();
    final active = items.where((r) => r.status == RequestStatus.accepted).toList();
    final history = items.where((r) => !r.status.isOpen).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Jobs'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'New (${pending.length})'),
              Tab(text: 'Active (${active.length})'),
              const Tab(text: 'History'),
            ],
          ),
        ),
        body: requests.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(incomingRequestsProvider)),
          data:
              (_) => TabBarView(
                children: [
                  _JobsList(
                    requests: pending,
                    empty: const EmptyState(
                      icon: Icons.mark_email_unread_outlined,
                      title: 'No new requests',
                      message: 'Keep your services active and your location set to receive requests.',
                    ),
                  ),
                  _JobsList(
                    requests: active,
                    empty: const EmptyState(
                      icon: Icons.handshake_outlined,
                      title: 'No active jobs',
                      message: 'Accepted requests appear here until you mark them completed.',
                    ),
                  ),
                  _JobsList(
                    requests: history,
                    empty: const EmptyState(icon: Icons.history_rounded, title: 'No past jobs yet'),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}

class _JobsList extends ConsumerWidget {
  const _JobsList({required this.requests, required this.empty});
  final List<ServiceRequest> requests;
  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (requests.isEmpty) return empty;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(incomingRequestsProvider.future),
      child: ContentWidth(
        maxWidth: 860,
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: requests.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final r = requests[i];
            return RequestCard(
              request: r,
              counterpartName: r.customer?.name ?? 'Customer',
              counterpartPhone: r.customer?.phone,
              showDistance: true,
              actions: providerRequestActions(context, ref, r),
            );
          },
        ),
      ),
    );
  }
}
