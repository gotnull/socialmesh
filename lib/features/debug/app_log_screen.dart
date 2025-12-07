import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';

/// Log entry with level and timestamp
class AppLogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String source;
  final String message;

  AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });
}

enum LogLevel {
  debug,
  info,
  warning,
  error;

  Color get color {
    switch (this) {
      case LogLevel.debug:
        return AppTheme.textTertiary;
      case LogLevel.info:
        return AccentColors.blue;
      case LogLevel.warning:
        return AppTheme.warningYellow;
      case LogLevel.error:
        return AppTheme.errorRed;
    }
  }

  String get label {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }
}

/// In-memory log storage for app logging
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  final List<AppLogEntry> _logs = [];
  static const int maxLogs = 1000;

  List<AppLogEntry> get logs => List.unmodifiable(_logs);

  void log(LogLevel level, String source, String message) {
    _logs.add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: level,
        source: source,
        message: message,
      ),
    );

    // Trim old logs
    while (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }
  }

  void debug(String source, String message) =>
      log(LogLevel.debug, source, message);
  void info(String source, String message) =>
      log(LogLevel.info, source, message);
  void warning(String source, String message) =>
      log(LogLevel.warning, source, message);
  void error(String source, String message) =>
      log(LogLevel.error, source, message);

  void clear() => _logs.clear();

  String export() {
    final buffer = StringBuffer();
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

/// Provider for app logger
final appLoggerProvider = Provider<AppLogger>((ref) => AppLogger());

/// Provider for filtered logs
final filteredLogsProvider = StateProvider<List<LogLevel>>(
  (ref) => LogLevel.values.toList(),
);

class AppLogScreen extends ConsumerStatefulWidget {
  const AppLogScreen({super.key});

  @override
  ConsumerState<AppLogScreen> createState() => _AppLogScreenState();
}

class _AppLogScreenState extends ConsumerState<AppLogScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<AppLogEntry> _getFilteredLogs() {
    final logger = ref.watch(appLoggerProvider);
    final filters = ref.watch(filteredLogsProvider);

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
    final filters = ref.read(filteredLogsProvider);
    final selected = Set<LogLevel>.from(filters);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: const Text(
            'Filter Log Levels',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: LogLevel.values.map((level) {
              return CheckboxListTile(
                title: Text(level.label, style: TextStyle(color: level.color)),
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
                ref.read(filteredLogsProvider.notifier).state = selected
                    .toList();
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

  void _shareLog() {
    final logger = ref.read(appLoggerProvider);
    final content = logger.export();
    // Get share position for iPad support
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 100, 100);
    Share.share(content, subject: 'Socialmesh App Log', sharePositionOrigin: sharePositionOrigin);
  }

  void _copyToClipboard() {
    final logger = ref.read(appLoggerProvider);
    final content = logger.export();
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log copied to clipboard'),
        backgroundColor: AppTheme.darkCard,
      ),
    );
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Clear Logs', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to clear all logs?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(appLoggerProvider).clear();
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
    final logs = _getFilteredLogs();
    final filters = ref.watch(filteredLogsProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'App Log',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
              color: _autoScroll ? context.accentColor : AppTheme.textSecondary,
            ),
            tooltip: _autoScroll ? 'Auto-scroll on' : 'Auto-scroll off',
            onPressed: () {
              setState(() => _autoScroll = !_autoScroll);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: AppTheme.darkCard,
            onSelected: (value) {
              switch (value) {
                case 'filter':
                  _showFilterDialog();
                  break;
                case 'copy':
                  _copyToClipboard();
                  break;
                case 'share':
                  _shareLog();
                  break;
                case 'clear':
                  _clearLogs();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'filter',
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      color: filters.length < LogLevel.values.length
                          ? context.accentColor
                          : AppTheme.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text('Filter', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy, color: AppTheme.textSecondary, size: 20),
                    SizedBox(width: 12),
                    Text('Copy', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, color: AppTheme.textSecondary, size: 20),
                    SizedBox(width: 12),
                    Text('Share', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: AppTheme.errorRed,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text('Clear', style: TextStyle(color: AppTheme.errorRed)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search logs...',
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppTheme.textTertiary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: AppTheme.textTertiary,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.darkCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Log count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${logs.length} entries',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const Spacer(),
                if (filters.length < LogLevel.values.length)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Filtered',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Log list
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 64,
                          color: AppTheme.textTertiary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No log entries',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final entry = logs[index];
                      return _buildLogEntry(entry);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(AppLogEntry entry) {
    final time =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}.'
        '${entry.timestamp.millisecond.toString().padLeft(3, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: entry.level == LogLevel.error
            ? AppTheme.errorRed.withValues(alpha: 0.1)
            : entry.level == LogLevel.warning
            ? AppTheme.warningYellow.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(width: 8),

          // Level badge
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: entry.level.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.level.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: entry.level.color,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Source
          Text(
            '[${entry.source}]',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: context.accentColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 8),

          // Message
          Expanded(
            child: Text(
              entry.message,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: entry.level == LogLevel.error
                    ? AppTheme.errorRed
                    : entry.level == LogLevel.warning
                    ? AppTheme.warningYellow
                    : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
