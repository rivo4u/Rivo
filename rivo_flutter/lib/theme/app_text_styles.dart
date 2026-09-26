import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Manrope for headings / numerics, Inter for body & labels.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle heading({double size = 20, FontWeight? weight, Color? color}) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w800,
        color: color ?? AppColors.text,
        letterSpacing: -0.2,
      );

  static TextStyle statNumber({double size = 18, Color? color}) => GoogleFonts.manrope(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? AppColors.text,
      );

  static TextStyle body({double size = 13, FontWeight weight = FontWeight.w500, Color? color}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.text,
      );

  static TextStyle label({double size = 11.5, Color? color}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textMute,
      );
}

class AppShadows {
  AppShadows._();

  static const sm = [
    BoxShadow(color: AppColors.shadowColor, blurRadius: 4, offset: Offset(0, 1)),
  ];
  static const md = [
    BoxShadow(color: AppColors.shadowColor, blurRadius: 18, offset: Offset(0, 6)),
  ];
}

class AppRadius {
  AppRadius._();
  static const lg = 20.0;
  static const md = 14.0;
  static const sm = 10.0;
}
