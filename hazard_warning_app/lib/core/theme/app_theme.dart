import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const primaryBlue = Color(0xFF0F2D5C);
  static const accentBlue = Color(0xFF2563EB);
  static const lightBlueBg = Color(0xFFEFF6FF);
  static const lightBlueChip = Color(0xFFDBEAFE);
  static const scaffoldBg = Color(0xFFF8FAFC);
  static const borderGrey = Color(0xFFE2E8F0);
  static const textGrey = Color(0xFF64748B);
  static const textDark = Color(0xFF0F172A);
  static const severityHigh = Color(0xFFB91C1C);
  static const severityModerate = Color(0xFFF59E0B);
  static const severityLow = Color(0xFF059669);
  static const offlineBanner = Color(0xFFFFEDD5);
  static const offlineText = Color(0xFF9A3412);
  static const warningBanner = Color(0xFFFFFBEB);
  static const warningText = Color(0xFF92400E);
  static const successGreen = Color(0xFF16A34A);
  static const overCapacity = Color(0xFFFECDD3);
  static const overCapacityText = Color(0xFFB91C1C);
  static const navy = Color(0xFF0A1F44);
  static const navyDeep = Color(0xFF06142E);
  static const surfaceMuted = Color(0xFFF1F5F9);
  static const dangerSoft = Color(0xFFFEF2F2);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F2D5C), Color(0xFF1D4ED8)],
  );
}

class AppShadows {
  static final soft = [
    BoxShadow(
      color: const Color(0xFF0F2D5C).withValues(alpha: 0.07),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

ThemeData buildAppTheme() {
  const radius = 16.0;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.accentBlue,
    brightness: Brightness.light,
    primary: AppColors.primaryBlue,
    onPrimary: Colors.white,
    secondary: AppColors.accentBlue,
    surface: Colors.white,
    onSurface: AppColors.textDark,
    outline: AppColors.borderGrey,
    error: AppColors.severityHigh,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.scaffoldBg,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AppColors.textDark,
        letterSpacing: -0.5,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        color: AppColors.textDark,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        color: AppColors.textGrey,
        height: 1.4,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        side: const BorderSide(color: AppColors.borderGrey, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderGrey),
      ),
    ),
  );
}
