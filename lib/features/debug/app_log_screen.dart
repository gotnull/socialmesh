import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../services/debug/debug_export_service.dart';
import '../../utils/share_utils.dart';
import '../../utils/snackbar.dart';

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

  Color getColor(BuildContext context) {
    switch (this) {
      case LogLevel.debug:
        return context.textTertiary;
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

/// Notifier for filtered log levels
class FilteredLogsNotifier extends Notifier<List<LogLevel>> {
  @override
  List<LogLevel> build() => LogLevel.values.toList();

  void setFilters(List<LogLevel> filters) => state = filters;
  void toggleFilter(LogLevel level) {
    if (state.contains(level)) {
      state = state.where((l) => l != level).toList();
    } else {
      state = [...state, level];
    }
  }
}

/// Provider for filtered logs
final filteredLogsProvider =
    NotifierProvider<FilteredLogsNotifier, List<LogLevel>>(
      FilteredLogsNotifier.new,
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
          backgroundColor: context.card,
          title: Text(
            'Filter Log Levels',
            style: TextStyle(color: context.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: LogLevel.values.map((level) {
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
                    .read(filteredLogsProvider.notifier)
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

  void _shareLog() {
    final logger = ref.read(appLoggerProvider);
    final content = logger.export();
    shareText(content, subject: 'Socialmesh App Log', context: context);
  }

  Future<void> _exportDebug() async {
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 100, 100);

    try {
      showInfoSnackBar(
        context,
        'Generating debug export...',
        duration: const Duration(seconds: 1),
      );

      final exportService = ref.read(debugExportServiceProvider);
      await exportService.exportAndShare(sharePositionOrigin);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Export failed: $e');
      }
    }
  }

  void _copyToClipboard() {
    final logger = ref.read(appLoggerProvider);
    final content = logger.export();
    Clipboard.setData(ClipboardData(text: content));
    showSuccessSnackBar(context, 'Log copied to clipboard');
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: Text('Clear Logs', style: TextStyle(color: context.textPrimary)),
        content: Text(
          'Are you sure you want to clear all logs?',
          style: TextStyle(color: context.textSecondary),
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
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          'App Log',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
              color: _autoScroll ? context.accentColor : context.textSecondary,
            ),
            tooltip: _autoScroll ? 'Auto-scroll on' : 'Auto-scroll off',
            onPressed: () {
              setState(() => _autoScroll = !_autoScroll);
            },
          ),
          AppBarOverflowMenu<String>(
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
                case 'debug_export':
                  _exportDebug();
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
                          : context.textSecondary,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Filter',
                      style: TextStyle(color: context.textPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy, color: context.textSecondary, size: 20),
                    SizedBox(width: 12),
                    Text('Copy', style: TextStyle(color: context.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, color: context.textSecondary, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Share Log',
                      style: TextStyle(color: context.textPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'debug_export',
                child: Row(
                  children: [
                    Icon(
                      Icons.bug_report,
                      color: context.accentColor,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Export Debug JSON',
                      style: TextStyle(color: context.accentColor),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
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
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search logs...',
                hintStyle: TextStyle(color: context.textTertiary),
                prefixIcon: Icon(Icons.search, color: context.textTertiary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: context.textTertiary),
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
                  style: TextStyle(fontSize: 13, color: context.textTertiary),
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

          SizedBox(height: 8),

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
                          color: context.textTertiary.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No log entries',
                          style: TextStyle(
                            fontSize: 16,
                            color: context.textTertiary,
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
            style: TextStyle(
              fontSize: 11,
              fontFamily: AppTheme.fontFamily,
              color: context.textTertiary,
            ),
          ),
          SizedBox(width: 8),

          // Level badge
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: entry.level.getColor(context).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.level.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: entry.level.getColor(context),
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Source
          Text(
            '[${entry.source}]',
            style: TextStyle(
              fontSize: 11,
              fontFamily: AppTheme.fontFamily,
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
                fontFamily: AppTheme.fontFamily,
                color: entry.level == LogLevel.error
                    ? AppTheme.errorRed
                    : entry.level == LogLevel.warning
                    ? AppTheme.warningYellow
                    : context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
