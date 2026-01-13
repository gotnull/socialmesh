import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../providers/glyph_provider.dart';
import '../../services/glyph_service.dart';
import '../../utils/snackbar.dart';
import 'widgets/glyph_matrix_preview.dart';

/// Advanced glyph pattern builder with multi-channel control
class GlyphPatternBuilderScreen extends ConsumerStatefulWidget {
  const GlyphPatternBuilderScreen({super.key});

  @override
  ConsumerState<GlyphPatternBuilderScreen> createState() =>
      _GlyphPatternBuilderScreenState();
}

class _GlyphPatternBuilderScreenState
    extends ConsumerState<GlyphPatternBuilderScreen> {
  final List<GlyphChannel> _channels = [];

  @override
  void initState() {
    super.initState();
    // Start with one channel
    _channels.add(
      const GlyphChannel(zone: GlyphZone.a, period: 300, cycles: 1),
    );
  }

  void _addChannel() {
    setState(() {
      _channels.add(
        const GlyphChannel(zone: GlyphZone.a, period: 300, cycles: 1),
      );
    });
  }

  void _removeChannel(int index) {
    setState(() {
      _channels.removeAt(index);
    });
  }

  void _updateChannel(int index, GlyphChannel channel) {
    setState(() {
      _channels[index] = channel;
    });
  }

  Future<void> _testPattern() async {
    if (_channels.isEmpty) {
      if (mounted) {
        showErrorSnackBar(context, 'Add at least one channel');
      }
      return;
    }

    final glyphService = ref.read(glyphServiceProvider);
    await glyphService.advancedPattern(channels: _channels);

    if (mounted) {
      showSuccessSnackBar(context, 'Pattern executed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          'Pattern Builder',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _testPattern,
            tooltip: 'Test Pattern',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _channels.length + 1, // +1 for preview at top
              itemBuilder: (context, index) {
                // First item: Matrix preview
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GlyphMatrixPreview(
                      activeZones: _channels.map((c) => c.zone).toList(),
                      showLabels: true,
                    ),
                  );
                }

                // Subsequent items: Channel cards
                final channelIndex = index - 1;
                return _ChannelCard(
                  key: ValueKey(channelIndex),
                  channel: _channels[channelIndex],
                  index: channelIndex,
                  onUpdate: (channel) => _updateChannel(channelIndex, channel),
                  onRemove: _channels.length > 1
                      ? () => _removeChannel(channelIndex)
                      : null,
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.card,
              border: Border(top: BorderSide(color: context.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: BouncyTap(
                    onTap: _addChannel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: context.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.primary),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: context.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Add Channel',
                            style: TextStyle(
                              color: context.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                BouncyTap(
                  onTap: _testPattern,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.primary,
                          context.primary.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: context.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatefulWidget {
  final GlyphChannel channel;
  final int index;
  final ValueChanged<GlyphChannel> onUpdate;
  final VoidCallback? onRemove;

  const _ChannelCard({
    required super.key,
    required this.channel,
    required this.index,
    required this.onUpdate,
    this.onRemove,
  });

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  late GlyphZone _zone;
  late double _period;
  late double _cycles;
  double? _interval;

  @override
  void initState() {
    super.initState();
    _zone = widget.channel.zone;
    _period = widget.channel.period.toDouble();
    _cycles = widget.channel.cycles.toDouble();
    _interval = widget.channel.interval?.toDouble();
  }

  void _updateChannel() {
    widget.onUpdate(
      GlyphChannel(
        zone: _zone,
        period: _period.toInt(),
        cycles: _cycles.toInt(),
        interval: _interval?.toInt(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Channel ${widget.index + 1}',
                  style: TextStyle(
                    color: context.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (widget.onRemove != null)
                BouncyTap(
                  onTap: widget.onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.red,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Zone',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: GlyphZone.values.map((zone) {
              final isSelected = zone == _zone;
              return BouncyTap(
                onTap: () {
                  setState(() {
                    _zone = zone;
                  });
                  _updateChannel();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.primary.withValues(alpha: 0.2)
                        : context.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? context.primary : context.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        zone.displayName,
                        style: TextStyle(
                          color: isSelected
                              ? context.primary
                              : context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        zone.description,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _buildSlider('Period', '${_period.toInt()}ms', _period, 50, 2000, (
            value,
          ) {
            setState(() {
              _period = value;
            });
            _updateChannel();
          }),
          const SizedBox(height: 12),
          _buildSlider('Cycles', '${_cycles.toInt()}x', _cycles, 1, 10, (
            value,
          ) {
            setState(() {
              _cycles = value;
            });
            _updateChannel();
          }),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _interval != null,
                onChanged: (value) {
                  setState(() {
                    _interval = value == true ? 100 : null;
                  });
                  _updateChannel();
                },
                activeColor: context.primary,
              ),
              Text(
                'Interval',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (_interval != null) ...[
            const SizedBox(height: 8),
            _buildSlider(
              'Delay',
              '${_interval!.toInt()}ms',
              _interval!,
              0,
              1000,
              (value) {
                setState(() {
                  _interval = value;
                });
                _updateChannel();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlider(
    String label,
    String value,
    double currentValue,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: context.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(
          value: currentValue,
          min: min,
          max: max,
          divisions: ((max - min) / (max > 100 ? 10 : 1)).toInt(),
          activeColor: context.primary,
          inactiveColor: context.primary.withValues(alpha: 0.2),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
