/// Shape and spacing scale. Before this existed the app used 14 different
/// corner radii and ad-hoc padding; pick the nearest step here instead of
/// inventing a new number.
class AppRadius {
  AppRadius._();

  /// Chips, small tags, inline badges.
  static const xs = 8.0;

  /// Inner elements: note tiles, banners, small buttons.
  static const sm = 12.0;

  /// Inputs and primary buttons.
  static const md = 14.0;

  /// Cards, sheets, panels — the default container radius.
  static const lg = 16.0;

  /// Bottom sheets and large surfaces.
  static const xl = 20.0;

  /// Fully rounded pills and avatars.
  static const pill = 999.0;
}

/// Spacing scale — multiples of 4, so vertical rhythm stays consistent.
class AppSpace {
  AppSpace._();

  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}
