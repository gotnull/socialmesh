import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;

/// Screen for configuring display settings
class DisplayConfigScreen extends ConsumerStatefulWidget {
  const DisplayConfigScreen({super.key});

  @override
  ConsumerState<DisplayConfigScreen> createState() =>
      _DisplayConfigScreenState();
}

class _DisplayConfigScreenState extends ConsumerState<DisplayConfigScreen> {
  bool _isLoading = false;
  int _screenOnSecs = 60;
  int _autoCarouselSecs = 0;
  bool _flipScreen = false;
  pb.Config_DisplayConfig_DisplayUnits? _units;
  pb.Config_DisplayConfig_DisplayMode? _displayMode;
  bool _headingBold = false;
  bool _wakeOnTapOrMotion = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.getConfig(pb.AdminMessage_ConfigType.DISPLAY_CONFIG);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setDisplayConfig(
        screenOnSecs: _screenOnSecs,
        autoScreenCarouselSecs: _autoCarouselSecs,
        flipScreen: _flipScreen,
        units: _units,
        displayMode: _displayMode,
        headingBold: _headingBold,
        wakeOnTapOrMotion: _wakeOnTapOrMotion,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Display configuration saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Display Configuration'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveConfig,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(title: 'SCREEN'),
                const SizedBox(height: 8),
                _buildScreenSettings(theme),
                const SizedBox(height: 24),
                _SectionHeader(title: 'UNITS & FORMAT'),
                const SizedBox(height: 8),
                _buildUnitsSettings(theme),
                const SizedBox(height: 24),
                _SectionHeader(title: 'DISPLAY MODE'),
                const SizedBox(height: 8),
                _buildDisplayModeSelector(theme),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildScreenSettings(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Screen Timeout: ${_screenOnSecs == 0 ? 'Always On' : '${_screenOnSecs}s'}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'How long before screen turns off',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Slider(
              value: _screenOnSecs.toDouble(),
              min: 0,
              max: 300,
              divisions: 30,
              label: _screenOnSecs == 0 ? 'Always On' : '${_screenOnSecs}s',
              onChanged: (value) {
                setState(() => _screenOnSecs = value.toInt());
              },
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Auto Carousel: ${_autoCarouselSecs == 0 ? 'Disabled' : '${_autoCarouselSecs}s'}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Automatically cycle through screens',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Slider(
              value: _autoCarouselSecs.toDouble(),
              min: 0,
              max: 60,
              divisions: 12,
              label: _autoCarouselSecs == 0 ? 'Off' : '${_autoCarouselSecs}s',
              onChanged: (value) {
                setState(() => _autoCarouselSecs = value.toInt());
              },
            ),
            const Divider(),
            SwitchListTile(
              value: _flipScreen,
              onChanged: (value) => setState(() => _flipScreen = value),
              title: const Text('Flip Screen'),
              subtitle: const Text('Rotate display 180°'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _wakeOnTapOrMotion,
              onChanged: (value) => setState(() => _wakeOnTapOrMotion = value),
              title: const Text('Wake on Tap/Motion'),
              subtitle: const Text('Turn on screen when device is moved'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitsSettings(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Measurement Units',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                _units == pb.Config_DisplayConfig_DisplayUnits.METRIC
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: _units == pb.Config_DisplayConfig_DisplayUnits.METRIC
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              title: const Text('Metric'),
              subtitle: const Text('Kilometers, Celsius'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              onTap: () => setState(
                () => _units = pb.Config_DisplayConfig_DisplayUnits.METRIC,
              ),
            ),
            ListTile(
              leading: Icon(
                _units == pb.Config_DisplayConfig_DisplayUnits.IMPERIAL
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: _units == pb.Config_DisplayConfig_DisplayUnits.IMPERIAL
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              title: const Text('Imperial'),
              subtitle: const Text('Miles, Fahrenheit'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              onTap: () => setState(
                () => _units = pb.Config_DisplayConfig_DisplayUnits.IMPERIAL,
              ),
            ),
            const Divider(),
            SwitchListTile(
              value: _headingBold,
              onChanged: (value) => setState(() => _headingBold = value),
              title: const Text('Bold Headings'),
              subtitle: const Text('Show compass headings in bold'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayModeSelector(ThemeData theme) {
    final modes = [
      (
        pb.Config_DisplayConfig_DisplayMode.DEFAULT,
        'Default',
        'Standard display layout',
        Icons.smartphone,
      ),
      (
        pb.Config_DisplayConfig_DisplayMode.TWOCOLOR,
        'Two Color',
        'Optimized for two-color displays',
        Icons.contrast,
      ),
      (
        pb.Config_DisplayConfig_DisplayMode.INVERTED,
        'Inverted',
        'Dark background, light text',
        Icons.invert_colors,
      ),
      (
        pb.Config_DisplayConfig_DisplayMode.COLOR,
        'Color',
        'Full color display mode',
        Icons.palette,
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Display Mode',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose the display rendering mode',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...modes.map((m) {
              final isSelected = _displayMode == m.$1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _displayMode = m.$1),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withAlpha(100),
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          ? theme.colorScheme.primaryContainer.withAlpha(50)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          m.$4,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.$2,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                              Text(
                                m.$3,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
