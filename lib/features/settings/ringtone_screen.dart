import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../services/audio/rtttl_player.dart';

/// Preset ringtones with name and RTTTL string
class RingtonePreset {
  final String name;
  final String rtttl;
  final String description;

  const RingtonePreset({
    required this.name,
    required this.rtttl,
    required this.description,
  });
}

/// Built-in ringtone presets
const _builtInPresets = [
  RingtonePreset(
    name: 'Meshtastic Default',
    rtttl:
        '24:d=32,o=5,b=565:f6,p,f6,4p,p,f6,p,f6,2p,p,b6,p,b6,p,b6,p,b6,p,b,p,b,p,b,p,b,p,b,p,b,p,b,p,b,1p.,2p.,p',
    description: 'Default Meshtastic notification',
  ),
  RingtonePreset(
    name: 'Nokia Ringtone',
    rtttl: '24:d=4,o=5,b=180:8e6,8d6,f#,g#,8c#6,8b,d,e,8b,8a,c#,e,2a',
    description: 'Classic Nokia tune',
  ),
  RingtonePreset(
    name: 'Zelda Get Item',
    rtttl: '24:d=16,o=5,b=120:g,c6,d6,2g6',
    description: 'Legend of Zelda item sound',
  ),
  RingtonePreset(
    name: 'Mario Coin',
    rtttl: '24:d=8,o=6,b=200:b,e7',
    description: 'Super Mario coin collect',
  ),
  RingtonePreset(
    name: 'Mario Power Up',
    rtttl: 'powerup:d=16,o=5,b=200:g,a,b,c6,d6,e6,f#6,g6,a6,b6,2c7',
    description: 'Super Mario power up',
  ),
  RingtonePreset(
    name: 'Mario Theme',
    rtttl: '24:d=4,o=5,b=100:16e6,16e6,32p,8e6,16c6,8e6,8g6,8p,8g',
    description: 'Super Mario theme (short)',
  ),
  RingtonePreset(
    name: 'Morse CQ',
    rtttl: '24:d=16,o=6,b=120:8c,p,c,p,8c,p,c,4p,8c,p,8c,p,c,p,8c,8p',
    description: 'Morse code CQ call',
  ),
  RingtonePreset(
    name: 'Simple Beep',
    rtttl: '24:d=4,o=5,b=120:c6,p,c6',
    description: 'Simple double beep',
  ),
  RingtonePreset(
    name: 'Alert',
    rtttl: '24:d=8,o=6,b=140:c,e,g,c7,p,c7,g,e,c',
    description: 'Ascending alert tone',
  ),
  RingtonePreset(
    name: 'Ping',
    rtttl: '24:d=16,o=6,b=200:e,p,e',
    description: 'Quick ping sound',
  ),
];

/// Provider for custom ringtone presets stored in SharedPreferences
final customRingtonesProvider =
    StateNotifierProvider<CustomRingtonesNotifier, List<RingtonePreset>>((ref) {
      return CustomRingtonesNotifier();
    });

class CustomRingtonesNotifier extends StateNotifier<List<RingtonePreset>> {
  static const _prefsKey = 'custom_ringtones';

  CustomRingtonesNotifier() : super([]) {
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey) ?? [];

    final presets = <RingtonePreset>[];
    for (final item in saved) {
      final parts = item.split('|||');
      if (parts.length >= 2) {
        presets.add(
          RingtonePreset(
            name: parts[0],
            rtttl: parts[1],
            description: parts.length > 2 ? parts[2] : 'Custom ringtone',
          ),
        );
      }
    }
    state = presets;
  }

  Future<void> _savePresets() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = state
        .map((p) => '${p.name}|||${p.rtttl}|||${p.description}')
        .toList();
    await prefs.setStringList(_prefsKey, encoded);
  }

  Future<void> addPreset(RingtonePreset preset) async {
    state = [...state, preset];
    await _savePresets();
  }

  Future<void> removePreset(int index) async {
    final newState = [...state];
    newState.removeAt(index);
    state = newState;
    await _savePresets();
  }

  Future<void> updatePreset(int index, RingtonePreset preset) async {
    final newState = [...state];
    newState[index] = preset;
    state = newState;
    await _savePresets();
  }
}

class RingtoneScreen extends ConsumerStatefulWidget {
  const RingtoneScreen({super.key});

  @override
  ConsumerState<RingtoneScreen> createState() => _RingtoneScreenState();
}

class _RingtoneScreenState extends ConsumerState<RingtoneScreen> {
  final _rtttlController = TextEditingController();
  final _rtttlPlayer = RtttlPlayer();
  bool _saving = false;
  bool _loading = false;
  bool _playing = false;
  int _selectedPresetIndex = -1;
  bool _showingCustom = false;
  int _playingPresetIndex = -1;
  bool _playingCustomPreset = false;
  String? _validationError;

  /// Validate RTTTL format
  /// Returns null if valid, error message if invalid
  String? _validateRtttl(String rtttl) {
    if (rtttl.trim().isEmpty) {
      return 'RTTTL string cannot be empty';
    }

    final trimmed = rtttl.trim();

    // Must have at least 2 colons (name:defaults:notes or defaults:notes)
    final colonCount = ':'.allMatches(trimmed).length;
    if (colonCount < 1) {
      return 'Invalid format: missing colons. Expected format: name:d=4,o=5,b=120:notes';
    }

    final parts = trimmed.split(':');

    // Get defaults section
    String defaults;
    String notesSection;

    if (parts.length >= 3) {
      defaults = parts[1].toLowerCase();
      notesSection = parts.sublist(2).join(':');
    } else if (parts.length == 2) {
      defaults = parts[0].toLowerCase();
      notesSection = parts[1];
    } else {
      return 'Invalid format: expected name:defaults:notes';
    }

    // Validate defaults section has proper key=value pairs
    bool hasValidDefaults = false;
    for (final part in defaults.split(',')) {
      final kv = part.trim().split('=');
      if (kv.length == 2) {
        final key = kv[0].trim();
        final value = kv[1].trim();
        if (['d', 'o', 'b'].contains(key) && int.tryParse(value) != null) {
          hasValidDefaults = true;
        }
      }
    }

    if (!hasValidDefaults) {
      return 'Invalid defaults: expected d=duration, o=octave, b=bpm';
    }

    // Validate notes section has valid note characters
    if (notesSection.trim().isEmpty) {
      return 'No notes found in RTTTL string';
    }

    final validNotePattern = RegExp(
      r'^[0-9]*[a-gp]#?[0-9]*\.?$',
      caseSensitive: false,
    );
    final notes = notesSection.split(',');

    for (final note in notes) {
      final trimmedNote = note.trim();
      if (trimmedNote.isEmpty) continue;
      if (!validNotePattern.hasMatch(trimmedNote)) {
        return 'Invalid note: "$trimmedNote". Notes should be like c, 8e6, f#, 4p';
      }
    }

    if (notes.where((n) => n.trim().isNotEmpty).isEmpty) {
      return 'No valid notes found';
    }

    return null; // Valid
  }

  void _onRtttlChanged(String value) {
    setState(() {
      _validationError = value.isEmpty ? null : _validateRtttl(value);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentRingtone();
    _rtttlController.addListener(() => _onRtttlChanged(_rtttlController.text));
  }

  @override
  void dispose() {
    _rtttlController.dispose();
    _rtttlPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPreview() async {
    // Stop any preset playback
    if (_playingPresetIndex >= 0) {
      await _rtttlPlayer.stop();
      setState(() {
        _playingPresetIndex = -1;
        _playingCustomPreset = false;
      });
    }

    final validation = _validateRtttl(_rtttlController.text);
    if (validation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_playing) {
      await _rtttlPlayer.stop();
      setState(() => _playing = false);
      return;
    }

    setState(() => _playing = true);

    try {
      await _rtttlPlayer.play(_rtttlController.text.trim());

      // Wait for playback to complete
      while (_rtttlPlayer.isPlaying) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _playing = false);
      }
    }
  }

  Future<void> _playPreset(
    RingtonePreset preset,
    int index, {
    bool isCustom = false,
  }) async {
    // Stop main preview if playing
    if (_playing) {
      await _rtttlPlayer.stop();
      setState(() => _playing = false);
    }

    // If this preset is already playing, stop it
    if (_playingPresetIndex == index && _playingCustomPreset == isCustom) {
      await _rtttlPlayer.stop();
      setState(() {
        _playingPresetIndex = -1;
        _playingCustomPreset = false;
      });
      return;
    }

    // Stop any other preset
    if (_playingPresetIndex >= 0) {
      await _rtttlPlayer.stop();
    }

    setState(() {
      _playingPresetIndex = index;
      _playingCustomPreset = isCustom;
    });

    try {
      await _rtttlPlayer.play(preset.rtttl);

      // Wait for playback to complete
      while (_rtttlPlayer.isPlaying) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) break;
      }
    } catch (e) {
      // Ignore errors during preset playback
    } finally {
      if (mounted) {
        setState(() {
          _playingPresetIndex = -1;
          _playingCustomPreset = false;
        });
      }
    }
  }

  Future<void> _loadCurrentRingtone() async {
    setState(() => _loading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.getRingtone();
      // The response will come via the admin message handler
      // For now we'll just show the text field
    } catch (e) {
      // Ignore - device may not support ringtone
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveRingtone() async {
    final validation = _validateRtttl(_rtttlController.text);
    if (validation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final protocol = ref.read(protocolServiceProvider);
    setState(() => _saving = true);

    try {
      await protocol.setRingtone(_rtttlController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ringtone saved to device'),
            backgroundColor: AppTheme.darkCard,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save ringtone: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _selectPreset(
    RingtonePreset preset,
    int index, {
    bool isCustom = false,
  }) {
    setState(() {
      _rtttlController.text = preset.rtttl;
      _selectedPresetIndex = index;
      _showingCustom = isCustom;
    });
  }

  void _showAddCustomDialog() {
    final nameController = TextEditingController();
    final rtttlController = TextEditingController();
    final descController = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Add Custom Ringtone',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.darkBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rtttlController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                  maxLines: 3,
                  onChanged: (value) {
                    setDialogState(() {
                      dialogError = value.isEmpty
                          ? null
                          : _validateRtttl(value);
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'RTTTL String',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    hintText: '24:d=4,o=5,b=120:c,e,g',
                    hintStyle: TextStyle(
                      color: AppTheme.textTertiary.withValues(alpha: 0.5),
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: AppTheme.darkBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    errorText: dialogError,
                    errorMaxLines: 2,
                    errorStyle: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.darkBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  setDialogState(() {
                    dialogError = 'Name is required';
                  });
                  return;
                }

                final validation = _validateRtttl(rtttlController.text);
                if (validation != null) {
                  setDialogState(() {
                    dialogError = validation;
                  });
                  return;
                }

                ref
                    .read(customRingtonesProvider.notifier)
                    .addPreset(
                      RingtonePreset(
                        name: nameController.text.trim(),
                        rtttl: rtttlController.text.trim(),
                        description: descController.text.trim().isEmpty
                            ? 'Custom ringtone'
                            : descController.text.trim(),
                      ),
                    );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Custom ringtone added'),
                    backgroundColor: AppTheme.darkCard,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRtttlHelp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'RTTTL Format Guide',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'What is RTTTL?',
                'Ring Tone Text Transfer Language (RTTTL) is a format for creating musical output with simple text strings.',
              ),
              _buildHelpSection(
                'Format',
                'name:d=duration,o=octave,b=bpm:notes',
              ),
              _buildHelpSection(
                'Header',
                '• Name: Identifier (often ignored)\n'
                    '• d=N: Default note duration (1,2,4,8,16,32)\n'
                    '• o=N: Default octave (4,5,6,7)\n'
                    '• b=N: Beats per minute',
              ),
              _buildHelpSection(
                'Notes',
                '• c, c#, d, d#, e, f, f#, g, g#, a, a#, b\n'
                    '• p = pause/rest\n'
                    '• Optional duration prefix (4c = quarter note C)\n'
                    '• Optional octave suffix (c6 = C in octave 6)\n'
                    '• Optional dot for 1.5x duration (c.)',
              ),
              _buildHelpSection(
                'Example',
                '24:d=4,o=5,b=120:c,e,g,c6\n\n'
                    'Plays C, E, G, high C at 120 BPM\n'
                    'Default quarter notes in octave 5',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.graphBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.graphBlue.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.link,
                      color: AppTheme.graphBlue.withValues(alpha: 0.8),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Try Nokia Composer online to create and preview RTTTL strings',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryGreen,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontFamily: 'Inter',
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customRingtones = ref.watch(customRingtonesProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Ringtone',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showRtttlHelp,
            icon: const Icon(Icons.help_outline, color: AppTheme.textSecondary),
            tooltip: 'RTTTL Help',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _saveRingtone,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Current RTTTL input
                  const Text(
                    'RTTTL STRING',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textTertiary,
                      letterSpacing: 1,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _rtttlController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Paste or select an RTTTL ringtone...',
                            hintStyle: TextStyle(
                              color: AppTheme.textTertiary.withValues(
                                alpha: 0.5,
                              ),
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: AppTheme.darkBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: _validationError != null
                                  ? const BorderSide(
                                      color: AppTheme.errorRed,
                                      width: 1,
                                    )
                                  : BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: _validationError != null
                                  ? const BorderSide(
                                      color: AppTheme.errorRed,
                                      width: 1,
                                    )
                                  : BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: _validationError != null
                                    ? AppTheme.errorRed
                                    : AppTheme.primaryGreen,
                                width: 1,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        if (_validationError != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 14,
                                color: AppTheme.errorRed,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _validationError!,
                                  style: const TextStyle(
                                    color: AppTheme.errorRed,
                                    fontSize: 12,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Play/Preview button
                            ElevatedButton.icon(
                              onPressed: _playPreview,
                              icon: Icon(
                                _playing ? Icons.stop : Icons.play_arrow,
                                size: 20,
                              ),
                              label: Text(_playing ? 'Stop' : 'Preview'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _playing
                                    ? AppTheme.errorRed
                                    : AppTheme.graphBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () {
                                _rtttlController.clear();
                                setState(() {
                                  _selectedPresetIndex = -1;
                                  _validationError = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Clear'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.textSecondary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap Preview to hear how it sounds, then Save to device',
                          style: TextStyle(
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                            fontSize: 12,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Built-in presets section
                  const Text(
                    'BUILT-IN PRESETS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textTertiary,
                      letterSpacing: 1,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: _builtInPresets.asMap().entries.map((entry) {
                        final index = entry.key;
                        final preset = entry.value;
                        final isSelected =
                            !_showingCustom && _selectedPresetIndex == index;
                        final isPlaying =
                            !_playingCustomPreset &&
                            _playingPresetIndex == index;

                        return Column(
                          children: [
                            InkWell(
                              onTap: () => _selectPreset(preset, index),
                              borderRadius: index == 0
                                  ? const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    )
                                  : index == _builtInPresets.length - 1
                                  ? const BorderRadius.vertical(
                                      bottom: Radius.circular(12),
                                    )
                                  : BorderRadius.zero,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    // Music icon
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryGreen.withValues(
                                                alpha: 0.15,
                                              )
                                            : AppTheme.darkBackground,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isSelected
                                            ? Icons.music_note
                                            : Icons.music_note_outlined,
                                        color: isSelected
                                            ? AppTheme.primaryGreen
                                            : AppTheme.textSecondary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Title and description
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            preset.name,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? AppTheme.primaryGreen
                                                  : Colors.white,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              fontFamily: 'Inter',
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            preset.description,
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 12,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Play button
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Material(
                                        color: isPlaying
                                            ? AppTheme.errorRed.withValues(
                                                alpha: 0.15,
                                              )
                                            : AppTheme.darkBackground,
                                        borderRadius: BorderRadius.circular(20),
                                        child: InkWell(
                                          onTap: () =>
                                              _playPreset(preset, index),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: Icon(
                                            isPlaying
                                                ? Icons.stop
                                                : Icons.play_arrow,
                                            color: isPlaying
                                                ? AppTheme.errorRed
                                                : AppTheme.textSecondary,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Selected indicator
                                    SizedBox(
                                      width: 24,
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check_circle,
                                              color: AppTheme.primaryGreen,
                                              size: 22,
                                            )
                                          : const Icon(
                                              Icons.chevron_right,
                                              color: AppTheme.textTertiary,
                                              size: 22,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (index < _builtInPresets.length - 1)
                              const Divider(
                                height: 1,
                                indent: 68,
                                color: AppTheme.darkBorder,
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Custom presets section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CUSTOM PRESETS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textTertiary,
                          letterSpacing: 1,
                          fontFamily: 'Inter',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showAddCustomDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (customRingtones.isEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.library_music_outlined,
                            size: 48,
                            color: AppTheme.textTertiary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No custom ringtones',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "Add" to create your own presets',
                            style: TextStyle(
                              color: AppTheme.textTertiary.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 12,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: customRingtones.asMap().entries.map((entry) {
                          final index = entry.key;
                          final preset = entry.value;
                          final isSelected =
                              _showingCustom && _selectedPresetIndex == index;
                          final isPlaying =
                              _playingCustomPreset &&
                              _playingPresetIndex == index;

                          return Column(
                            children: [
                              InkWell(
                                onTap: () => _selectPreset(
                                  preset,
                                  index,
                                  isCustom: true,
                                ),
                                borderRadius: index == 0
                                    ? const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      )
                                    : index == customRingtones.length - 1
                                    ? const BorderRadius.vertical(
                                        bottom: Radius.circular(12),
                                      )
                                    : BorderRadius.zero,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      // Music icon
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppTheme.primaryGreen
                                                    .withValues(alpha: 0.15)
                                              : AppTheme.darkBackground,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          isSelected
                                              ? Icons.music_note
                                              : Icons.music_note_outlined,
                                          color: isSelected
                                              ? AppTheme.primaryGreen
                                              : AppTheme.textSecondary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Title and description
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              preset.name,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? AppTheme.primaryGreen
                                                    : Colors.white,
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                fontFamily: 'Inter',
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              preset.description,
                                              style: const TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 12,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Play button
                                      SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: Material(
                                          color: isPlaying
                                              ? AppTheme.errorRed.withValues(
                                                  alpha: 0.15,
                                                )
                                              : AppTheme.darkBackground,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: InkWell(
                                            onTap: () => _playPreset(
                                              preset,
                                              index,
                                              isCustom: true,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            child: Icon(
                                              isPlaying
                                                  ? Icons.stop
                                                  : Icons.play_arrow,
                                              color: isPlaying
                                                  ? AppTheme.errorRed
                                                  : AppTheme.textSecondary,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Delete button (only if not selected)
                                      if (!isSelected)
                                        SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: Material(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            child: InkWell(
                                              onTap: () {
                                                ref
                                                    .read(
                                                      customRingtonesProvider
                                                          .notifier,
                                                    )
                                                    .removePreset(index);
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Preset removed',
                                                    ),
                                                    backgroundColor:
                                                        AppTheme.darkCard,
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                  ),
                                                );
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              child: const Icon(
                                                Icons.delete_outline,
                                                color: AppTheme.textTertiary,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      // Selected indicator (only if selected)
                                      if (isSelected)
                                        const SizedBox(
                                          width: 40,
                                          child: Center(
                                            child: Icon(
                                              Icons.check_circle,
                                              color: AppTheme.primaryGreen,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (index < customRingtones.length - 1)
                                const Divider(
                                  height: 1,
                                  indent: 68,
                                  color: AppTheme.darkBorder,
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Info card
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.warningYellow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.warningYellow.withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: AppTheme.warningYellow.withValues(alpha: 0.8),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tip: Find your device',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Send a message with the bell emoji (🔔) to trigger the ringtone on your device. Great for finding lost nodes!',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }
}
