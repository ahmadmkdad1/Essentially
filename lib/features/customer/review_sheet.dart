import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/models/service_request.dart';
import '../../data/repositories/marketplace_repository.dart';

/// Returns true when a review was posted.
Future<bool> showReviewSheet(BuildContext context, ServiceRequest request) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReviewSheet(request: request),
  );
  return result ?? false;
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.request});
  final ServiceRequest request;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  final _comment = TextEditingController();
  int _rating = 5;
  bool _sending = false;

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await ref.read(marketplaceRepositoryProvider).createReview(widget.request.id, _rating, _comment.text);
      if (!mounted) return;
      Navigator.pop(context, true);
      showSnack(context, 'Thanks for your review!');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How was the service?', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(widget.request.title, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 40,
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i <= _rating ? AppColors.accent : AppColors.textMuted,
                  ),
                ),
            ],
          ),
          Center(child: Text(_labels[_rating], style: theme.textTheme.titleSmall?.copyWith(color: AppColors.accent))),
          const SizedBox(height: 16),
          TextField(
            controller: _comment,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Share details (optional)', alignLabelWithHint: true),
          ),
          const SizedBox(height: 12),
          LoadingButton(label: 'Post review', loading: _sending, onPressed: _submit),
        ],
      ),
    );
  }
}
