import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../router/routes.dart';

/// App bar leading for detail screens: a back button normally, or a home
/// button when the page was opened directly (deep link / browser refresh).
class BackOrHomeButton extends ConsumerWidget {
  const BackOrHomeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (context.canPop()) return const BackButton();
    final user = ref.watch(currentUserProvider);
    return IconButton(
      tooltip: 'Home',
      icon: const Icon(Icons.home_outlined),
      onPressed: () => context.go(user == null ? Routes.login : Routes.home(user.role)),
    );
  }
}
