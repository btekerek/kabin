import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Single source of truth for Kabin's look: one accent color used
/// sparingly for actions, neutral/desaturated surfaces everywhere else,
/// rounded flat components instead of Material's default shadowed ones.
/// Light only for now - dark mode isn't built yet.
class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF3457D5);
  static const radius = 12.0;
  static const cardRadius = 16.0;

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );

    final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);
    final textTheme = base.textTheme.copyWith(
      headlineSmall:
          base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium:
          base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      titleLarge:
          base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium:
          base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall:
          base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        letterSpacing: 0.3,
        color: colorScheme.onSurfaceVariant,
      ),
      bodySmall: base.textTheme.bodySmall
          ?.copyWith(color: colorScheme.onSurfaceVariant),
    );

    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );

    return base.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.05), colorScheme.surface),
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(cardRadius)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(cardRadius)),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1.2),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      dividerTheme: DividerThemeData(
          color: colorScheme.outlineVariant, thickness: 1, space: 32),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
