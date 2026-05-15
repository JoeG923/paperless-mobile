import 'package:flutter/material.dart';

/// Centralized design tokens for the Paperless Mobile design system.
///
/// Use these instead of literal numbers so spacing, radii, motion and
/// elevation stay coherent across the app.
class PmSpacing {
  PmSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets pagePadding = EdgeInsets.all(lg);
  static const EdgeInsets pagePaddingHorizontal = EdgeInsets.symmetric(
    horizontal: lg,
  );
  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets dense = EdgeInsets.all(sm);
}

class PmRadii {
  PmRadii._();

  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  static final BorderRadius rxs = BorderRadius.circular(xs);
  static final BorderRadius rsm = BorderRadius.circular(sm);
  static final BorderRadius rmd = BorderRadius.circular(md);
  static final BorderRadius rlg = BorderRadius.circular(lg);
  static final BorderRadius rxl = BorderRadius.circular(xl);
  static final BorderRadius rxxl = BorderRadius.circular(xxl);

  static final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: rmd,
  );
  static final RoundedRectangleBorder dialogShape = RoundedRectangleBorder(
    borderRadius: rxxl,
  );
  static final RoundedRectangleBorder bottomSheetShape =
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(xxl)),
      );
}

class PmDurations {
  PmDurations._();

  static const Duration micro = Duration(milliseconds: 100);
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration long = Duration(milliseconds: 500);
}

class PmElevations {
  PmElevations._();

  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 3;
  static const double level3 = 6;
}

class PmBreakpoints {
  PmBreakpoints._();

  /// Width at which we switch from bottom navigation to a navigation rail.
  static const double mediumWidth = 600;

  /// Width at which the rail becomes extended with labels.
  static const double largeWidth = 840;
}
