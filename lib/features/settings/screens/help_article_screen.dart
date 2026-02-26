// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_article.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/help_article_providers.dart';

/// Full-screen article reader for the knowledge-base Help Center.
class HelpArticleScreen extends ConsumerStatefulWidget {
  final HelpArticle article;

  const HelpArticleScreen({super.key, required this.article});

  @override
  ConsumerState<HelpArticleScreen> createState() => _HelpArticleScreenState();
}

class _HelpArticleScreenState extends ConsumerState<HelpArticleScreen> {
  @override
  void initState() {
    super.initState();
    // Mark article as read when opened
    Future.microtask(() {
      ref.read(helpArticleReadProvider.notifier).markRead(widget.article.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(
      helpArticleContentProvider(widget.article.filePath),
    );

    return GlassScaffold(
      title: widget.article.title,
      slivers: [
        // Category badge
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing20,
              AppTheme.spacing12,
              AppTheme.spacing20,
              AppTheme.spacing4,
            ),
            child: Row(
              children: [
                _CategoryBadge(category: widget.article.category),
                const SizedBox(width: AppTheme.spacing10),
                Icon(Icons.schedule, size: 14, color: context.textTertiary),
                const SizedBox(width: AppTheme.spacing4),
                Text(
                  '${widget.article.readingTimeMinutes} min read',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Markdown body
        contentAsync.when(
          data: (markdown) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing20,
                vertical: AppTheme.spacing8,
              ),
              child: MarkdownBody(
                data: _stripFrontMatter(markdown),
                styleSheet: _buildStyleSheet(context),
                selectable: true,
              ),
            ),
          ),
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: context.textTertiary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  Text(
                    'Failed to load article',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom padding
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.of(context).padding.bottom + AppTheme.spacing32,
          ),
        ),
      ],
    );
  }

  /// Strip YAML front-matter (between --- delimiters) from markdown content.
  String _stripFrontMatter(String markdown) {
    final trimmed = markdown.trimLeft();
    if (!trimmed.startsWith('---')) return markdown;
    final endIndex = trimmed.indexOf('---', 3);
    if (endIndex < 0) return markdown;
    return trimmed.substring(endIndex + 3).trimLeft();
  }

  /// Build a MarkdownStyleSheet matching the app's visual language.
  MarkdownStyleSheet _buildStyleSheet(BuildContext context) {
    final primaryText = context.textPrimary;
    final secondaryText = context.textSecondary;
    final accent = AppTheme.primaryMagenta;
    final surface = context.surface;
    final border = context.border;

    return MarkdownStyleSheet(
      // Headings
      h1: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primaryText,
        height: 1.3,
      ),
      h1Padding: const EdgeInsets.only(
        top: AppTheme.spacing16,
        bottom: AppTheme.spacing12,
      ),
      h2: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: primaryText,
        height: 1.3,
      ),
      h2Padding: const EdgeInsets.only(
        top: AppTheme.spacing20,
        bottom: AppTheme.spacing8,
      ),
      h3: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryText,
        height: 1.3,
      ),
      h3Padding: const EdgeInsets.only(
        top: AppTheme.spacing16,
        bottom: AppTheme.spacing6,
      ),

      // Body text
      p: TextStyle(fontSize: 15, color: primaryText, height: 1.6),
      pPadding: const EdgeInsets.only(bottom: AppTheme.spacing12),

      // Strong / emphasis
      strong: TextStyle(fontWeight: FontWeight.w600, color: accent),
      em: TextStyle(fontStyle: FontStyle.italic, color: secondaryText),

      // Lists
      listBullet: TextStyle(fontSize: 15, color: accent, height: 1.6),
      listBulletPadding: const EdgeInsets.only(right: AppTheme.spacing8),
      listIndent: 20.0,

      // Blockquote
      blockquote: TextStyle(
        fontSize: 15,
        color: secondaryText,
        height: 1.5,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing8,
        AppTheme.spacing8,
      ),

      // Code
      code: TextStyle(
        fontSize: 13,
        color: accent,
        fontFamily: 'JetBrainsMono',
        backgroundColor: surface,
      ),
      codeblockDecoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: border),
      ),
      codeblockPadding: const EdgeInsets.all(AppTheme.spacing12),

      // Table
      tableHead: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      tableBody: TextStyle(fontSize: 13, color: secondaryText),
      tableBorder: TableBorder.all(color: border, width: 1),
      tableHeadAlign: TextAlign.left,
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing6,
      ),

      // Divider / thematic break
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
    );
  }
}

// =============================================================================
// Category Badge
// =============================================================================

class _CategoryBadge extends StatelessWidget {
  final HelpArticleCategory category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 13, color: category.color),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            category.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: category.color,
            ),
          ),
        ],
      ),
    );
  }
}
