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
}
