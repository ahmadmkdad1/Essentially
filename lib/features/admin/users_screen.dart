import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import 'admin_providers.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  Role? _role;
  AccountStatus? _status;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = (role: _role, status: _status, search: _query);
    final users = ref.watch(adminUsersProvider(filter));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: ContentWidth(
        maxWidth: 960,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: TextField(
                controller: _search,
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), () => setState(() => _query = v.trim()));
                },
                decoration: const InputDecoration(
                  hintText: 'Search by name, email or business',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final r in [null, Role.user, Role.provider, Role.admin])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          r == null
                              ? 'All roles'
                              : (r == Role.user ? 'Customers' : (r == Role.provider ? 'Providers' : 'Admins')),
                        ),
                        selected: _role == r,
                        onSelected: (_) => setState(() => _role = r),
                      ),
                    ),
                  const SizedBox(width: 8),
                  for (final s in AccountStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(s.label),
                        selected: _status == s,
                        onSelected: (on) => setState(() => _status = on ? s : null),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: users.when(
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(adminUsersProvider(filter))),
                data:
                    (page) =>
                        page.items.isEmpty
                            ? const EmptyState(icon: Icons.person_search_outlined, title: 'No matching users')
                            : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                              itemCount: page.items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final row = page.items[i];
                                final u = row.user;
                                return Card(
                                  child: ListTile(
                                    onTap: () => context.push(Routes.adminUser(u.id)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: Avatar(
                                      name: u.fullName,
                                      color:
                                          u.role == Role.provider
                                              ? AppColors.violet
                                              : (u.role == Role.admin ? AppColors.accent : AppColors.info),
                                    ),
                                    title: Text(u.displayName, style: theme.textTheme.titleSmall),
                                    subtitle: Text(
                                      '${u.role.label} · ${u.email} · joined ${Fmt.date(u.createdAt)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Wrap(
                                      spacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        if (row.openReports > 0)
                                          StatusPill(
                                            label: '${row.openReports}',
                                            color: AppColors.danger,
                                            icon: Icons.flag_rounded,
                                          ),
                                        if (u.warningCount > 0)
                                          StatusPill(
                                            label: '${u.warningCount}',
                                            color: AppColors.warning,
                                            icon: Icons.warning_amber_rounded,
                                          ),
                                        StatusPill(label: u.status.label, color: u.status.color),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
