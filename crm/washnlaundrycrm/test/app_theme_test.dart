import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/theme/app_theme.dart';

void main() {
  group('switch theme', () {
    final theme = buildAppTheme(ThemeData().textTheme).switchTheme;

    Color? track(Set<WidgetState> s) => theme.trackColor!.resolve(s);
    Color? thumb(Set<WidgetState> s) => theme.thumbColor!.resolve(s);

    test('on is solid green with a white knob', () {
      final on = {WidgetState.selected};
      expect(track(on), AppColors.success);
      expect(thumb(on), Colors.white);
    });

    test('off is faded: translucent knob, track and outline', () {
      const off = <WidgetState>{};
      expect(thumb(off)!.a, lessThan(1));
      expect(track(off)!.a, lessThan(1));
      expect(theme.trackOutlineColor!.resolve(off)!.a, lessThan(1));
    });

    test('a disabled switch is fainter than an enabled one, on or off', () {
      for (final selected in [true, false]) {
        final enabled = {if (selected) WidgetState.selected};
        final disabled = {...enabled, WidgetState.disabled};
        expect(track(disabled)!.a, lessThan(track(enabled)!.a));
        expect(thumb(disabled)!.a, lessThan(thumb(enabled)!.a));
      }
    });
  });

  group('mobile typography and tokens', () {
    final theme = buildAppTheme(ThemeData().textTheme);

    test('scales down titles to 17-18px w600 with tight tracking', () {
      expect(theme.textTheme.titleLarge?.fontSize, 18);
      expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w600);
      expect(theme.textTheme.titleLarge?.letterSpacing, -0.3);
      expect(AppTypography.title.fontSize, inInclusiveRange(17, 18));
      expect(AppTypography.title.fontWeight, FontWeight.w600);
      expect(AppTypography.title.letterSpacing, -0.3);
    });

    test('KPI/Hero numbers scaled to 18-20px w700 with -0.4 tracking', () {
      expect(theme.textTheme.headlineMedium?.fontSize, 20);
      expect(theme.textTheme.headlineMedium?.fontWeight, FontWeight.w700);
      expect(theme.textTheme.headlineMedium?.letterSpacing, -0.4);
      expect(theme.textTheme.headlineSmall?.fontSize, 18);
      expect(theme.textTheme.headlineSmall?.fontWeight, FontWeight.w700);
      expect(theme.textTheme.headlineSmall?.letterSpacing, -0.4);
      expect(AppTypography.kpiHero.fontSize, inInclusiveRange(18, 20));
      expect(AppTypography.kpiHero.fontWeight, FontWeight.w700);
    });

    test('section titles scaled to 14-15px w600', () {
      expect(theme.textTheme.titleMedium?.fontSize, 15);
      expect(theme.textTheme.titleMedium?.fontWeight, FontWeight.w600);
      expect(theme.textTheme.titleSmall?.fontSize, 14);
      expect(theme.textTheme.titleSmall?.fontWeight, FontWeight.w600);
      expect(AppTypography.sectionTitle.fontSize, inInclusiveRange(14, 15));
      expect(AppTypography.sectionTitle.fontWeight, FontWeight.w600);
    });

    test('body scaled to 13-14px w400/w500', () {
      expect(theme.textTheme.bodyLarge?.fontSize, 14);
      expect(theme.textTheme.bodyLarge?.fontWeight, FontWeight.w500);
      expect(theme.textTheme.bodyMedium?.fontSize, 13);
      expect(theme.textTheme.bodyMedium?.fontWeight, FontWeight.w400);
      expect(AppTypography.body.fontSize, inInclusiveRange(13, 14));
    });

    test('captions and badges scaled to 10-11.5px w600', () {
      expect(theme.textTheme.labelMedium?.fontSize, 11.5);
      expect(theme.textTheme.labelMedium?.fontWeight, FontWeight.w600);
      expect(theme.textTheme.labelSmall?.fontSize, 10.5);
      expect(theme.textTheme.labelSmall?.fontWeight, FontWeight.w600);
      expect(AppTypography.captionBadge.fontSize, inInclusiveRange(10, 11.5));
      expect(AppTypography.badge.fontSize, inInclusiveRange(10, 11.5));
    });
  });
}
