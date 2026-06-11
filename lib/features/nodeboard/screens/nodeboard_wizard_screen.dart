// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeBoard creation wizard — multi-step board setup.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../utils/text_sanitizer.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../utils/snackbar.dart';
import '../models/nodeboard_theme.dart';
import '../providers/nodeboard_providers.dart';
import 'nodeboard_screen.dart';

// Section descriptions for the checklist step.
const _kSectionDescriptions = <String, String>{
  // lint-allow: hardcoded-string
  'announcements': 'Official board announcements from the SysOp',
  // lint-allow: hardcoded-string
  'general': 'General discussion for all topics',
  // lint-allow: hardcoded-string
  'guestbook': 'Leave a message for visitors',
  // lint-allow: hardcoded-string
  'help': 'Questions and support',
  // lint-allow: hardcoded-string
  'off-topic': 'Anything goes',
};

class NodeBoardWizardScreen extends ConsumerStatefulWidget {
  const NodeBoardWizardScreen({super.key});

  @override
  ConsumerState<NodeBoardWizardScreen> createState() =>
      _NodeBoardWizardScreenState();
}

class _NodeBoardWizardScreenState extends ConsumerState<NodeBoardWizardScreen>
    with LifecycleSafeMixin<NodeBoardWizardScreen> {
  static const _totalSteps = 6;

  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1: Name / Slug
  final _titleController = TextEditingController();
  final _sysopNameController = TextEditingController();
  final _slugController = TextEditingController();
  bool _slugManuallyEdited = false;

  // Step 2: Tagline / Description
  final _taglineController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Step 3: Sections
  final Map<String, bool> _defaultSections = {
    'announcements': true,
    'general': true,
    'guestbook': true,
    'help': false,
    'off-topic': false,
  };

  // Step 4: Theme
  String? _selectedThemeId;

  // Step 5: Welcome / Splash
  final _welcomeTextController = TextEditingController();
  final _ansiSplashController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _sysopNameController.dispose();
    _slugController.dispose();
    _taglineController.dispose();
    _descriptionController.dispose();
    _welcomeTextController.dispose();
    _ansiSplashController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    if (_slugManuallyEdited) return;
    final slug = _titleController.text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    _slugController.text = slug;
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      AppLogging.nodeBoard(
        'Wizard: step $_currentStep \u2192 ${_currentStep + 1}',
      );
      HapticFeedback.lightImpact();
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      AppLogging.nodeBoard(
        'Wizard: step $_currentStep \u2192 ${_currentStep - 1}',
      );
      HapticFeedback.lightImpact();
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _createBoard() async {
    final notifier = ref.read(nodeBoardCreateNotifierProvider.notifier);

    final selectedSections = _defaultSections.entries
        .where((e) => e.value)
        .map(
          (e) => {
            'key': e.key,
            'title': e.key[0].toUpperCase() + e.key.substring(1),
          },
        )
        .toList();

    try {
      AppLogging.nodeBoard(
        'Wizard: creating board slug=${_slugController.text.trim()}',
      );
      HapticFeedback.mediumImpact();
      final board = await notifier.createBoard(
        slug: _slugController.text.trim(),
        title: _titleController.text.trim(),
        sysopName: _sysopNameController.text.trim(),
        tagline: _taglineController.text.trim().isNotEmpty
            ? _taglineController.text.trim()
            : null,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        themeId: _selectedThemeId,
        welcomeText: _welcomeTextController.text.trim().isNotEmpty
            ? _welcomeTextController.text.trim()
            : null,
        ansiSplash: _ansiSplashController.text.trim().isNotEmpty
            ? _ansiSplashController.text.trim()
            : null,
        defaultSections: selectedSections,
      );

      if (!mounted) return;
      AppLogging.nodeBoard('Wizard: board created, navigating to board');
      HapticFeedback.lightImpact();
      // lint-allow: hardcoded-string
      showSuccessSnackBar(context, 'Board created!');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => NodeBoardScreen(slug: board.slug)),
      );
    } catch (e) {
      if (!mounted) return;
      AppLogging.nodeBoard('Wizard: create failed: $e');
      // lint-allow: hardcoded-string
      showErrorSnackBar(context, 'Failed to create board: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold.body(
        title: context.l10n.nodeboardCreateBoard,
        hasScrollBody: false,
        body: Column(
          children: [
            // Progress indicator
            _buildProgressBar(),
            // Step content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildNameSlugStep(),
                  _buildTaglineDescriptionStep(),
                  _buildSectionsStep(),
                  _buildThemeStep(),
                  _buildWelcomeSplashStep(),
                  _buildReviewStep(),
                ],
              ),
            ),
            // Bottom navigation
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentStep;
          final isCurrent = index == _currentStep;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isCurrent ? AppTheme.spacing6 : AppTheme.spacing4,
              margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing2),
              decoration: BoxDecoration(
                color: isActive
                    ? context.accentColor
                    : context.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.radius4),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContainer({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      children: [
        Text(
          title.toUpperCase(),
          style: context.labelMediumStyle?.copyWith(
            color: context.accentColor,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppTheme.spacing6),
        Text(
          subtitle,
          style: context.bodySecondaryStyle?.copyWith(
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing24),
        ...children,
      ],
    );
  }

  Widget _buildNameSlugStep() {
    return _buildStepContainer(
      // lint-allow: hardcoded-string
      title: 'Name & Identity',
      // lint-allow: hardcoded-string
      subtitle: 'Choose a name and handle for your board.',
      children: [
        BottomSheetTextField(
          controller: _titleController,
          label: 'Board title', // lint-allow: hardcoded-string
          hint: 'My Awesome BBS', // lint-allow: hardcoded-string
          maxLength: 100,
        ),
        const SizedBox(height: AppTheme.spacing12),
        BottomSheetTextField(
          controller: _sysopNameController,
          label: 'SysOp name', // lint-allow: hardcoded-string
          hint: 'YourHandle', // lint-allow: hardcoded-string
          maxLength: 60,
        ),
        const SizedBox(height: AppTheme.spacing12),
        BottomSheetTextField(
          controller: _slugController,
          label: 'Slug', // lint-allow: hardcoded-string
          hint: 'my-awesome-bbs', // lint-allow: hardcoded-string
          maxLength: 60,
          onChanged: (_) => _slugManuallyEdited = true,
        ),
        const SizedBox(height: AppTheme.spacing16),
      ],
    );
  }

  Widget _buildTaglineDescriptionStep() {
    return _buildStepContainer(
      // lint-allow: hardcoded-string
      title: 'Tagline & Description',
      // lint-allow: hardcoded-string
      subtitle: 'Tell visitors what your board is about.',
      children: [
        BottomSheetTextField(
          controller: _taglineController,
          label: 'Tagline', // lint-allow: hardcoded-string
          hint:
              'A short description for your board', // lint-allow: hardcoded-string
          maxLength: 140,
        ),
        const SizedBox(height: AppTheme.spacing12),
        BottomSheetTextField(
          controller: _descriptionController,
          label: 'Description', // lint-allow: hardcoded-string
          hint:
              'Full description of your board...', // lint-allow: hardcoded-string
          maxLength: 5000,
          maxLines: 6,
        ),
        const SizedBox(height: AppTheme.spacing16),
      ],
    );
  }

  Widget _buildSectionsStep() {
    return _buildStepContainer(
      // lint-allow: hardcoded-string
      title: 'Sections',
      // lint-allow: hardcoded-string
      subtitle: 'Choose which default sections to include.',
      children: [
        ..._defaultSections.entries.map((entry) {
          final description = _kSectionDescriptions[entry.key] ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _defaultSections[entry.key] = !entry.value;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius16),
                  border: Border.all(
                    color: entry.value
                        ? context.accentColor.withValues(alpha: 0.5)
                        : context.border.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: AppTheme.spacing24,
                      height: AppTheme.spacing24,
                      decoration: BoxDecoration(
                        color: entry.value
                            ? context.accentColor
                            : context.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radius6),
                        border: Border.all(
                          color: entry.value
                              ? context.accentColor
                              : context.border,
                        ),
                      ),
                      child: entry.value
                          ? Icon(
                              Icons.check,
                              size: AppTheme.spacing16,
                              color: SemanticColors.onAccent,
                            )
                          : null,
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key[0].toUpperCase() + entry.key.substring(1),
                            style: context.bodyStyle?.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.spacing2),
                            Text(
                              description,
                              style: context.bodySmallStyle?.copyWith(
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildThemeStep() {
    final themes = ref.watch(nodeBoardThemesProvider);

    return _buildStepContainer(
      // lint-allow: hardcoded-string
      title: 'Theme',
      // lint-allow: hardcoded-string
      subtitle: 'Pick a visual style for your board.',
      children: [
        themes.when(
          data: (themeList) => _buildThemeGrid(themeList),
          loading: () => Center(
            child: CircularProgressIndicator(color: context.accentColor),
          ),
          error: (e, _) => Text(
            // lint-allow: hardcoded-string
            'Failed to load themes',
            style: context.bodyStyle?.copyWith(color: SemanticColors.error),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeGrid(List<NodeBoardTheme> themes) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppTheme.spacing12,
        mainAxisSpacing: AppTheme.spacing12,
        childAspectRatio: 1.3,
      ),
      itemCount: themes.length,
      itemBuilder: (context, index) {
        final theme = themes[index];
        final isSelected = _selectedThemeId == theme.id;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedThemeId = theme.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius16),
              border: Border.all(
                color: isSelected
                    ? context.accentColor
                    : context.border.withValues(alpha: 0.5),
                width: isSelected ? AppTheme.spacing2 : AppTheme.spacing1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(
                          right: AppTheme.spacing6,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: AppTheme.spacing18,
                          color: context.accentColor,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        theme.name,
                        style: context.titleSmallStyle?.copyWith(
                          color: context.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing8,
                    vertical: AppTheme.spacing2,
                  ),
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radius6),
                  ),
                  child: Text(
                    theme.styleMode.toJson(),
                    style: context.captionStyle?.copyWith(
                      color: context.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  theme.accentPreset,
                  style: context.captionStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeSplashStep() {
    return _buildStepContainer(
      // lint-allow: hardcoded-string
      title: 'Welcome & Splash',
      // lint-allow: hardcoded-string
      subtitle: 'Customize the welcome message and ANSI splash art.',
      children: [
        BottomSheetTextField(
          controller: _welcomeTextController,
          label: 'Welcome text', // lint-allow: hardcoded-string
          hint: 'Welcome to my board!', // lint-allow: hardcoded-string
          maxLength: 2000,
          maxLines: 5,
        ),
        const SizedBox(height: AppTheme.spacing12),
        BottomSheetTextField(
          controller: _ansiSplashController,
          label: 'ANSI splash art', // lint-allow: hardcoded-string
          hint: 'ASCII/ANSI art here...', // lint-allow: hardcoded-string
          maxLength: 4000,
          maxLines: 8,
        ),
        const SizedBox(height: AppTheme.spacing16),
      ],
    );
  }

  Widget _buildReviewStep() {
    final selectedSections = _defaultSections.entries
        .where((e) => e.value)
        .map((e) => e.key[0].toUpperCase() + e.key.substring(1))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      children: [
        Text(
          // lint-allow: hardcoded-string
          'REVIEW',
          style: context.labelMediumStyle?.copyWith(
            color: context.accentColor,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppTheme.spacing6),
        Text(
          // lint-allow: hardcoded-string
          'Review your board settings before creating.',
          style: context.bodySecondaryStyle?.copyWith(
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing24),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            border: Border.all(color: context.border.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              // lint-allow: hardcoded-string
              _ReviewRow(label: 'Title', value: _titleController.text),
              // lint-allow: hardcoded-string
              _ReviewRow(label: 'SysOp', value: _sysopNameController.text),
              // lint-allow: hardcoded-string
              _ReviewRow(label: 'Slug', value: '/${_slugController.text}'),
              if (_taglineController.text.isNotEmpty)
                // lint-allow: hardcoded-string
                _ReviewRow(label: 'Tagline', value: _taglineController.text),
              _ReviewRow(
                // lint-allow: hardcoded-string
                label: 'Sections',
                value: selectedSections.join(', '),
              ),
              if (_selectedThemeId != null)
                // lint-allow: hardcoded-string
                _ReviewRow(label: 'Theme', value: _selectedThemeId!),
              if (_welcomeTextController.text.isNotEmpty)
                _ReviewRow(
                  // lint-allow: hardcoded-string
                  label: 'Welcome',
                  value: safeSubstring(_welcomeTextController.text, 80),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        border: Border(
          top: BorderSide(color: context.border.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _previousStep,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: context.border.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacing14,
                      ),
                    ),
                    child: Text(context.l10n.commonBack),
                  ),
                )
              else
                const Expanded(child: SizedBox.shrink()),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                // lint-allow: hardcoded-string
                '${_currentStep + 1} / $_totalSteps',
                style: context.labelMediumStyle?.copyWith(
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: isLastStep
                    ? FilledButton(
                        onPressed: _createBoard,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spacing14,
                          ),
                        ),
                        child: Text(context.l10n.nodeboardCreateBoard),
                      )
                    : FilledButton(
                        onPressed: _nextStep,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spacing14,
                          ),
                        ),
                        child: Text(context.l10n.commonNext),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppTheme.spacing100,
            child: Text(
              label,
              style: context.labelStyle?.copyWith(color: context.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.bodyStyle?.copyWith(color: context.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
