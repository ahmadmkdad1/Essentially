import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import 'auth_controller.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Center(
          child:
              auth.hasError
                  ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogo(size: 48),
                      const SizedBox(height: 24),
                      ErrorState(error: auth.error!, onRetry: () => ref.invalidate(authControllerProvider)),
                    ],
                  )
                  : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppLogo(size: 56),
                      SizedBox(height: 32),
                      SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    ],
                  ),
        ),
      ),
    );
  }
}
