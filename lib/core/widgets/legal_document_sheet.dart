import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'app_bottom_sheet.dart';

/// Displays legal documents (Terms, Privacy, Support) in a modal bottom sheet.
/// Content is parsed from the bundled .md files.
class LegalDocumentSheet extends StatelessWidget {
  final String title;
  final String content;

  const LegalDocumentSheet({
    super.key,
    required this.title,
    required this.content,
  });

  /// Show Terms of Service
  static Future<void> showTerms(BuildContext context) async {
    final content = await _loadDocument('docs/terms-of-service.md');
    if (context.mounted) {
      _show(context, 'Terms of Service', content);
    }
  }

  /// Show Privacy Policy
  static Future<void> showPrivacy(BuildContext context) async {
    final content = await _loadDocument('docs/privacy-policy.md');
    if (context.mounted) {
      _show(context, 'Privacy Policy', content);
    }
  }

  /// Show Support / FAQ
  static Future<void> showSupport(BuildContext context) async {
    final content = await _loadDocument('docs/support.md');
    if (context.mounted) {
      _show(context, 'Help & Support', content);
    }
  }

  static Future<String> _loadDocument(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (e) {
      return 'Unable to load document. Please visit our website.';
    }
  }

  static void _show(BuildContext context, String title, String content) {
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: LegalDocumentSheet(title: title, content: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              child: _MarkdownContent(content: content),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple markdown-like renderer for legal documents
class _MarkdownContent extends StatelessWidget {
  final String content;

  const _MarkdownContent({required this.content});

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    bool inTable = false;
    List<String> tableRows = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Skip table separator lines
      if (line.startsWith('|--') || line.startsWith('| --')) {
        continue;
      }

      // Handle tables
      if (line.startsWith('|') && line.endsWith('|')) {
        if (!inTable) {
          inTable = true;
          tableRows = [];
        }
        tableRows.add(line);
        // Check if next line is not a table row
        if (i + 1 >= lines.length ||
            !lines[i + 1].startsWith('|') ||
            lines[i + 1].startsWith('|--')) {
          if (i + 1 < lines.length && lines[i + 1].startsWith('|--')) {
            continue; // Skip, more table content coming
          }
        }
        if (i + 1 >= lines.length ||
            (!lines[i + 1].startsWith('|') &&
                !lines[i + 1].startsWith('|--'))) {
          // End of table
          widgets.add(_buildTable(context, tableRows));
          widgets.add(const SizedBox(height: 12));
          inTable = false;
          tableRows = [];
        }
        continue;
      }

      // Main title (# )
      if (line.startsWith('# ') && !line.startsWith('## ')) {
        // Skip main title since we show it in the header
        continue;
      }

      // Section header (## )
      if (line.startsWith('## ')) {
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 20));
        }
        widgets.add(Text(
          line.substring(3),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.accentColor,
          ),
        ));
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Subsection header (### )
      if (line.startsWith('### ')) {
        widgets.add(const SizedBox(height: 16));
        widgets.add(Text(
          line.substring(4),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ));
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Horizontal rule
      if (line.startsWith('---')) {
        widgets.add(const SizedBox(height: 12));
        widgets.add(Divider(color: AppTheme.textTertiary.withValues(alpha: 0.3)));
        widgets.add(const SizedBox(height: 12));
        continue;
      }

      // Skip metadata lines
      if (line.startsWith('**Last Updated:') ||
          line.startsWith('**Socialmesh**')) {
        continue;
      }

      // Copyright notice
      if (line.startsWith('©')) {
        widgets.add(const SizedBox(height: 16));
        widgets.add(Text(
          line,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textTertiary,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ));
        continue;
      }

      // Bullet points
      if (line.startsWith('- ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 7, right: 12),
                decoration: BoxDecoration(
                  color: context.accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: _buildRichText(context, line.substring(2)),
              ),
            ],
          ),
        ));
        continue;
      }

      // Numbered list
      final numberedMatch = RegExp(r'^(\d+)\. (.*)').firstMatch(line);
      if (numberedMatch != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${numberedMatch.group(1)}.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.accentColor,
                  ),
                ),
              ),
              Expanded(
                child: _buildRichText(context, numberedMatch.group(2)!),
              ),
            ],
          ),
        ));
        continue;
      }

      // Q&A format
      if (line.startsWith('**Q:')) {
        widgets.add(const SizedBox(height: 12));
        widgets.add(_buildRichText(context, line));
        continue;
      }

      // Empty line
      if (line.trim().isEmpty) {
        if (widgets.isNotEmpty && widgets.last is! SizedBox) {
          widgets.add(const SizedBox(height: 8));
        }
        continue;
      }

      // Regular paragraph
      widgets.add(_buildRichText(context, line));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildTable(BuildContext context, List<String> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final headerCells =
        rows[0].split('|').where((c) => c.trim().isNotEmpty).toList();

    final dataRows = rows
        .skip(1)
        .map((row) => row.split('|').where((c) => c.trim().isNotEmpty).toList())
        .where((cells) => cells.isNotEmpty)
        .toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.textTertiary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: headerCells
                  .map((cell) => Expanded(
                        child: Text(
                          cell.trim().replaceAll('**', ''),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ))
                  .toList(),
            ),
          ),
          // Data rows
          ...dataRows.map((cells) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.textTertiary.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: cells
                      .map((cell) => Expanded(
                            child: Text(cell.trim().replaceAll('**', '')),
                          ))
                      .toList(),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildRichText(BuildContext context, String text) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*([^*]+)\*\*|\[([^\]]+)\]\(([^)]+)\)|([^*\[]+)');

    for (final match in pattern.allMatches(text)) {
      if (match.group(1) != null) {
        // Bold text
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (match.group(2) != null && match.group(3) != null) {
        // Link - just show as styled text (no tap handling for simplicity)
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(
            color: context.accentColor,
            decoration: TextDecoration.underline,
          ),
        ));
      } else if (match.group(4) != null) {
        // Regular text
        spans.add(TextSpan(text: match.group(4)));
      }
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.textPrimary,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }
}
