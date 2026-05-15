import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';

/// Mime-type breakdown shown on the Landing/Stats card.
///
/// Renders a donut chart with NO in-slice text (labels overlap on small
/// slices), and a compact, scannable vertical legend below it (color swatch
/// + short type name + count + percent), with proper truncation and
/// theme-aware contrast.
class MimeTypesPieChart extends StatefulWidget {
  final PaperlessServerStatisticsModel statistics;

  const MimeTypesPieChart({super.key, required this.statistics});

  @override
  State<MimeTypesPieChart> createState() => _MimeTypesPieChartState();
}

class _MimeTypesPieChartState extends State<MimeTypesPieChart> {
  /// Short, human-readable display names per MIME type.
  static const _shortNames = <String, String>{
    'application/pdf': 'PDF',
    'image/png': 'PNG',
    'image/jpeg': 'JPEG',
    'image/tiff': 'TIFF',
    'image/gif': 'GIF',
    'image/webp': 'WebP',
    'text/plain': 'Text',
    'application/msword': 'Word',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        'Word',
    'application/vnd.ms-powerpoint': 'PowerPoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        'PowerPoint',
    'application/vnd.ms-excel': 'Excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        'Excel',
    'application/vnd.oasis.opendocument.text': 'ODT',
    'application/vnd.oasis.opendocument.presentation': 'ODP',
    'application/vnd.oasis.opendocument.spreadsheet': 'ODS',
  };

  String _displayNameFor(String mimeType) {
    final short = _shortNames[mimeType];
    if (short != null) return short;
    // Fall back to the subtype, e.g. "application/zip" -> "ZIP".
    final slash = mimeType.indexOf('/');
    if (slash >= 0 && slash < mimeType.length - 1) {
      return mimeType.substring(slash + 1).toUpperCase();
    }
    return mimeType;
  }

  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = widget.statistics.documentsTotal;

    // Theme-aware palette built from the seed color so chart blends with
    // both light and dark themes.
    final palette = _buildPalette(scheme);

    final fileTypes = widget.statistics.fileTypeCounts;

    if (fileTypes.isEmpty || total <= 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Stack chart vertically over legend; chart takes a fixed compact
        // height so the legend below stays fully readable.
        const chartSize = 160.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SizedBox(
                height: chartSize,
                width: chartSize,
                child: PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            _touchedIndex = null;
                            return;
                          }
                          _touchedIndex =
                              response.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 2,
                    centerSpaceRadius: 44,
                    sections: [
                      for (int i = 0; i < fileTypes.length; i++)
                        PieChartSectionData(
                          color: palette[i % palette.length],
                          value: fileTypes[i].count.toDouble(),
                          // Never draw labels inside slices; they overlap.
                          title: '',
                          radius: _touchedIndex == i ? 28 : 24,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: PmSpacing.md),
            // Compact legend list, one entry per line.
            for (int i = 0; i < fileTypes.length; i++)
              _LegendRow(
                color: palette[i % palette.length],
                label: _displayNameFor(fileTypes[i].mimeType),
                count: fileTypes[i].count,
                percent: total > 0 ? fileTypes[i].count / total * 100 : 0,
                highlighted: _touchedIndex == i,
                onTap: () {
                  setState(() {
                    _touchedIndex = _touchedIndex == i ? null : i;
                  });
                },
              ),
          ],
        );
      },
    );
  }

  /// Generate a small distinct palette derived from the theme primary so the
  /// chart works in both light and dark mode.
  List<Color> _buildPalette(ColorScheme scheme) {
    final base = HSLColor.fromColor(scheme.primary);
    return [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      base.withHue((base.hue + 40) % 360).withLightness(0.55).toColor(),
      base.withHue((base.hue + 80) % 360).withLightness(0.55).toColor(),
      base.withHue((base.hue + 120) % 360).withLightness(0.5).toColor(),
      base.withHue((base.hue + 160) % 360).withLightness(0.55).toColor(),
      base.withHue((base.hue + 200) % 360).withLightness(0.5).toColor(),
      base.withHue((base.hue + 240) % 360).withLightness(0.55).toColor(),
    ];
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final double percent;
  final bool highlighted;
  final VoidCallback onTap;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.count,
    required this.percent,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PmSpacing.xs,
          vertical: PmSpacing.xs,
        ),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: highlighted
                    ? Border.all(color: scheme.onSurface, width: 2)
                    : null,
              ),
            ),
            const SizedBox(width: PmSpacing.sm),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: PmSpacing.sm),
            Text(
              '$count',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: PmSpacing.sm),
            SizedBox(
              width: 48,
              child: Text(
                '${percent.toStringAsFixed(percent >= 10 ? 0 : 1)}%',
                textAlign: TextAlign.right,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience accessor for ordered Material shades, kept for backwards
/// compatibility with other widgets that imported this extension from here.
extension AllShades on MaterialColor {
  List<Color> get values => [
    shade200,
    shade600,
    shade300,
    shade100,
    shade800,
    shade400,
    shade900,
    shade500,
    shade700,
  ];
}
