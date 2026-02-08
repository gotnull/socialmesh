# Android Build Warnings

Warnings from third-party plugin subprojects that cannot be eliminated without
upstream changes. Compile warnings (Java deprecation/unchecked and Kotlin
unchecked casts) are suppressed for dependency subprojects in
`android/build.gradle.kts` so they do not pollute build output. This file
records what is suppressed and why.

Last audited: 2026-02-08
Flutter 3.38.9 / Dart 3.10.8 / AGP 8.11.1 / Kotlin 2.2.20

---

## A) firebase_auth 6.1.4 (3 Java deprecation warnings)

| Warning | Source file | Deprecated API |
|---------|------------|----------------|
| `[deprecation] updateEmail(String) in FirebaseUser` | `FlutterFirebaseAuthUser.java:343` | Firebase Android SDK |
| `[deprecation] setDynamicLinkDomain(String) in Builder` | `PigeonParser.java:258` | Firebase Android SDK |
| `[deprecation] fetchSignInMethodsForEmail(String) in FirebaseAuth` | `FlutterFirebaseAuthPlugin.java:474` | Firebase Android SDK |

**Root cause:** The plugin calls deprecated methods in the Firebase Android SDK.
Dynamic Links has been sunset and `fetchSignInMethodsForEmail` is deprecated for
security reasons. The plugin wraps them for backward compatibility.

**Version pinned:** `firebase_auth: ^6.0.1` resolves to 6.1.4 (latest stable).

**Next step:** Wait for upstream firebase_auth release that removes these calls
or migrates to replacement APIs. Track
https://github.com/firebase/flutterfire/issues for updates.

---

## B) flutter_angle 0.3.9 (2 Java unchecked cast warnings)

| Warning | Source file |
|---------|------------|
| `[unchecked] unchecked cast` | `FlutterAnglePlugin.java:216` |
| `[unchecked] unchecked cast` | `FlutterAnglePlugin.java:258` |

**Root cause:** `(Map<String,Object>) call.arguments` casts without type
checking. Standard Flutter method-channel pattern that javac flags.

**Version pinned:** Transitive dependency via `three_js` (0.2.7). 0.3.9 is the
latest release.

**Next step:** No action required. These are safe casts on Flutter method channel
arguments. Wait for upstream fix or suppress.

---

## C) flutter_inappwebview_android 1.1.3 (100 Java warnings)

Breakdown: ~60 deprecation + ~40 unchecked cast warnings.

### Deprecation warnings (representative set)

| Deprecated API | Count | Notes |
|---------------|-------|-------|
| `CookieSyncManager` (class, `getInstance()`, `sync()`) | 8 | Deprecated since API 21; use `CookieManager.flush()` |
| `shouldOverrideUrlLoading(WebView, String)` | 2 | Override kept for pre-API-24 compat |
| `onReceivedError(WebView, int, String, String)` | 4 | Override kept for pre-API-23 compat |
| `shouldInterceptRequest(WebView, String)` | 2 | Override kept for pre-API-21 compat |
| `SYSTEM_UI_FLAG_*` constants in `View` | 12 | Deprecated in API 30; replaced by WindowInsetsController |
| `setSystemUiVisibility(int)` / `getSystemUiVisibility()` | 4 | Same as above |
| `setForceDark` / `setForceDarkStrategy` in `WebSettingsCompat` | 6 | Deprecated in AndroidX WebKit |
| `setAllowFileAccessFromFileURLs` / `setAllowUniversalAccessFromFileURLs` | 4 | Security-deprecated in API 30 |
| `setSavePassword` / `setSaveFormData` | 6 | Deprecated since API 18/26 |
| `removeSessionCookie()` / `removeAllCookie()` | 4 | Use async variants instead |
| `Handler()` no-arg constructor | 1 | Use `Handler(Looper)` |
| `AbsoluteLayout.LayoutParams` | 4 | Deprecated since API 3 |
| `createPrintDocumentAdapter()` no-arg | 1 | Use variant with job name |
| Other internal deprecations | 2 | `clearCache`, `clearSessionCache`, `clearAllCache` |

### Unchecked cast warnings

~40 instances of `(Map<String, Object>) call.arguments` and similar casts across
`WebViewChannelDelegate.java`, `InAppWebViewSettings.java`,
`InAppWebViewChromeClient.java`, and `InAppWebView.java`. Standard Flutter
method-channel deserialization pattern.

**Root cause:** The plugin supports a wide Android API range and retains
backward-compatible overrides for older API levels. The unchecked casts are
inherent to Flutter's method channel argument passing.

**Version pinned:** `flutter_inappwebview: ^6.1.5` resolves to 6.1.5, which
pulls `flutter_inappwebview_android` 1.1.3 (latest stable). A prerelease
`1.2.0-beta.3` exists but is not suitable for production.

**Next step:** Monitor `flutter_inappwebview` 6.2.0 stable release. The beta
series may address some of these. Track
https://github.com/nicklasOSLT/flutter_inappwebview/issues for updates.

---

## D) Additional Kotlin unchecked cast warnings (suppressed, 10 total)

| Plugin | Version | Count | Cast pattern |
|--------|---------|-------|-------------|
| `firebase_analytics` | 12.1.1 | 3 | `Map<*, *>` to `Map<String, Any>` |
| `cloud_functions` | 6.0.6 | 2 | `Any` to `Map<String, Any>` |
| `file_picker` | 10.3.10 | 2 | `Any?` to `ArrayList<String>?` |
| `live_activities` | 2.4.6 | 2 | `Any?`/`Any!` to `Map<String, Any>` |
| `three_js_sensors` | 0.1.2 | 1 | `defaultDisplay: Display!` deprecated |

**Root cause:** Kotlin type-erasure means generic casts from platform channels
are inherently unchecked. The `three_js_sensors` warning is from using the
deprecated `WindowManager.defaultDisplay` property.

**Next step:** All packages are at latest stable. These are safe patterns. Wait
for upstream fixes.

---

## E) Gradle configuration warnings (124 lines)

These appear only with `--warning-mode all` and are Gradle DSL deprecation
notices, not code warnings. They come from plugins still using old Groovy
`propName value` syntax instead of `propName = value` assignment.

Affected properties: `group`, `version`, `namespace`, `compileSdk`, `minSdk`,
`buildConfig`, `checkAllWarnings`, `warningsAsErrors`, and others.

**Root cause:** Plugin `build.gradle` files use Groovy space-assignment syntax
deprecated in Gradle 8.x (removal planned for Gradle 10.0).

**Next step:** These will resolve as plugins migrate to Kotlin DSL or update
their Groovy syntax. No action possible from the app side. Does not affect build
correctness.

---

## Suppression approach

File: `android/build.gradle.kts`

Suppression is applied only to subprojects (third-party plugins), excluding
`:app`. This ensures our own code still surfaces all warnings.

- **Java:** `doFirst` block strips all `-Xlint` flags added by AGP and replaces
  with `-Xlint:none` for plugin subprojects only.
- **Kotlin:** `suppressWarnings` is set to `true` for plugin subprojects only.

The `:app` project retains full warning visibility.