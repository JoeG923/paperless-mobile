import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/features/settings/model/color_scheme_option.dart';

const _classicThemeColorSeed = Color(0xFF6FAF3F);

ThemeData buildTheme({
  required Brightness brightness,
  required ColorSchemeOption preferredColorScheme,
  ColorScheme? dynamicScheme,
}) {
  final classicScheme = ColorScheme.fromSeed(
    seedColor: _classicThemeColorSeed,
    brightness: brightness,
  );
  late ColorScheme colorScheme;
  switch (preferredColorScheme) {
    case ColorSchemeOption.classic:
      colorScheme = classicScheme;
      break;
    case ColorSchemeOption.dynamic:
      colorScheme = dynamicScheme ?? classicScheme;
      break;
  }
  colorScheme = colorScheme.harmonized();
  final base = ThemeData.from(colorScheme: colorScheme, useMaterial3: true);
  final textTheme = _buildTextTheme(base.textTheme, colorScheme);

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.surface,
    canvasColor: colorScheme.surface,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: PmElevations.level0,
      scrolledUnderElevation: PmElevations.level1,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colorScheme.surface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.secondaryContainer,
      surfaceTintColor: Colors.transparent,
      elevation: PmElevations.level2,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium?.copyWith(
          color: selected
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.secondaryContainer,
      selectedIconTheme: IconThemeData(
        color: colorScheme.onSecondaryContainer,
        size: 24,
      ),
      unselectedIconTheme: IconThemeData(
        color: colorScheme.onSurfaceVariant,
        size: 24,
      ),
      selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      labelType: NavigationRailLabelType.all,
      useIndicator: true,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: PmElevations.level0,
      margin: const EdgeInsets.symmetric(
        horizontal: PmSpacing.lg,
        vertical: PmSpacing.sm,
      ),
      shape: PmRadii.cardShape,
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: PmRadii.rlg,
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: PmRadii.rlg,
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: PmRadii.rlg,
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: PmRadii.rlg,
        borderSide: BorderSide(color: colorScheme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: PmSpacing.lg,
        vertical: PmSpacing.lg,
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
    ),
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      iconColor: colorScheme.onSurfaceVariant,
      textColor: colorScheme.onSurface,
      titleTextStyle: textTheme.bodyLarge,
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: PmSpacing.lg,
        vertical: PmSpacing.xs,
      ),
      shape: RoundedRectangleBorder(borderRadius: PmRadii.rmd),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.secondaryContainer,
      disabledColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      labelStyle: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(
        color: colorScheme.onSecondaryContainer,
      ),
      checkmarkColor: colorScheme.onSecondaryContainer,
      deleteIconColor: colorScheme.onSurfaceVariant,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: PmRadii.rsm),
      padding: const EdgeInsets.symmetric(
        horizontal: PmSpacing.sm,
        vertical: PmSpacing.xs,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant, size: 18),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: PmElevations.level3,
      shape: PmRadii.dialogShape,
      titleTextStyle: textTheme.headlineSmall?.copyWith(
        color: colorScheme.onSurface,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: colorScheme.surfaceContainerLow,
      elevation: PmElevations.level1,
      modalElevation: PmElevations.level1,
      showDragHandle: true,
      dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      shape: PmRadii.bottomSheetShape,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      actionTextColor: colorScheme.inversePrimary,
      shape: RoundedRectangleBorder(borderRadius: PmRadii.rmd),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: PmSpacing.lg,
        vertical: PmSpacing.md,
      ),
      elevation: PmElevations.level3,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      elevation: PmElevations.level2,
      focusElevation: PmElevations.level3,
      hoverElevation: PmElevations.level3,
      shape: RoundedRectangleBorder(borderRadius: PmRadii.rlg),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: PmRadii.rxxl),
        padding: const EdgeInsets.symmetric(
          horizontal: PmSpacing.xl,
          vertical: PmSpacing.md,
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: PmRadii.rxxl),
        padding: const EdgeInsets.symmetric(
          horizontal: PmSpacing.xl,
          vertical: PmSpacing.md,
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: PmRadii.rxxl),
        padding: const EdgeInsets.symmetric(
          horizontal: PmSpacing.xl,
          vertical: PmSpacing.md,
        ),
        side: BorderSide(color: colorScheme.outline),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: PmRadii.rxxl),
        padding: const EdgeInsets.symmetric(
          horizontal: PmSpacing.lg,
          vertical: PmSpacing.sm,
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: colorScheme.secondaryContainer,
        selectedForegroundColor: colorScheme.onSecondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: PmRadii.rxxl),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: colorScheme.surfaceContainerHighest,
      circularTrackColor: colorScheme.surfaceContainerHighest,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: PmRadii.rsm,
      ),
      textStyle: textTheme.bodySmall?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: PmSpacing.md,
        vertical: PmSpacing.sm,
      ),
      waitDuration: const Duration(milliseconds: 500),
    ),
    iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant, size: 24),
    badgeTheme: BadgeThemeData(
      backgroundColor: colorScheme.error,
      textColor: colorScheme.onError,
      textStyle: textTheme.labelSmall,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: PmRadii.rmd),
      collapsedShape: RoundedRectangleBorder(borderRadius: PmRadii.rmd),
      tilePadding: const EdgeInsets.symmetric(horizontal: PmSpacing.lg),
      childrenPadding: const EdgeInsets.fromLTRB(
        PmSpacing.lg,
        0,
        PmSpacing.lg,
        PmSpacing.lg,
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: PmElevations.level1,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurface.withValues(alpha: 0.38);
        }
        if (states.contains(WidgetState.selected)) {
          return colorScheme.onPrimary;
        }
        return colorScheme.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.surfaceContainerHighest;
        }
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary;
        }
        return colorScheme.surfaceContainerHighest;
      }),
    ),
  );
}

TextTheme _buildTextTheme(TextTheme base, ColorScheme scheme) {
  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(
      fontWeight: FontWeight.w400,
      letterSpacing: -0.5,
    ),
    headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w600),
    headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w500),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: base.bodyLarge?.copyWith(color: scheme.onSurface, height: 1.4),
    bodyMedium: base.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.4,
    ),
  );
}

SystemUiOverlayStyle buildOverlayStyle(
  ThemeData theme, {
  Color? systemNavigationBarColor,
}) {
  final scheme = theme.colorScheme;
  final navBarColor = systemNavigationBarColor ?? scheme.surface;
  return switch (theme.brightness) {
    Brightness.light => SystemUiOverlayStyle.dark.copyWith(
      systemNavigationBarColor: navBarColor,
      systemNavigationBarDividerColor: navBarColor,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
    Brightness.dark => SystemUiOverlayStyle.light.copyWith(
      systemNavigationBarColor: navBarColor,
      systemNavigationBarDividerColor: navBarColor,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  };
}
