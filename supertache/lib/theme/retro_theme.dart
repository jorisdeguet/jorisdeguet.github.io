import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RetroTheme {
  // Couleurs mode sombre
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkBg = Color(0xFF1A1A1A);
  static const Color darkCard = Color(0xFF2A2A2A);
  static const Color darkGray = Color(0xFF333333);
  static const Color mediumGray = Color(0xFF666666);
  static const Color lightGray = Color(0xFFCCCCCC);

  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,

      // Police monospace sobre (Roboto Mono comme alternative à Courier)
      textTheme: GoogleFonts.robotoMonoTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.robotoMono(
          fontSize: 32,
          color: white,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.robotoMono(
          fontSize: 24,
          color: white,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: GoogleFonts.robotoMono(
          fontSize: 20,
          color: white,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: GoogleFonts.robotoMono(
          fontSize: 16,
          color: white,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.robotoMono(
          fontSize: 14,
          color: white,
          fontWeight: FontWeight.w500,
        ),
        titleMedium: GoogleFonts.robotoMono(
          fontSize: 12,
          color: white,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.robotoMono(
          fontSize: 14,
          color: white,
        ),
        bodyMedium: GoogleFonts.robotoMono(
          fontSize: 12,
          color: lightGray,
        ),
        bodySmall: GoogleFonts.robotoMono(
          fontSize: 10,
          color: mediumGray,
        ),
        labelLarge: GoogleFonts.robotoMono(
          fontSize: 14,
          color: white,
          fontWeight: FontWeight.w500,
        ),
      ),

      // AppBar sombre
      appBarTheme: AppBarTheme(
        backgroundColor: black,
        foregroundColor: white,
        elevation: 0,
        titleTextStyle: GoogleFonts.robotoMono(
          fontSize: 16,
          color: white,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: white, size: 24),
      ),

      // Cards sombres avec bordures simples
      cardTheme: const CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: mediumGray, width: 1),
          borderRadius: BorderRadius.zero,
        ),
        margin: EdgeInsets.all(8),
      ),

      // Boutons avec style sobre
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: white,
          foregroundColor: black,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.robotoMono(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: white,
          side: const BorderSide(color: white, width: 1),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.robotoMono(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Input fields sombres
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: mediumGray, width: 1),
          borderRadius: BorderRadius.zero,
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: mediumGray, width: 1),
          borderRadius: BorderRadius.zero,
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: white, width: 2),
          borderRadius: BorderRadius.zero,
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: mediumGray, width: 1),
          borderRadius: BorderRadius.zero,
        ),
        labelStyle: GoogleFonts.robotoMono(
          fontSize: 12,
          color: lightGray,
        ),
        hintStyle: GoogleFonts.robotoMono(
          fontSize: 12,
          color: mediumGray,
        ),
      ),

      // Drawer sombre
      drawerTheme: const DrawerThemeData(
        backgroundColor: darkBg,
        elevation: 0,
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: mediumGray,
        thickness: 1,
        space: 16,
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textColor: white,
        iconColor: white,
        titleTextStyle: GoogleFonts.robotoMono(
          fontSize: 14,
          color: white,
        ),
        subtitleTextStyle: GoogleFonts.robotoMono(
          fontSize: 12,
          color: lightGray,
        ),
      ),

      // Icons
      iconTheme: const IconThemeData(
        color: white,
        size: 24,
      ),

      // Progress indicators
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: white,
      ),

      // Sliders
      sliderTheme: const SliderThemeData(
        activeTrackColor: white,
        inactiveTrackColor: mediumGray,
        thumbColor: white,
        overlayColor: Color(0x33FFFFFF),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCard,
        contentTextStyle: GoogleFonts.robotoMono(
          fontSize: 12,
          color: white,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: darkCard,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: mediumGray, width: 1),
          borderRadius: BorderRadius.zero,
        ),
        titleTextStyle: GoogleFonts.robotoMono(
          fontSize: 16,
          color: white,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: GoogleFonts.robotoMono(
          fontSize: 12,
          color: lightGray,
        ),
      ),

      colorScheme: const ColorScheme.dark(
        primary: white,
        secondary: lightGray,
        surface: darkCard,
        error: mediumGray,
        onPrimary: black,
        onSecondary: black,
        onSurface: white,
        onError: white,
      ),

      useMaterial3: false,
    );
  }
}

/// Bordure simple (conservée pour compatibilité mais simplifiée)
class PixelBorder extends OutlinedBorder {
  const PixelBorder({
    this.pixelSize = 0.0,
    super.side = const BorderSide(color: Color(0xFF666666), width: 1),
  });

  final double pixelSize;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) {
    return PixelBorder(
      pixelSize: pixelSize * t,
      side: side.scale(t),
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect.deflate(side.width));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;

    final paint = Paint()
      ..color = side.color
      ..strokeWidth = side.width
      ..style = PaintingStyle.stroke;

    canvas.drawRect(rect.deflate(side.width / 2), paint);
  }

  @override
  PixelBorder copyWith({BorderSide? side, double? pixelSize}) {
    return PixelBorder(
      side: side ?? this.side,
      pixelSize: pixelSize ?? this.pixelSize,
    );
  }
}

