import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/core/widgets/state/pm_error_state.dart';
import 'package:paperless_mobile/features/landing/view/widgets/mime_types_pie_chart.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/routing/routes/documents_route.dart';
import 'package:paperless_mobile/routing/routes/inbox_route.dart';

/// Statistics card showing server stats (inbox count, total docs, total chars)
/// and the [MimeTypesPieChart].
///
/// Pass a different [statsKey] to force the [FutureBuilder] to re-fetch.
class StatsCard extends StatelessWidget {
  const StatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainer,
      shape: PmRadii.cardShape,
      elevation: PmElevations.level1,
      child: Padding(
        padding: PmSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: scheme.primary, size: 20),
                const SizedBox(width: PmSpacing.sm),
                Text(
                  S.of(context)!.statistics,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: PmSpacing.md),
            FutureBuilder<PaperlessServerStatisticsModel>(
              future: context
                  .read<PaperlessServerStatsApi>()
                  .getServerStatistics(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return PmErrorState(
                    title: S.of(context)!.couldNotLoadStatistics,
                  );
                }
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }
                return _StatsContent(stats: snapshot.data!);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  final PaperlessServerStatisticsModel stats;

  const _StatsContent({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatChip(
                icon: Icons.inbox_rounded,
                label: S.of(context)!.documentsInInbox,
                value: stats.documentsInInbox.toString(),
                onTap: () => InboxRoute().go(context),
              ),
            ),
            const SizedBox(width: PmSpacing.sm),
            Expanded(
              child: _StatChip(
                icon: Icons.folder_rounded,
                label: S.of(context)!.totalDocuments,
                value: stats.documentsTotal.toString(),
                onTap: () => DocumentsRoute().go(context),
              ),
            ),
            const SizedBox(width: PmSpacing.sm),
            Expanded(
              child: _StatChip(
                icon: Icons.text_fields_rounded,
                label: S.of(context)!.totalCharacters,
                value: _compactNumber(stats.totalChars ?? 0),
              ),
            ),
          ],
        ),
        if (stats.fileTypeCounts.isNotEmpty) ...[
          const SizedBox(height: PmSpacing.lg),
          MimeTypesPieChart(statistics: stats),
        ],
      ],
    );
  }

  String _compactNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: PmRadii.rsm,
      child: InkWell(
        onTap: onTap,
        borderRadius: PmRadii.rsm,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PmSpacing.sm,
            vertical: PmSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(height: PmSpacing.xs),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
