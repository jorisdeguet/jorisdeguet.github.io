import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RetroTheme {
  // Couleurs 8-bits noir et blanc
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkGray = Color(0xFF333333);
  static const Color mediumGray = Color(0xFF666666);
  static const Color lightGray = Color(0xFFCCCCCC);

  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: white,

      // Police rétro 8-bits
      textTheme: GoogleFonts.pressStart2pTextTheme().copyWith(
        displayLarge: GoogleFonts.pressStart2p(
          fontSize: 32,
          color: black,
          height: 1.5,
        ),
        displayMedium: GoogleFonts.pressStart2p(
          fontSize: 24,
          color: black,
          height: 1.5,
        ),
        displaySmall: GoogleFonts.pressStart2p(
          fontSize: 20,
          color: black,
          height: 1.5,
        ),
        headlineMedium: GoogleFonts.pressStart2p(
          fontSize: 16,
          color: black,
          height: 1.5,
        ),
        titleLarge: GoogleFonts.pressStart2p(
          fontSize: 14,
          color: black,
          height: 1.5,
        ),
        titleMedium: GoogleFonts.pressStart2p(
          fontSize: 12,
          color: black,
          height: 1.5,
        ),
        bodyLarge: GoogleFonts.pressStart2p(
          fontSize: 10,
          color: black,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.pressStart2p(
          fontSize: 8,
          color: black,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.pressStart2p(
          fontSize: 7,
          color: mediumGray,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.pressStart2p(
          fontSize: 10,
          color: white,
          height: 1.5,
        ),
      ),

      // AppBar avec style pixelisé
      appBarTheme: AppBarTheme(
        backgroundColor: black,
        foregroundColor: white,
        elevation: 0,
        titleTextStyle: GoogleFonts.pressStart2p(
          fontSize: 12,
          color: white,
          height: 1.5,
        ),
        iconTheme: const IconThemeData(color: white, size: 24),
      ),

      // Cards avec bordures pixelisées
      cardTheme: const CardThemeData(
        color: white,
        elevation: 0,
        shape: PixelBorder(),
        margin: EdgeInsets.all(8),
      ),

      // Boutons avec style rétro
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: black,
          foregroundColor: white,
          elevation: 0,
          shape: const PixelBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.pressStart2p(
            fontSize: 10,
            height: 1.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: black,
          side: const BorderSide(color: black, width: 3),
          shape: const PixelBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.pressStart2p(
            fontSize: 10,
            height: 1.5,
          ),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: black, width: 3),
          borderRadius: BorderRadius.zero,
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: black, width: 3),
          borderRadius: BorderRadius.zero,
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: black, width: 4),
          borderRadius: BorderRadius.zero,
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: darkGray, width: 3),
          borderRadius: BorderRadius.zero,
        ),
        labelStyle: GoogleFonts.pressStart2p(
          fontSize: 8,
          color: mediumGray,
          height: 1.5,
        ),
        hintStyle: GoogleFonts.pressStart2p(
          fontSize: 8,
          color: lightGray,
          height: 1.5,
        ),
      ),

      // Drawer
      drawerTheme: const DrawerThemeData(
        backgroundColor: white,
        elevation: 0,
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: black,
        thickness: 2,
        space: 16,
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const PixelBorder(),
        textColor: black,
        iconColor: black,
        titleTextStyle: GoogleFonts.pressStart2p(
          fontSize: 10,
          color: black,
          height: 1.5,
        ),
        subtitleTextStyle: GoogleFonts.pressStart2p(
          fontSize: 7,
          color: mediumGray,
          height: 1.5,
        ),
      ),

      // Icons
      iconTheme: const IconThemeData(
        color: black,
        size: 24,
      ),

      // Progress indicators
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: black,
      ),

      // Sliders
      sliderTheme: const SliderThemeData(
        activeTrackColor: black,
        inactiveTrackColor: lightGray,
        thumbColor: black,
        overlayColor: Color(0x33000000),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: black,
        contentTextStyle: GoogleFonts.pressStart2p(
          fontSize: 8,
          color: white,
          height: 1.5,
        ),
        shape: const PixelBorder(),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: white,
        elevation: 0,
        shape: const PixelBorder(),
        titleTextStyle: GoogleFonts.pressStart2p(
          fontSize: 12,
          color: black,
          height: 1.5,
        ),
        contentTextStyle: GoogleFonts.pressStart2p(
          fontSize: 8,
          color: black,
          height: 1.5,
        ),
      ),

      colorScheme: const ColorScheme.light(
        primary: black,
        secondary: darkGray,
        surface: white,
        error: mediumGray,
        onPrimary: white,
        onSecondary: white,
        onSurface: black,
        onError: white,
      ),

      useMaterial3: false, // Pour un look plus rétro
    );
  }
}

/// Bordure pixelisée personnalisée
class PixelBorder extends OutlinedBorder {
  const PixelBorder({
    this.pixelSize = 4.0,
    super.side = const BorderSide(color: Color(0xFF000000), width: 3),
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
    return _createPixelPath(rect.deflate(side.width));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _createPixelPath(rect);
  }

  Path _createPixelPath(Rect rect) {
    final path = Path();
    final corners = pixelSize;

    // Haut gauche avec coin pixelisé
    path.moveTo(rect.left + corners, rect.top);

    // Ligne du haut
    path.lineTo(rect.right - corners, rect.top);

    // Coin haut droit
    path.lineTo(rect.right, rect.top + corners);

    // Ligne droite
    path.lineTo(rect.right, rect.bottom - corners);

    // Coin bas droit
    path.lineTo(rect.right - corners, rect.bottom);

    // Ligne du bas
    path.lineTo(rect.left + corners, rect.bottom);

    // Coin bas gauche
    path.lineTo(rect.left, rect.bottom - corners);

    // Ligne gauche
    path.lineTo(rect.left, rect.top + corners);

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;

    final paint = Paint()
      ..color = side.color
      ..strokeWidth = side.width
      ..style = PaintingStyle.stroke;

    canvas.drawPath(getOuterPath(rect, textDirection: textDirection), paint);
  }

  @override
  PixelBorder copyWith({BorderSide? side, double? pixelSize}) {
    return PixelBorder(
      side: side ?? this.side,
      pixelSize: pixelSize ?? this.pixelSize,
    );
  }
}

