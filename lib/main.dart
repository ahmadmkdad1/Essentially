import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      // Surface API errors to the UI immediately instead of silently retrying.
      retry: (retryCount, error) => null,
      child: const EssentiallyApp(),
    ),
  );
}
