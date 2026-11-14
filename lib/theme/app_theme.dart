import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet warna dan konfigurasi tema Aloka
/// Gaya Visual: Modern Minimalist dengan nuansa Soft Pastel & Warm Earthy
class AlokaColors {
  AlokaColors._();

  // Background Utama: Warm Off-White / Cream
  static const Color background = Color(0xFFF7F6F2);

  // Surface / Kartu: Pure White & Soft Sand
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceSand = Color(0xFFEFECE6);

  // Teks & Navigasi Gelap: Charcoal Black
  static const Color charcoal = Color(0xFF222222);
  static const Color textSecondary = Color(0xFF6E6D68);
  static const Color textMuted = Color(0xFF9E9C95);

  // Aksen Utama 1: Mustard Gold (kartu utama, tab aktif, ikon kategori)
  static const Color mustardGold = Color(0xFFEBB85E);

  // Aksen Utama 2: Pastel Lime Green (kartu status, bar pemasukan/terpenuhi, indikator positif)
  static const Color pastelLime = Color(0xFFBCE47A);

  // Aksen Utama 3: Terracotta / Coral Red (ilustrasi utama, bar pengeluaran/kekurangan, aksen ikon)
  static const Color terracotta = Color(0xFFE35B3B);

  // Aksen Pendukung: Dusty Blush Pink (lencana nominal, tab sekunder, latar ikon)
  static const Color dustyBlush = Color(0xFFEBD5D0);

  // Warna garis pembatas halus
  static const Color borderSubtle = Color(0xFFE5E2DC);
}

class AlokaTheme {
  AlokaTheme._();

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AlokaColors.background,
      colorScheme: const ColorScheme.light(
        primary: AlokaColors.charcoal,
        secondary: AlokaColors.mustardGold,
        tertiary: AlokaColors.pastelLime,
        surface: AlokaColors.surfaceWhite,
        error: AlokaColors.terracotta,
        onPrimary: AlokaColors.surfaceWhite,
        onSecondary: AlokaColors.charcoal,
        onSurface: AlokaColors.charcoal,
        onError: AlokaColors.surfaceWhite,
      ),
      textTheme: baseTextTheme.copyWith(
        // Judul Utama & Angka Saldo: Plus Jakarta Sans Bold - SemiBold berukuran besar
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AlokaColors.charcoal,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AlokaColors.charcoal,
          letterSpacing: -0.4,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AlokaColors.charcoal,
        ),
        // Subjudul & Label Navigasi: Medium hingga Semi-Bold berukuran sedang
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AlokaColors.charcoal,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AlokaColors.charcoal,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AlokaColors.charcoal,
        ),
        // Teks Sekunder & Metadata: Regular berukuran kecil dengan kontras redup
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AlokaColors.charcoal,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AlokaColors.textSecondary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AlokaColors.textMuted,
        ),
      ),
      cardTheme: CardThemeData(
        color: AlokaColors.surfaceWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AlokaColors.surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(
          fontSize: 13,
          color: AlokaColors.textMuted,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AlokaColors.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AlokaColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AlokaColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AlokaColors.mustardGold, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AlokaColors.terracotta, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AlokaColors.charcoal,
          foregroundColor: AlokaColors.surfaceWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
