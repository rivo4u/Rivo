import 'package:flutter/material.dart';

/// Rivo brand palette — light green + white, locked design system.
/// Keep every screen on these tokens so the app reads as one product.
class AppColors {
  AppColors._();

  static const green = Color(0xFF3DA866);
  static const greenDark = Color(0xFF2E8C55);
  static const greenDarker = Color(0xFF1F6E42);
  static const greenDeep = Color(0xFF123B27);

  static const greenLight = Color(0xFFEAF7EF);
  static const greenMid = Color(0xFFCFEEDB);
  static const greenLine = Color(0xFFD5EEDF);

  static const bg = Color(0xFFFFFFFF);
  static const bgMuted = Color(0xFFEEF4F0);

  static const text = Color(0xFF132018);
  static const textMute = Color(0xFF71857A);
  static const cardBorder = Color(0xFFE7F3EC);

  static const roomDeep = Color(0xFF1C2B22);
  static const roomText = Color(0xFFEAF3EC);
  static const roomTextMute = Color(0xFFCFE3D6);

  static const shadowColor = Color(0x1A123B27);

  static const gradientVip = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6FCF8E), greenDark],
  );

  static const gradientSvip = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [greenDark, greenDarker],
  );

  static const gradientHeader = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [greenLight, bg],
  );
}
