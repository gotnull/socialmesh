import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/theme.dart';

void main() {
  group('AccentColors', () {
    test('all list contains 18 colors', () {
      expect(AccentColors.all.length, 18);
    });

    test('names list has same length as all list', () {
      expect(AccentColors.names.length, AccentColors.all.length);
    });

    test('gradients list has same length as all list', () {
      expect(AccentColors.gradients.length, AccentColors.all.length);
    });

    test('each gradient has exactly 8 colors', () {
      for (int i = 0; i < AccentColors.gradients.length; i++) {
        expect(
          AccentColors.gradients[i].length,
          8,
          reason: 'Gradient at index $i should have 8 colors',
        );
      }
    });

    test('gradientFor returns correct gradient for each accent color', () {
      for (int i = 0; i < AccentColors.all.length; i++) {
        final color = AccentColors.all[i];
        final gradient = AccentColors.gradientFor(color);
        expect(
          gradient,
          AccentColors.gradients[i],
          reason:
              'gradientFor(${AccentColors.names[i]}) should return gradient at index $i',
        );
      }
    });

    test('gradientFor returns default gradient for unknown color', () {
      final unknownColor = const Color(0xFF123456);
      final gradient = AccentColors.gradientFor(unknownColor);
      expect(
        gradient,
        AccentColors.gradients[0],
      ); // Default to magenta gradient
    });

    test('nameFor returns correct name for each color', () {
      for (int i = 0; i < AccentColors.all.length; i++) {
        final color = AccentColors.all[i];
        final name = AccentColors.nameFor(color);
        expect(
          name,
          AccentColors.names[i],
          reason: 'nameFor should return ${AccentColors.names[i]}',
        );
      }
    });

    test('nameFor returns Custom for unknown color', () {
      final unknownColor = const Color(0xFF123456);
      final name = AccentColors.nameFor(unknownColor);
      expect(name, 'Custom');
    });

    test('specific color values are correct', () {
      expect(AccentColors.magenta, const Color(0xFFE91E8C));
      expect(AccentColors.purple, const Color(0xFF8B5CF6));
      expect(AccentColors.blue, const Color(0xFF4F6AF6));
      expect(AccentColors.cyan, const Color(0xFF06B6D4));
      expect(AccentColors.teal, const Color(0xFF14B8A6));
      expect(AccentColors.green, const Color(0xFF22C55E));
      expect(AccentColors.lime, const Color(0xFF84CC16));
      expect(AccentColors.yellow, const Color(0xFFEAB308));
      expect(AccentColors.orange, const Color(0xFFF97316));
      expect(AccentColors.red, const Color(0xFFEF4444));
      expect(AccentColors.pink, const Color(0xFFEC4899));
      expect(AccentColors.rose, const Color(0xFFF43F5E));
    });
  });
}
