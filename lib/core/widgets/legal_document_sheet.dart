// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — WebView browser with solid background, no glass blur
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../constants.dart';
import '../l10n/l10n_extension.dart';
import '../theme.dart';
import '../logging.dart';

/// Opens legal documents (Terms, Privacy, Support) in an in-app webview.
/// Uses the socialmesh.app website for consistent, up-to-date content.
/// Shows a friendly offline placeholder if the page fails to load.
class LegalDocumentSheet {
  LegalDocumentSheet._();

  /// Show Terms of Service
  static void showTerms(BuildContext context) {
    _showWebView(
      context,
      context.l10n.legalDocumentTermsOfService,
      AppUrls.termsUrlInApp,
    );
  }

  /// Show Terms of Service scrolled to a specific section anchor.
  ///
  /// The [sectionAnchor] must match an `id` attribute on a heading in
  /// `terms-of-service.html` (e.g. `radio-compliance`, `acceptable-use`).
  /// See [LegalConstants] for the full list of anchor constants.
  static void showTermsSection(BuildContext context, String sectionAnchor) {
    _showWebView(
      context,
      context.l10n.legalDocumentTermsOfService,
      AppUrls.termsUrlInAppWithSection(sectionAnchor),
    );
  }

  /// Show Privacy Policy
  static void showPrivacy(BuildContext context) {
    _showWebView(
      context,
      context.l10n.legalDocumentPrivacyPolicy,
      AppUrls.privacyUrlInApp,
    );
  }

  /// Show Privacy Policy scrolled to a specific section anchor.
  ///
  /// The [sectionAnchor] must match an `id` attribute on a heading in
  /// `privacy-policy.html` (e.g. `third-party-services`, `local-data`).
  static void showPrivacySection(BuildContext context, String sectionAnchor) {
    _showWebView(
      context,
      context.l10n.legalDocumentPrivacyPolicy,
      AppUrls.privacyUrlInAppWithSection(sectionAnchor),
    );
  }

  /// Show Support / FAQ
  static void showSupport(BuildContext context) {
    _showWebView(
      context,
      context.l10n.legalDocumentHelpAndSupport,
      AppUrls.supportUrlInApp,
    );
  }

  /// Show Documentation
  static void showDocs(BuildContext context) {
    _showWebView(
      context,
      context.l10n.legalDocumentDocumentation,
      AppUrls.docsUrlInApp,
    );
  }

  /// Show FAQ
  static void showFAQ(BuildContext context) {
    _showWebView(context, context.l10n.legalDocumentFaq, AppUrls.faqUrlInApp);
  }

  /// Show Delete Account page
  static void showDeleteAccount(BuildContext context) {
    _showWebView(
      context,
      context.l10n.legalDocumentDeleteAccount,
      AppUrls.deleteAccountUrlInApp,
    );
  }

  static void _showWebView(BuildContext context, String title, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LegalWebViewScreen(title: title, url: url),
      ),
    );
  }
}

/// In-app webview for legal documents with offline error handling.
class _LegalWebViewScreen extends StatefulWidget {
  final String title;
  final String url;

  const _LegalWebViewScreen({required this.title, required this.url});

  @override
  State<_LegalWebViewScreen> createState() => _LegalWebViewScreenState();
}

class _LegalWebViewScreenState extends State<_LegalWebViewScreen> {
  double _progress = 0;
  String _title = '';
  InAppWebViewController? _webViewController;
  bool _canGoBack = false;
  bool _hasLoadError = false;
  String _errorDescription = '';

  @override
  void initState() {
    super.initState();
    _title = widget.title;
  }

  void _retry() {
    AppLogging.app('LegalWebView: retrying load for ${widget.url}');
    setState(() {
      _hasLoadError = false;
      _errorDescription = '';
      _progress = 0;
    });
    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(widget.url)),
    );
  }

  Widget _buildOfflinePlaceholder(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: accentColor.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              context.l10n.legalDocumentUnableToLoad,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              context.l10n.legalDocumentRequiresInternet,
              style: TextStyle(color: context.textTertiary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (_errorDescription.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacing8),
              Text(
                _errorDescription,
                style: TextStyle(color: context.textTertiary, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppTheme.spacing24),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.l10n.commonRetry),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          _title,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          tooltip: context.l10n.commonClose,
        ),
        actions: [
          if (_canGoBack)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _webViewController?.goBack(),
              tooltip: context.l10n.legalDocumentGoBack,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _hasLoadError
                ? _retry
                : () => _webViewController?.reload(),
            tooltip: context.l10n.legalDocumentRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator (only when loading and no error)
          if (_progress < 1.0 && !_hasLoadError)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: context.card,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 2,
            ),
          // Content: either the WebView or the offline placeholder
          Expanded(
            child: _hasLoadError
                ? _buildOfflinePlaceholder(context)
                : InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                    initialSettings: InAppWebViewSettings(
                      transparentBackground: true,
                      javaScriptEnabled: true,
                      useShouldOverrideUrlLoading: false,
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                      iframeAllowFullscreen: true,
                    ),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                    },
                    onLoadStart: (controller, url) {
                      if (mounted) {
                        setState(() {
                          _progress = 0;
                          _hasLoadError = false;
                          _errorDescription = '';
                        });
                      }
                    },
                    onProgressChanged: (controller, progress) {
                      if (mounted) setState(() => _progress = progress / 100);
                    },
                    onLoadStop: (controller, url) async {
                      setState(() => _progress = 1.0);
                      final canGoBack = await controller.canGoBack();
                      if (mounted) setState(() => _canGoBack = canGoBack);
                    },
                    onTitleChanged: (controller, title) {
                      if (mounted && title != null && title.isNotEmpty) {
                        // Keep our custom title, don't update from page
                      }
                    },
                    onReceivedError: (controller, request, error) {
                      AppLogging.app(
                        'LegalWebView error: type=${error.type}, '
                        'description=${error.description}, '
                        'url=${request.url}',
                      );

                      // Only show offline placeholder for main frame
                      // navigation errors (not sub-resource failures like
                      // images or scripts).
                      final isMainFrame = request.url.toString() == widget.url;

                      // Common offline / unreachable error types
                      final isConnectivityError =
                          error.type == WebResourceErrorType.HOST_LOOKUP ||
                          error.type ==
                              WebResourceErrorType.CANNOT_CONNECT_TO_HOST ||
                          error.type ==
                              WebResourceErrorType.NOT_CONNECTED_TO_INTERNET ||
                          error.type == WebResourceErrorType.TIMEOUT ||
                          error.type ==
                              WebResourceErrorType.NETWORK_CONNECTION_LOST;

                      if (isMainFrame || isConnectivityError) {
                        if (mounted) {
                          setState(() {
                            _hasLoadError = true;
                            _errorDescription = error.description;
                          });
                        }
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
