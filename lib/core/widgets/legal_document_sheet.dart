// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../constants.dart';
import '../theme.dart';
import '../logging.dart';

/// Opens legal documents (Terms, Privacy, Support) in an in-app webview.
/// Uses the socialmesh.app website for consistent, up-to-date content.
class LegalDocumentSheet {
  LegalDocumentSheet._();

  /// Show Terms of Service
  static void showTerms(BuildContext context) {
    _showWebView(context, 'Terms of Service', AppUrls.termsUrlInApp);
  }

  /// Show Terms of Service scrolled to a specific section anchor.
  ///
  /// The [sectionAnchor] must match an `id` attribute on a heading in
  /// `terms-of-service.html` (e.g. `radio-compliance`, `acceptable-use`).
  /// See [LegalConstants] for the full list of anchor constants.
  static void showTermsSection(BuildContext context, String sectionAnchor) {
    _showWebView(
      context,
      'Terms of Service',
      AppUrls.termsUrlInAppWithSection(sectionAnchor),
    );
  }

  /// Show Privacy Policy
  static void showPrivacy(BuildContext context) {
    _showWebView(context, 'Privacy Policy', AppUrls.privacyUrlInApp);
  }

  /// Show Privacy Policy scrolled to a specific section anchor.
  ///
  /// The [sectionAnchor] must match an `id` attribute on a heading in
  /// `privacy-policy.html` (e.g. `third-party-services`, `local-data`).
  static void showPrivacySection(BuildContext context, String sectionAnchor) {
    _showWebView(
      context,
      'Privacy Policy',
      AppUrls.privacyUrlInAppWithSection(sectionAnchor),
    );
  }

  /// Show Support / FAQ
  static void showSupport(BuildContext context) {
    _showWebView(context, 'Help & Support', AppUrls.supportUrlInApp);
  }

  /// Show Documentation
  static void showDocs(BuildContext context) {
    _showWebView(context, 'Documentation', AppUrls.docsUrlInApp);
  }

  /// Show FAQ
  static void showFAQ(BuildContext context) {
    _showWebView(context, 'FAQ', AppUrls.faqUrlInApp);
  }

  /// Show Delete Account page
  static void showDeleteAccount(BuildContext context) {
    _showWebView(context, 'Delete Account', AppUrls.deleteAccountUrlInApp);
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

/// In-app webview for legal documents
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

  @override
  void initState() {
    super.initState();
    _title = widget.title;
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
        ),
        actions: [
          if (_canGoBack)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _webViewController?.goBack(),
              tooltip: 'Go back',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webViewController?.reload(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          if (_progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: context.card,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 2,
            ),
          // WebView
          Expanded(
            child: InAppWebView(
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
                if (mounted) setState(() => _progress = 0);
              },
              onProgressChanged: (controller, progress) {
                if (mounted) setState(() => _progress = progress / 100);
              },
              onLoadStop: (controller, url) async {
                if (!mounted) return;
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
                AppLogging.app('WebView error: ${error.description}');
              },
            ),
          ),
        ],
      ),
    );
  }
}
