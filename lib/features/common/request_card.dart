import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/service_request.dart';

/// Shared request card. The [counterpartName] is the provider for customers
/// and the customer for providers. Role-specific buttons go in [actions].
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.counterpartName,
    this.counterpartPhone,
    this.actions = const [],
    this.onTap,
    this.showDistance = false,
    this.messageLabel = 'Customer note',
  });

  final ServiceRequest request;
  final String counterpartName;
  final String? counterpartPhone;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final bool showDistance;

  /// Label of the customer's message ("Your note" when the customer is viewing).
  final String messageLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = request;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: r.status.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(r.status.icon, color: r.status.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          '$counterpartName · ${Fmt.relative(r.createdAt)}',
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusPill(label: r.status.label, color: r.status.color),
                      const SizedBox(height: 6),
                      Text(
                        Fmt.price(r.quotedPrice, r.currency, r.priceUnit),
                        style: theme.textTheme.titleSmall?.copyWith(color: AppColors.accent),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Line(
                icon: Icons.place_outlined,
                text:
                    showDistance && r.distanceKm != null
                        ? '${r.address} · ${Fmt.distance(r.distanceKm)} away'
                        : r.address,
              ),
              if (r.preferredDate != null)
                _Line(icon: Icons.event_outlined, text: 'Preferred: ${Fmt.dateTime(r.preferredDate!)}'),
              if (counterpartPhone != null && r.status.isOpen)
                _Line(icon: Icons.phone_outlined, text: counterpartPhone!),
              if (r.message != null && r.message!.isNotEmpty) _Quote(label: messageLabel, text: r.message!),
              if (r.providerNote != null && r.providerNote!.isNotEmpty)
                _Quote(
                  label: r.status == RequestStatus.rejected ? 'Reason' : 'Provider note',
                  text: r.providerNote!,
                  color: r.status == RequestStatus.rejected ? AppColors.danger : AppColors.info,
                ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ),
      ],
    ),
  );
}

class _Quote extends StatelessWidget {
  const _Quote({required this.label, required this.text, this.color = AppColors.textSecondary});
  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border(left: BorderSide(color: color, width: 3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
        const SizedBox(height: 4),
        Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
      ],
    ),
  );
}

/// Compact action button used inside request cards.
class CardAction extends StatelessWidget {
  const CardAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    const size = Size(0, 40);
    if (primary) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: size, padding: const EdgeInsets.symmetric(horizontal: 16)),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: size,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        foregroundColor: color,
        side: color == null ? null : BorderSide(color: color!.withValues(alpha: 0.5)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
