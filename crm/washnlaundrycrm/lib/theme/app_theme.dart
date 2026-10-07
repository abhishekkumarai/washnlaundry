import 'package:flutter/material.dart';

/// The marketing site's palette (src/app/globals.css), named once so the theme
/// below and any widget that needs a token share one definition.
class AppColors {
  static const background = Color(0xFFF8F7F5); // warm paper
  static const card = Colors.white;
  static const ink = Color(0xFF141A24);
  static const primary = Color(0xFF182C4F); // navy
  static const primaryHover = Color(0xFF101E38);
  static const onPrimary = Color(0xFFFAF9F6);
  static const accent = Color(0xFF2563EB);
  static const accentSoft = Color(0xFFEFF6FF);
  static const muted = Color(0xFF64748B);
  static const mutedFill = Color(0xFFF1EFEA);
  static const border = Color(0xFFE4E0D8);
  static const borderSubtle = Color(0xFFECE9E2);
  static const danger = Color(0xFFDC2626);
  static const success = Color(0xFF10B981); // "active" / on
}

/// One theme for the whole app, so Material widgets (buttons, fields, cards,
/// dialogs, chips, switches…) look right without per-screen styling.
///
/// Deliberately sets colors, shapes and text weight only — no paddings or
/// minimum sizes — so no screen's layout shifts. Widgets that already style
/// themselves (`FilledButton.styleFrom(...)`, an explicit `InputDecoration`)
/// keep doing so; the theme only fills in what they leave unset.
ThemeData buildAppTheme(TextTheme baseTextTheme) {
  const radius = 10.0;
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  const hairline = BorderSide(color: AppColors.border);

  OutlineInputBorder field(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
      );

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.accent,
    surface: AppColors.background,
    onSurface: AppColors.ink,
    outline: AppColors.border,
    outlineVariant: AppColors.borderSubtle,
    error: AppColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: baseTextTheme,
    scaffoldBackgroundColor: AppColors.background,
    dividerColor: AppColors.borderSubtle,
    dividerTheme: const DividerThemeData(color: AppColors.borderSubtle),

    // Buttons
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: hairline,
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    // Text fields: a hairline outline for fields that don't style themselves.
    // Only `border` is set here, deliberately: Flutter applies a theme's
    // enabled/focused/error borders even to a field that passes
    // `border: InputBorder.none`, which drew a second box inside every
    // custom-built search bar and field.
    inputDecorationTheme: InputDecorationThemeData(
      border: field(AppColors.border),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: AppColors.primary.withValues(alpha: 0.2),
    ),

    // Surfaces
    cardTheme: CardThemeData(
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hairline,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      shape: shape,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),

    // Selection controls and chips
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.accentSoft,
      checkmarkColor: AppColors.primary,
      side: hairline,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.ink),
    ),
    // On is green at full strength (the same green as Active elsewhere); Off is
    // faded so an enabled toggle reads as "on" at a glance, and a toggle that
    // can't be used (disabled) fades further.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        final on = s.contains(WidgetState.selected);
        final disabled = s.contains(WidgetState.disabled);
        return (on ? Colors.white : AppColors.muted)
            .withValues(alpha: disabled ? 0.38 : (on ? 1 : 0.5));
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        final on = s.contains(WidgetState.selected);
        final disabled = s.contains(WidgetState.disabled);
        return (on ? AppColors.success : AppColors.mutedFill)
            .withValues(alpha: disabled ? 0.38 : (on ? 1 : 0.6));
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) {
        final on = s.contains(WidgetState.selected);
        final disabled = s.contains(WidgetState.disabled);
        return (on ? AppColors.success : AppColors.border)
            .withValues(alpha: disabled ? 0.38 : (on ? 1 : 0.6));
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.primary : null),
      checkColor: const WidgetStatePropertyAll(AppColors.onPrimary),
      side: const BorderSide(color: AppColors.muted, width: 1.5),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.mutedFill,
    ),

    // Three-dots / dropdown menus: the same white, hairline-bordered surface the
    // menus that style themselves already use, so Credits and Reports match.
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: hairline,
      ),
    ),

    // Lists, tabs, tables
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.muted,
      textColor: AppColors.ink,
      selectedColor: AppColors.primary,
      selectedTileColor: AppColors.accentSoft,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.primary,
      dividerColor: AppColors.border,
    ),
    dataTableTheme: const DataTableThemeData(
      headingTextStyle: TextStyle(
          fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.muted),
      dividerThickness: 1,
    ),
  );
}
