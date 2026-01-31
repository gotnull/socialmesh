import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/connection_required_wrapper.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../generated/meshtastic/mesh.pbenum.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;
import '../../providers/app_providers.dart';
import '../../utils/share_utils.dart';
import '../../utils/snackbar.dart';

/// Device log entry with timestamp
class DeviceLogEntry {
  final DateTime timestamp;
  final LogRecord_Level level;
  final String source;
  final String message;

  DeviceLogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });

  factory DeviceLogEntry.fromLogRecord(pb.LogRecord record) {
    return DeviceLogEntry(
      timestamp: record.time > 0
          ? DateTime.fromMillisecondsSinceEpoch(record.time * 1000)
          : DateTime.now(),
      level: record.level,
      source: record.source.isNotEmpty ? record.source : 'firmware',
      message: record.message,
    );
  }
}

/// Convert LogRecord_Level to display color
extension LogRecordLevelColor on LogRecord_Level {
  Color getColor(BuildContext context) {
    switch (this) {
      case LogRecord_Level.TRACE:
      case LogRecord_Level.DEBUG:
        return context.textTertiary;
      case LogRecord_Level.INFO:
        return AccentColors.blue;
      case LogRecord_Level.WARNING:
        return AppTheme.warningYellow;
      case LogRecord_Level.ERROR:
      case LogRecord_Level.CRITICAL:
        return AppTheme.errorRed;
      default:
        return context.textSecondary;
    }
  }

  String get label {
    switch (this) {
      case LogRecord_Level.TRACE:
        return 'TRACE';
      case LogRecord_Level.DEBUG:
        return 'DEBUG';
      case LogRecord_Level.INFO:
        return 'INFO';
      case LogRecord_Level.WARNING:
        return 'WARN';
      case LogRecord_Level.ERROR:
        return 'ERROR';
      case LogRecord_Level.CRITICAL:
        return 'CRIT';
      default:
        return 'UNSET';
    }
  }
}

/// In-memory storage for device logs
class DeviceLogger {
  static final DeviceLogger _instance = DeviceLogger._internal();
  factory DeviceLogger() => _instance;
  DeviceLogger._internal();

  final List<DeviceLogEntry> _logs = [];
  static const int maxLogs = 2000;

  List<DeviceLogEntry> get logs => List.unmodifiable(_logs);

  void add(DeviceLogEntry entry) {
    _logs.add(entry);

    // Trim old logs
    while (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }
  }

  void addFromLogRecord(pb.LogRecord record) {
    add(DeviceLogEntry.fromLogRecord(record));
  }

  void clear() => _logs.clear();

  String export() {
    final buffer = StringBuffer();
    buffer.writeln('=== Device Firmware Logs ===');
    buffer.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');

    for (final entry in _logs) {
      buffer.writeln(
        '[${entry.timestamp.toIso8601String()}] '
        '[${entry.level.label}] '
        '[${entry.source}] '
        '${entry.message}',
      );
    }
    return buffer.toString();
  }
}

/// Provider for device logger
final deviceLoggerProvider = Provider<DeviceLogger>((ref) => DeviceLogger());

/// Notifier for filtered log levels
class DeviceLogFilterNotifier extends Notifier<List<LogRecord_Level>> {
  @override
  List<LogRecord_Level> build() => [
    LogRecord_Level.INFO,
    LogRecord_Level.WARNING,
    LogRecord_Level.ERROR,
    LogRecord_Level.CRITICAL,
  ];

  void setFilters(List<LogRecord_Level> filters) => state = filters;

  void toggleFilter(LogRecord_Level level) {
    if (state.contains(level)) {
      state = state.where((l) => l != level).toList();
    } else {
      state = [...state, level];
    }
  }
}

/// Provider for filtered device logs
final deviceLogFilterProvider =
    NotifierProvider<DeviceLogFilterNotifier, List<LogRecord_Level>>(
      DeviceLogFilterNotifier.new,
    );

class DeviceLogsScreen extends ConsumerStatefulWidget {
  const DeviceLogsScreen({super.key});

  @override
  ConsumerState<DeviceLogsScreen> createState() => _DeviceLogsScreenState();
}

class _DeviceLogsScreenState extends ConsumerState<DeviceLogsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<pb.LogRecord>? _logSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToLogs();
  }

  void _subscribeToLogs() {
    // Subscribe to device log stream
    final deviceLogStream = ref.read(deviceLogStreamProvider.future);
    deviceLogStream
        .then((stream) {
          // Stream is available from the provider
        })
        .catchError((e) {
          // Ignore - transport might not support device logs
        });

    // Use listen on the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Listen to the stream provider
      ref.listen(deviceLogStreamProvider, (previous, next) {
        next.whenData((logRecord) {
          final logger = ref.read(deviceLoggerProvider);
          logger.addFromLogRecord(logRecord);
          if (mounted) setState(() {});

          // Auto-scroll if enabled
          if (_autoScroll && _scrollController.hasClients) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _logSubscription?.cancel();
    super.dispose();
  }

  List<DeviceLogEntry> _getFilteredLogs() {
    final logger = ref.watch(deviceLoggerProvider);
    final filters = ref.watch(deviceLogFilterProvider);

    return logger.logs.where((entry) {
      // Filter by level
      if (!filters.contains(entry.level)) return false;

      // Filter by search
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return entry.message.toLowerCase().contains(query) ||
            entry.source.toLowerCase().contains(query);
      }

      return true;
    }).toList();
  }

  void _showFilterDialog() {
    final filters = ref.read(deviceLogFilterProvider);
    final selected = Set<LogRecord_Level>.from(filters);

    final allLevels = [
      LogRecord_Level.TRACE,
      LogRecord_Level.DEBUG,
      LogRecord_Level.INFO,
      LogRecord_Level.WARNING,
      LogRecord_Level.ERROR,
      LogRecord_Level.CRITICAL,
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.card,
          title: Text(
            'Filter Log Levels',
            style: TextStyle(color: context.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: allLevels.map((level) {
              return CheckboxListTile(
                title: Text(
                  level.label,
                  style: TextStyle(color: level.getColor(context)),
                ),
                value: selected.contains(level),
                activeColor: context.accentColor,
                onChanged: (value) {
                  setDialogState(() {
                    if (value == true) {
                      selected.add(level);
                    } else {
                      selected.remove(level);
                    }
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                ref
                    .read(deviceLogFilterProvider.notifier)
                    .setFilters(selected.toList());
                Navigator.pop(context);
              },
              child: Text(
                'Apply',
                style: TextStyle(color: context.accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareLogs() {
    final logger = ref.read(deviceLoggerProvider);
    final content = logger.export();
    shareText(content, subject: 'Socialmesh Device Logs', context: context);
  }

  void _copyToClipboard() {
    final logger = ref.read(deviceLoggerProvider);
    final content = logger.export();
    Clipboard.setData(ClipboardData(text: content));
    showSuccessSnackBar(context, 'Device logs copied to clipboard');
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: Text('Clear Logs', style: TextStyle(color: context.textPrimary)),
        content: Text(
          'Are you sure you want to clear all device logs?',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(deviceLoggerProvider).clear();
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: AppTheme.errorRed),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConnectionRequiredWrapper(child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    final logs = _getFilteredLogs();
    final filters = ref.watch(deviceLogFilterProvider);

    return GlassScaffold(
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Device Logs', style: TextStyle(color: context.textPrimary)),
          Text(
            '${logs.length} entries',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
        ],
      ),
      actions: [
        // Auto-scroll toggle
        IconButton(
          icon: Icon(
            _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
            color: _autoScroll ? context.accentColor : context.textSecondary,
          ),
          tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
          onPressed: () {
            setState(() => _autoScroll = !_autoScroll);
          },
        ),
        // Filter button
        IconButton(
          icon: Badge(
            isLabelVisible: filters.length < 6,
            backgroundColor: context.accentColor,
            label: Text('${6 - filters.length}'),
            child: const Icon(Icons.filter_list),
          ),
          tooltip: 'Filter levels',
          onPressed: _showFilterDialog,
        ),
        // More menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          color: context.card,
          onSelected: (value) {
            switch (value) {
              case 'copy':
                _copyToClipboard();
                break;
              case 'share':
                _shareLogs();
                break;
              case 'clear':
                _clearLogs();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'copy',
              child: Row(
                children: [
                  Icon(Icons.copy, color: context.textSecondary),
                  const SizedBox(width: 12),
                  Text(
                    'Copy to Clipboard',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, color: context.textSecondary),
                  const SizedBox(width: 12),
                  Text('Share', style: TextStyle(color: context.textPrimary)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, color: AppTheme.errorRed),
                  const SizedBox(width: 12),
                  Text(
                    'Clear Logs',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
      slivers: [
        // Search bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search logs...',
                hintStyle: TextStyle(color: context.textTertiary),
                prefixIcon: Icon(Icons.search, color: context.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: context.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),

        // Info banner
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AccentColors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AccentColors.blue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AccentColors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Streaming firmware debug logs from your connected device via BLE',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // Log list
        if (logs.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.terminal, size: 64, color: context.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'No device logs yet',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Logs will appear here as your device sends them',
                    style: TextStyle(color: context.textTertiary, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final entry = logs[index];
              return _LogEntryTile(entry: entry);
            }, childCount: logs.length),
          ),
      ],
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final DeviceLogEntry entry;

  const _LogEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final levelColor = entry.level.getColor(context);
    final timeStr =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(
            timeStr,
            style: TextStyle(
              color: context.textTertiary,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),

          // Level badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.level.label,
              style: TextStyle(
                color: levelColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Source (if not generic)
          if (entry.source != 'firmware') ...[
            Text(
              '[${entry.source}]',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 4),
          ],

          // Message
          Expanded(
            child: Text(
              entry.message,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
