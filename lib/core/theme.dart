import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/logging.dart';

/// Available accent colors for the app
class AccentColors {
  static const magenta = Color(0xFFE91E8C);
  static const purple = Color(0xFF8B5CF6);
  static const blue = Color(0xFF4F6AF6);
  static const cyan = Color(0xFF06B6D4);
  static const teal = Color(0xFF14B8A6);
  static const green = Color(0xFF22C55E);
  static const lime = Color(0xFF84CC16);
  static const yellow = Color(0xFFEAB308);
  static const orange = Color(0xFFF97316);
  static const red = Color(0xFFEF4444);
  static const pink = Color(0xFFEC4899);
  static const rose = Color(0xFFF43F5E);

  // Gold gradient colors for premium features
  static const goldDarkYellow = Color(0xFFFFCC00);
  static const goldMetallic = Color(0xFFD4AF37);
  static const goldDarkGoldenrod = Color(0xFFB8860B);
  static const goldBrown = Color(0xFF996515);

  /// Gold gradient for premium buttons
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldDarkYellow, goldMetallic, goldDarkGoldenrod, goldBrown],
  );

  static const List<Color> all = [
    magenta,
    purple,
    blue,
    cyan,
    teal,
    green,
    lime,
    yellow,
    orange,
    red,
    pink,
    rose,
    goldMetallic, // Special: requires Complete Pack
  ];

  static const List<String> names = [
    'Magenta',
    'Purple',
    'Blue',
    'Cyan',
    'Teal',
    'Green',
    'Lime',
    'Yellow',
    'Orange',
    'Red',
    'Pink',
    'Rose',
    'Gold', // Special: requires Complete Pack
  ];

  /// Index of the special Gold color that requires Complete Pack
  static const int goldColorIndex = 12;

  /// Gradient colors for each accent (used for story rings, etc.)
  /// Each gradient has 3 colors that blend well with the base accent
  /// Indexed same as [all] list
  static const List<List<Color>> gradients = [
    // magenta (0xFFE91E8C)
    [
      Color(0xFFE91E8C),
      Color(0xFFEB3698),
      Color(0xFFED4DA4),
      Color(0xFFEF6AB2),
      Color(0xFFED4DA4),
      Color(0xFFEB3698),
      Color(0xFFE61687),
      Color(0xFFD4147C),
    ],

    // purple (0xFF8B5CF6)
    [
      Color(0xFF8B5CF6),
      Color(0xFF9C75F7),
      Color(0xFFAE8DF8),
      Color(0xFFC2AAF9),
      Color(0xFFAE8DF8),
      Color(0xFF9C75F7),
      Color(0xFF8452F6),
      Color(0xFF763FF5),
    ],

    // blue (0xFF4F6AF6)
    [
      Color(0xFF4F6AF6),
      Color(0xFF687FF7),
      Color(0xFF8094F8),
      Color(0xFF9EACF9),
      Color(0xFF8094F8),
      Color(0xFF687FF7),
      Color(0xFF4562F6),
      Color(0xFF3251F5),
    ],

    // cyan (0xFF06B6D4)
    [
      Color(0xFF06B6D4),
      Color(0xFF07CBEC),
      Color(0xFF16D6F7),
      Color(0xFF34DBF7),
      Color(0xFF16D6F7),
      Color(0xFF07CBEC),
      Color(0xFF06AECA),
      Color(0xFF059DB7),
    ],

    // teal (0xFF14B8A6)
    [
      Color(0xFF14B8A6),
      Color(0xFF17CEBA),
      Color(0xFF1AE5CF),
      Color(0xFF36E7D4),
      Color(0xFF1AE5CF),
      Color(0xFF17CEBA),
      Color(0xFF13AF9E),
      Color(0xFF119D8D),
    ],

    // green (0xFF22C55E)
    [
      Color(0xFF22C55E),
      Color(0xFF27D969),
      Color(0xFF3EDC78),
      Color(0xFF58E18A),
      Color(0xFF3EDC78),
      Color(0xFF27D969),
      Color(0xFF20BC5A),
      Color(0xFF1DAB51),
    ],

    // lime (0xFF84CC16)
    [
      Color(0xFF84CC16),
      Color(0xFF93E219),
      Color(0xFF9EE72E),
      Color(0xFFAAEA4A),
      Color(0xFF9EE72E),
      Color(0xFF93E219),
      Color(0xFF7EC315),
      Color(0xFF72B113),
    ],

    // yellow (0xFFEAB308)
    [
      Color(0xFFEAB308),
      Color(0xFFF6C015),
      Color(0xFFF7C62E),
      Color(0xFFF7CE4C),
      Color(0xFFF7C62E),
      Color(0xFFF6C015),
      Color(0xFFE0AC08),
      Color(0xFFCD9D07),
    ],

    // orange (0xFFF97316)
    [
      Color(0xFFF97316),
      Color(0xFFF9822F),
      Color(0xFFF99149),
      Color(0xFFFAA367),
      Color(0xFFF99149),
      Color(0xFFF9822F),
      Color(0xFFF96D0C),
      Color(0xFFEB6406),
    ],

    // red (0xFFEF4444)
    [
      Color(0xFFEF4444),
      Color(0xFFF15C5C),
      Color(0xFFF27474),
      Color(0xFFF49090),
      Color(0xFFF27474),
      Color(0xFFF15C5C),
      Color(0xFFEE3A3A),
      Color(0xFFED2727),
    ],

    // pink (0xFFEC4899)
    [
      Color(0xFFEC4899),
      Color(0xFFEE60A6),
      Color(0xFFF077B3),
      Color(0xFFF393C2),
      Color(0xFFF077B3),
      Color(0xFFEE60A6),
      Color(0xFFEB3F94),
      Color(0xFFE92C8A),
    ],

    // rose (0xFFF43F5E)
    [
      Color(0xFFF43F5E),
      Color(0xFFF55873),
      Color(0xFFF67087),
      Color(0xFFF78D9F),
      Color(0xFFF67087),
      Color(0xFFF55873),
      Color(0xFFF43556),
      Color(0xFFF32245),
    ],

    // gold (Special: requires Complete Pack)
    [
      Color(0xFFD4AF37), // goldMetallic
      Color(0xFFE6C058),
      Color(0xFFF7D179),
      Color(0xFFFFCC00), // goldDarkYellow
      Color(0xFFF7D179),
      Color(0xFFE6C058),
      Color(0xFFB8860B), // goldDarkGoldenrod
      Color(0xFF996515), // goldBrown
    ],
  ];

  /// Get the gradient colors for a given accent color
  static List<Color> gradientFor(Color color) {
    final colorValue = color.toARGB32();
    for (int i = 0; i < all.length; i++) {
      if (all[i].toARGB32() == colorValue) {
        return gradients[i];
      }
    }
    // Default to magenta gradient (index 0)
    return gradients[0];
  }

  static String nameFor(Color color) {
    final colorValue = color.toARGB32();
    for (int i = 0; i < all.length; i++) {
      if (all[i].toARGB32() == colorValue) {
        return names[i];
      }
    }
    return 'Custom';
  }
}

/// Colors used for chart series, widget builder, and data visualization
class ChartColors {
  // Primary series colors - used for data series in charts
  static const blue = Color(0xFF4F6AF6);
  static const green = Color(0xFF4ADE80);
  static const yellow = Color(0xFFFBBF24);
  static const pink = Color(0xFFF472B6);
  static const purple = Color(0xFFA78BFA);
  static const cyan = Color(0xFF22D3EE);
  static const red = Color(0xFFFF6B6B);
  static const orange = Color(0xFFFF9F43);

  // Gradient colors for value-based coloring
  static const gradientGreen = Color(0xFF4CAF50);
  static const gradientRed = Color(0xFFFF5252);
  static const gradientOrange = Color(0xFFFF9800);
  static const gradientPurple = Color(0xFF9C27B0);

  // Threshold colors
  static const thresholdRed = Color(0xFFFF5252);
  static const thresholdYellow = Color(0xFFFBBF24);
  static const thresholdGreen = Color(0xFF4CAF50);
  static const thresholdBlue = Color(0xFF4F6AF6);
  static const thresholdPink = Color(0xFFE91E63);
  static const thresholdPurple = Color(0xFF9C27B0);

  // Category colors for binding categories
  static const categoryNode = Color(0xFF60A5FA);
  static const categoryDevice = Color(0xFFA78BFA);
  static const categoryNetwork = Color(0xFF4ADE80);
  static const categoryEnvironment = Color(0xFF22D3EE);
  static const categoryPower = Color(0xFFFBBF24);
  static const categoryAirQuality = Color(0xFF34D399);
  static const categoryGps = Color(0xFFF472B6);
  static const categoryMessaging = Color(0xFFFF6B6B);

  /// Default series colors for charts (ordered for visual distinction)
  static const List<Color> seriesColors = [
    blue,
    green,
    yellow,
    pink,
    purple,
    cyan,
    red,
    orange,
  ];

  /// Colors available in gradient picker
  static const List<Color> gradientPickerColors = [
    gradientGreen,
    yellow,
    gradientOrange,
    gradientRed,
    blue,
    gradientPurple,
  ];

  /// Colors available in threshold picker
  static const List<Color> thresholdPickerColors = [
    thresholdRed,
    thresholdYellow,
    thresholdGreen,
    thresholdBlue,
    thresholdPink,
    thresholdPurple,
  ];

  /// Get color for a series index (cycles through available colors)
  static Color forIndex(int index) => seriesColors[index % seriesColors.length];
}

/// App taglines shown on splash/connecting screens
const appTaglines = [
  'Off-grid communication.',
  'No towers. No subscriptions.',
  'Your voice. Your network.',
  'Zero knowledge. Zero tracking.',
  'Device to device. Mile after mile.',
  'Build infrastructure together.',
];

/// Notifier for accent color - loads from SharedPreferences on startup
class AccentColorNotifier extends AsyncNotifier<Color> {
  @override
  Future<Color> build() async {
    try {
      // Load saved accent color from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedColorValue = prefs.getInt('accent_color');
      if (savedColorValue != null) {
        return Color(savedColorValue);
      }
    } catch (e) {
      // If SharedPreferences fails, just use default color
      AppLogging.settings('Failed to load accent color from preferences: $e');
    }
    return AccentColors.magenta;
  }

  /// Set accent color and persist to SharedPreferences
  /// This ensures cloud-synced colors persist locally for next app start
  Future<void> setColor(Color color) async {
    state = AsyncData(color);
    // Save to SharedPreferences so it persists on restart
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('accent_color', color.toARGB32());
    } catch (e) {
      AppLogging.settings('Failed to save accent color to preferences: $e');
    }
  }
}

/// Provider for the current accent color
final accentColorProvider = AsyncNotifierProvider<AccentColorNotifier, Color>(
  AccentColorNotifier.new,
);

/// Notifier for theme mode (dark/light/system)
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void setThemeMode(ThemeMode mode) => state = mode;
}

/// Provider for the current theme mode
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class AppTheme {
  // Font families
  static const fontFamily = 'JetBrainsMono';
  static const fontFamilyFallback = 'Inter';

  // Brand colors - extracted from app icon gradient
  static const primaryMagenta = Color(0xFFE91E8C); // Hot pink/magenta
  static const primaryPurple = Color(0xFF8B5CF6); // Purple
  static const primaryBlue = Color(0xFF4F6AF6); // Blue

  // Accent colors
  static const secondaryPink = Color(0xFFF97BBD);
  static const accentOrange = Color(0xFFFF9D6E);
  static const successGreen = Color(0xFF4ADE80);
  static const warningYellow = Color(0xFFFBBF24);
  static const errorRed = Color(0xFFEF4444);

  // Dark theme colors - exact match from design
  static const darkBackground = Color(0xFF1F2633);
  static const darkSurface = Color(0xFF29303D);
  static const darkCard = Color(0xFF29303D);
  static const darkCardAlt = Color(0xFF29303D);
  static const darkBorder = Color(0xFF414A5A);

  // Light theme colors
  static const lightBackground = Color(0xFFF5F7FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightCardAlt = Color(0xFFF0F2F5);
  static const lightBorder = Color(0xFFE0E4EA);

  // Text colors - dark theme
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFD1D5DB);
  static const textTertiary = Color(0xFF9CA3AF);

  // Text colors - light theme
  static const textPrimaryLight = Color(0xFF1A1F2E);
  static const textSecondaryLight = Color(0xFF4B5563);
  static const textTertiaryLight = Color(0xFF9CA3AF);

  // Graph colors
  static const graphPurple = Color(0xFF8B5CF6);
  static const graphBlue = Color(0xFF3B82F6);
  static const graphYellow = Color(0xFFFBBF24);
  static const graphRed = Color(0xFFEF4444);

  // Brand gradient (matches app icon)
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE91E8C), // Magenta
      Color(0xFF8B5CF6), // Purple
      Color(0xFF4F6AF6), // Blue
    ],
  );

  // Horizontal brand gradient for buttons
  static const brandGradientHorizontal = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFE91E8C), // Magenta
      Color(0xFF8B5CF6), // Purple
    ],
  );

  // Gradients
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4A148C), Color(0xFF1A1F2E)],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF374151), Color(0xFF2D3748)],
  );

  /// Create dark theme with the given accent color
  static ThemeData darkTheme(Color accentColor) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color scheme
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        secondary: secondaryPink,
        tertiary: accentOrange,
        surface: darkCard,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        outline: darkBorder,
      ),

      // Professional page transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: ZoomPageTransitionsBuilder(
            allowSnapshotting: true,
            allowEnterRouteSnapshotting: true,
          ),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),

      // Scaffold
      scaffoldBackgroundColor: darkBackground,

      // App bar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 24),
      ),

      // Card
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Text theme
      fontFamily: fontFamily,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          fontFamily: fontFamily,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          fontFamily: fontFamily,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: fontFamily,
          letterSpacing: -0.25,
        ),
        headlineLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: fontFamily,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: fontFamily,
        ),
        headlineSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: fontFamily,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          fontFamily: fontFamily,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          fontFamily: fontFamily,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          fontFamily: fontFamily,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textPrimary,
          fontFamily: fontFamily,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textSecondary,
          fontFamily: fontFamily,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textTertiary,
          fontFamily: fontFamily,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          fontFamily: fontFamily,
          letterSpacing: 0.5,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          fontFamily: fontFamily,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textTertiary,
          fontFamily: fontFamily,
          letterSpacing: 0.5,
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textTertiary),
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      // Filled button
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side: BorderSide(color: accentColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),

      // Switch theme - uses accent color
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentColor;
          }
          return Colors.grey.shade600;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Bottom navigation bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: accentColor,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: darkCard,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: fontFamily,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: textSecondary,
          fontFamily: fontFamily,
        ),
      ),

      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurface,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: fontFamily,
        ),
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        selectedColor: accentColor.withValues(alpha: 0.3),
        disabledColor: darkSurface.withValues(alpha: 0.5),
        labelStyle: const TextStyle(color: textPrimary),
        secondaryLabelStyle: const TextStyle(color: textSecondary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Icon theme
      iconTheme: const IconThemeData(color: textPrimary, size: 24),
    );
  }

  /// Create light theme with the given accent color
  static ThemeData lightTheme(Color accentColor) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color scheme
      colorScheme: ColorScheme.light(
        primary: accentColor,
        secondary: secondaryPink,
        tertiary: accentOrange,
        surface: lightCard,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
        outline: lightBorder,
      ),

      // Professional page transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: ZoomPageTransitionsBuilder(
            allowSnapshotting: true,
            allowEnterRouteSnapshotting: true,
          ),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),

      // Scaffold
      scaffoldBackgroundColor: lightBackground,

      // App bar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: textPrimaryLight,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
        iconTheme: IconThemeData(color: textPrimaryLight, size: 24),
      ),

      // Card
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Text theme
      fontFamily: fontFamily,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimaryLight,
          fontFamily: fontFamily,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimaryLight,
          fontFamily: fontFamily,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
          fontFamily: fontFamily,
          letterSpacing: -0.25,
        ),
        headlineLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
          fontFamily: fontFamily,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
          fontFamily: fontFamily,
        ),
        headlineSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
          fontFamily: fontFamily,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: textPrimaryLight,
          fontFamily: fontFamily,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimaryLight,
          fontFamily: fontFamily,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimaryLight,
          fontFamily: fontFamily,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textPrimaryLight,
          fontFamily: fontFamily,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textSecondaryLight,
          fontFamily: fontFamily,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textTertiaryLight,
          fontFamily: fontFamily,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimaryLight,
          fontFamily: fontFamily,
          letterSpacing: 0.5,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondaryLight,
          fontFamily: fontFamily,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textTertiaryLight,
          fontFamily: fontFamily,
          letterSpacing: 0.5,
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed),
        ),
        labelStyle: const TextStyle(color: textSecondaryLight),
        hintStyle: const TextStyle(color: textTertiaryLight),
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      // Filled button
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side: BorderSide(color: accentColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),

      // Switch theme - uses accent color
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentColor;
          }
          return Colors.grey.shade300;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Bottom navigation bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: accentColor,
        unselectedItemColor: textTertiaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: lightCard,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
          fontFamily: fontFamily,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: textSecondaryLight,
          fontFamily: fontFamily,
        ),
      ),

      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimaryLight,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: fontFamily,
        ),
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: lightSurface,
        selectedColor: accentColor.withValues(alpha: 0.2),
        disabledColor: lightSurface.withValues(alpha: 0.5),
        labelStyle: const TextStyle(color: textPrimaryLight),
        secondaryLabelStyle: const TextStyle(color: textSecondaryLight),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Icon theme
      iconTheme: const IconThemeData(color: textPrimaryLight, size: 24),
    );
  }

  /// @deprecated Use Theme.of(context).colorScheme.primary instead
  /// Legacy alias kept temporarily for compatibility during migration
  static const primaryGreen = AccentColors.magenta;
}

/// Extension on BuildContext for easy accent color access
extension AccentColorExtension on BuildContext {
  /// Returns the current accent color from the theme
  Color get accentColor => Theme.of(this).colorScheme.primary;
}

/// Theme-aware color extension for proper light/dark mode support
/// Use these instead of hardcoded AppTheme.dark* etc.
extension ThemeAwareColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  // Background colors
  Color get background =>
      isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground;
  Color get surface =>
      isDarkMode ? AppTheme.darkSurface : AppTheme.lightSurface;
  Color get surfaceVariant =>
      Theme.of(this).colorScheme.surfaceContainerHighest;
  Color get card => isDarkMode ? AppTheme.darkCard : AppTheme.lightCard;
  Color get cardAlt =>
      isDarkMode ? AppTheme.darkCardAlt : AppTheme.lightCardAlt;
  Color get border => isDarkMode ? AppTheme.darkBorder : AppTheme.lightBorder;

  // Accent colors
  Color get primary => Theme.of(this).colorScheme.primary;

  // Text colors
  Color get textPrimary =>
      isDarkMode ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
  Color get textSecondary =>
      isDarkMode ? AppTheme.textSecondary : AppTheme.textSecondaryLight;
  Color get textTertiary =>
      isDarkMode ? AppTheme.textTertiary : AppTheme.textTertiaryLight;
}

/// Semantic color constants for intentional white usage on colored backgrounds.
/// These remain visually white in both themes - use for content on accent/brand surfaces.
class SemanticColors {
  SemanticColors._();

  /// White foreground for content on accent-colored surfaces (buttons, FABs, badges)
  static const Color onAccent = Colors.white;

  /// White foreground for content on brand gradient backgrounds
  static const Color onBrand = Colors.white;

  /// White foreground for map markers, pins, and overlays on colored backgrounds
  static const Color onMarker = Colors.white;

  /// White for QR code contrast and similar high-contrast requirements
  static const Color highContrast = Colors.white;

  /// Semi-transparent white for glows, gradients, and visual effects
  static Color glow([double opacity = 0.5]) =>
      Colors.white.withValues(alpha: opacity);
}
