import 'package:dynamic_themes/dynamic_themes.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static const int Blue = 0;
  static const int Red = 1;
  static const int Green = 2;
  static const int Dark = 3;

  static String toStr(int themeId) {
    switch (themeId) {
      case Blue:
        return "Light Blue";
      case Red:
        return "Light Red";
      case Green:
        return "Light Green";
      case Dark:
        return "Dark Blue";
      default:
        return "Unknown";
    }
  }

  // generated with http://mcg.mbitson.com/#!?mcgpalette0=%230a549d&themename=mcgtheme
  static const int _bluePrimaryColor = 0xFF0a549d;

  static const MaterialColor blue = MaterialColor(
    _bluePrimaryColor,
    <int, Color>{
      50: Color(0xFFe2eaf3),
      100: Color(0xFFb6cce2),
      200: Color(0xFF85aace),
      300: Color(0xFF5487ba),
      400: Color(0xFF2f6eac),
      500: Color(_bluePrimaryColor),
      600: Color(0xFF094d95),
      700: Color(0xFF07438b),
      800: Color(0xFF053a81),
      900: Color(0xFF03296f),
    },
  );

  // green 51570d
  // blue 0a549d
  // red 820000
  static const int _greenPrimaryColor = 0xFF51570D;

  static const MaterialColor green = MaterialColor(
    _greenPrimaryColor,
    <int, Color>{
      50: Color(0xFFEAEBE2),
      100: Color(0xFFCBCDB6),
      200: Color(0xFFA8AB86),
      300: Color(0xFF858956),
      400: Color(0xFF6B7031),
      500: Color(_greenPrimaryColor),
      600: Color(0xFF4A4F0B),
      700: Color(0xFF404609),
      800: Color(0xFF373C07),
      900: Color(0xFF272C03),
    },
  );

  static const int _redPrimaryColor = 0xFF820000;
  static const MaterialColor red = MaterialColor(
    _redPrimaryColor,
    <int, Color>{
      50: Color(0xFFF0E0E0),
      100: Color(0xFFDAB3B3),
      200: Color(0xFFC18080),
      300: Color(0xFFA84D4D),
      400: Color(0xFF952626),
      500: Color(_redPrimaryColor),
      600: Color(0xFF7A0000),
      700: Color(0xFF6F0000),
      800: Color(0xFF650000),
      900: Color(0xFF520000),
    },
  );

  static MaterialColor primarySwatchForTheme(int theme) {
    switch (theme) {
      case Blue:
        return blue;
      case Red:
        return red;
      case Green:
        return green;
      case Dark:
        return Colors.grey;
      default:
        return blue;
    }
  }

  static MaterialColor primarySwatchFromContext(BuildContext context) {
    final themeId = DynamicTheme.of(context)?.themeId ?? Blue;

    return primarySwatchForTheme(themeId);
  }
}
