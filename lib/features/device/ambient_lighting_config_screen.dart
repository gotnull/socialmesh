// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/status_banner.dart';

/// Ambient Lighting configuration screen
class AmbientLightingConfigScreen extends ConsumerStatefulWidget {
  const AmbientLightingConfigScreen({super.key});

  @override
  ConsumerState<AmbientLightingConfigScreen> createState() =>
      _AmbientLightingConfigScreenState();
}

class _AmbientLightingConfigScreenState
    extends ConsumerState<AmbientLightingConfigScreen>
    with LifecycleSafeMixin {
  bool _ledState = false;
  int _currentColor = 0xFFFFFFFF;
  int _red = 255;
  int _green = 255;
  int _blue = 255;
  int _current = 10; // LED brightness/current (default 10)
  bool _hasChanges = false;
  bool _isSaving = false;
  bool _isLoading = true;

  final List<int> _presetColors = [
    0xFFFF0000, // Red
    0xFFFF6600, // Orange
    0xFFFFFF00, // Yellow
    0xFF00FF00, // Green
    0xFF00FFFF, // Cyan
    0xFF0000FF, // Blue
    0xFFFF00FF, // Magenta
    0xFFFFFFFF, // White
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final protocol = ref.read(protocolServiceProvider);

    // Check if we're connected before trying to load config
    if (!protocol.isConnected) {
      safeSetState(() => _isLoading = false);
      return;
    }

    final config = await protocol.getAmbientLightingModuleConfig();
    if (config != null && mounted) {
      safeSetState(() {
        _ledState = config.ledState;
        _red = config.red;
        _green = config.green;
        _blue = config.blue;
        _current = config.current > 0 ? config.current : 10;
        _currentColor = (0xFF << 24) | (_red << 16) | (_green << 8) | _blue;
        _isLoading = false;
      });
    } else {
      safeSetState(() => _isLoading = false);
    }
  }

  void _updateColor() {
    setState(() {
      _currentColor = (0xFF << 24) | (_red << 16) | (_green << 8) | _blue;
      _hasChanges = true;
    });
  }

  Future<void> _save() async {
    safeSetState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setAmbientLightingConfig(
        ledState: _ledState,
        red: _red,
        green: _green,
        blue: _blue,
        current: _current,
      );

      safeSetState(() => _hasChanges = false);
      if (mounted) {
        showSuccessSnackBar(context, 'Ambient lighting saved');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save: $e');
      }
    } finally {
      safeSetState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return GlassScaffold(
        title: 'Ambient Lighting',
        slivers: [const SliverFillRemaining(child: ScreenLoadingIndicator())],
      );
    }

    return GlassScaffold(
      title: 'Ambient Lighting',
      actions: [
        if (_hasChanges)
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.accentColor,
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: context.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // LED State toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LED Enabled',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          'Turn ambient lighting on or off',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    ThemedSwitch(
                      value: _ledState,
                      onChanged: (value) {
                        setState(() {
                          _ledState = value;
                          _hasChanges = true;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Color preview
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Color(_currentColor),
                    shape: BoxShape.circle,
                    boxShadow: _ledState
                        ? [
                            BoxShadow(
                              color: Color(
                                _currentColor,
                              ).withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Preset colors
              Text(
                'Preset Colors',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _presetColors.map((color) {
                  final isSelected = _currentColor == color;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentColor = color;
                        _red = (color >> 16) & 0xFF;
                        _green = (color >> 8) & 0xFF;
                        _blue = color & 0xFF;
                        _hasChanges = true;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // RGB sliders
              Text(
                'Custom Color',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              _ColorSlider(
                label: 'Red',
                value: _red,
                color: Colors.red,
                onChanged: (value) {
                  setState(() {
                    _red = value;
                    _updateColor();
                  });
                },
              ),

              _ColorSlider(
                label: 'Green',
                value: _green,
                color: Colors.green,
                onChanged: (value) {
                  setState(() {
                    _green = value;
                    _updateColor();
                  });
                },
              ),

              _ColorSlider(
                label: 'Blue',
                value: _blue,
                color: Colors.blue,
                onChanged: (value) {
                  setState(() {
                    _blue = value;
                    _updateColor();
                  });
                },
              ),

              const SizedBox(height: 24),

              // LED Brightness/Current
              Text(
                'LED Brightness',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$_current mA',
                            style: TextStyle(
                              color: context.accentColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LED drive current (brightness)',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: context.accentColor,
                        inactiveTrackColor: context.border,
                        thumbColor: context.accentColor,
                        overlayColor: context.accentColor.withValues(
                          alpha: 0.2,
                        ),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _current.toDouble(),
                        min: 1,
                        max: 31,
                        divisions: 30,
                        onChanged: (value) {
                          setState(() {
                            _current = value.toInt();
                            _hasChanges = true;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Info card
              StatusBanner.accent(
                title:
                    'Ambient lighting is only available on devices with LED support (RAK WisBlock, T-Beam, etc.)',
                margin: EdgeInsets.zero,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ColorSlider extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  const _ColorSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.2),
                thumbColor: color,
              ),
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: 255,
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
