import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/back_or_home.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import 'admin_providers.dart';
import 'audit_log_screen.dart';
import 'moderation_actions.dart';
import 'services_moderation_screen.dart';

class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(adminUserProvider(id));
    return Scaffold(
      appBar: AppBar(leading: const BackOrHomeButton(), title: const Text('User')),
      body: detail.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(adminUserProvider(id))),
        data: (d) {
          final theme = Theme.of(context);
          final u = d.user;
          final isAdmin = u.role == Role.admin;
          return ContentWidth(
            maxWidth: 900,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Avatar(name: u.fullName, size: 60),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.displayName, style: theme.textTheme.titleLarge),
                                  Text('${u.role.label} · ${u.email}', style: theme.textTheme.bodySmall),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      StatusPill(label: u.status.label, color: u.status.color),
                                      if (u.warningCount > 0)
                                        StatusPill(label: '${u.warningCount} warning(s)', color: AppColors.warning),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (u.status != AccountStatus.active) ...[
                          const SizedBox(height: 14),
                          InfoBanner(
                            color: u.status.color,
                            icon: Icons.gpp_bad_outlined,
                            message: [
                              u.status == AccountStatus.suspended && u.suspendedUntil != null
                                  ? 'Suspended until ${Fmt.dateTime(u.suspendedUntil!)}'
                                  : u.status.label,
                              if (u.statusReason != null) u.statusReason!,
                            ].join(' — '),
                          ),
                        ],
                        const SizedBox(height: 14),
                        KeyValueRow(icon: Icons.phone_outlined, label: 'Phone', value: u.phone ?? '—'),
                        KeyValueRow(icon: Icons.place_outlined, label: 'Address', value: u.address ?? '—'),
                        KeyValueRow(icon: Icons.calendar_today_outlined, label: 'Joined', value: Fmt.date(u.createdAt)),
                        KeyValueRow(
                          icon: Icons.login_rounded,
                          label: 'Last sign in',
                          value: u.lastLoginAt == null ? 'Never' : Fmt.relative(u.lastLoginAt!),
                        ),
                        if (!isAdmin) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => warnUser(context, ref, u),
                                icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                                label: const Text('Warn'),
                              ),
                              if (u.status != AccountStatus.active)
                                FilledButton.icon(
                                  onPressed: () => reactivateUser(context, ref, u),
                                  icon: const Icon(Icons.restart_alt_rounded),
                                  label: const Text('Reactivate'),
                                ),
                              if (u.status == AccountStatus.active)
                                OutlinedButton.icon(
                                  onPressed: () => suspendUser(context, ref, u),
                                  icon: const Icon(Icons.pause_circle_outline_rounded, color: AppColors.warning),
                                  label: const Text('Suspend'),
                                ),
                              if (u.status != AccountStatus.banned)
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                                  onPressed: () => banUser(context, ref, u),
                                  icon: const Icon(Icons.gpp_bad_outlined),
                                  label: const Text('Ban'),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Requests',
                        value: '${d.totalRequests}',
                        icon: Icons.receipt_long_outlined,
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: 'Reports against',
                        value: '${d.reportsAgainst.length}',
                        icon: Icons.flag_outlined,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: 'Reports filed',
                        value: '${d.reportsFiled}',
                        icon: Icons.outlined_flag_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (u.role == Role.provider) ...[
                  const SizedBox(height: 24),
                  SectionHeader('Services (${d.listings.length})'),
                  if (d.listings.isEmpty)
                    Text('No services published.', style: theme.textTheme.bodyMedium)
                  else
                    for (final l in d.listings) AdminListingTile(listing: l, showProvider: false),
                ],
                if (d.reportsAgainst.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const SectionHeader('Reports against this account'),
                  for (final r in d.reportsAgainst)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          onTap: () => context.push(Routes.adminReport(r.id)),
                          leading: Icon(r.targetType.icon, color: AppColors.danger),
                          title: Text(r.reason.label),
                          subtitle: Text(r.details, maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: StatusPill(label: r.status.label, color: r.status.color),
                        ),
                      ),
                    ),
                ],
                if (d.history.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const SectionHeader('Moderation history'),
                  for (final e in d.history) AuditTile(entry: e, showAdmin: true),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
