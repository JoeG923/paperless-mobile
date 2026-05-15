import 'package:flutter/material.dart';
import 'package:paperless_mobile/accessibility/accessibility_utils.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class HintCard extends StatelessWidget {
  final String hintText;
  final double elevation;
  final IconData hintIcon;
  final VoidCallback? onHintAcknowledged;
  final bool show;
  const HintCard({
    super.key,
    required this.hintText,
    this.onHintAcknowledged,
    this.elevation = 0,
    this.show = true,
    this.hintIcon = Icons.tips_and_updates_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedCrossFade(
      sizeCurve: Curves.easeInOutCubicEmphasized,
      firstCurve: Curves.easeOutCubic,
      secondCurve: Curves.easeInCubic,
      crossFadeState: show
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      secondChild: const SizedBox.shrink(),
      duration: PmDurations.medium.accessible(),
      firstChild: Card(
        color: scheme.tertiaryContainer,
        elevation: elevation,
        margin: const EdgeInsets.symmetric(
          horizontal: PmSpacing.lg,
          vertical: PmSpacing.sm,
        ),
        child: Padding(
          padding: const EdgeInsets.all(PmSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(hintIcon, color: scheme.onTertiaryContainer, size: 20),
                  const SizedBox(width: PmSpacing.md),
                  Expanded(
                    child: Text(
                      hintText,
                      softWrap: true,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              if (onHintAcknowledged != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: PmSpacing.sm),
                    child: TextButton(
                      onPressed: onHintAcknowledged,
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onTertiaryContainer,
                      ),
                      child: Text(S.of(context)!.gotIt),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
