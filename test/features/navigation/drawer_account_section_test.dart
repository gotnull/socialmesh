import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drawer account section regression tests.
///
/// These tests enforce structural invariants that prevent the drawer
/// from showing a broken "Account" tile when the profile provider is
/// in error or loading state. The root cause was:
///
///   1. firebaseAuthProvider throws when Firebase is not ready (Android
///      initializes slower than iOS).
///   2. UserProfileNotifier.build() called ref.read(firebaseAuthProvider)
///      without guarding the throw, putting userProfileProvider into
///      AsyncError state.
///   3. The drawer's profileAsync.when(error:) branch rendered a plain
///      _DrawerMenuTile(label: 'Account') with an onTap that navigated
///      to _drawerMenuItems[0] — completely wrong destination, and
///      showed "Account" instead of "Guest" / "Not signed in".
///
/// These tests scan the source files to ensure the fix is never reverted.
void main() {
  final mainShellFile = File('lib/features/navigation/main_shell.dart');
  final profileProvidersFile = File('lib/providers/profile_providers.dart');
  final activityTimelineFile = File(
    'lib/features/social/screens/activity_timeline_screen.dart',
  );

  late String mainShellSource;
  late String profileProvidersSource;
  late List<String> mainShellLines;

  /// Extract lines belonging to a method starting at the line matching
  /// [signature] (inclusive) until we hit a line at the same or lower
  /// indentation that starts a new member (or end of class).  This avoids
  /// fragile regex over nested parentheses.
  List<String> extractMethodBody(List<String> lines, RegExp signature) {
    int startIdx = -1;
    for (var i = 0; i < lines.length; i++) {
      if (signature.hasMatch(lines[i])) {
        startIdx = i;
        break;
      }
    }
    if (startIdx == -1) return [];

    // Walk forward collecting lines that belong to this method.
    // The method ends when we hit a non-empty line at baseIndent or less
    // that is not a continuation of the method (i.e. another member def,
    // closing brace of the class, or a blank line followed by another member).
    final result = <String>[lines[startIdx]];
    int braceDepth = 0;
    bool seenOpenBrace = false;

    for (var i = startIdx; i < lines.length; i++) {
      final line = lines[i];
      braceDepth += '{'.allMatches(line).length;
      braceDepth -= '}'.allMatches(line).length;
      if (line.contains('{')) seenOpenBrace = true;

      if (i > startIdx) result.add(line);

      // Once we have seen the opening brace and brace depth returns to 0,
      // we have captured the entire method.
      if (seenOpenBrace && braceDepth <= 0) break;
    }
    return result;
  }

  /// Strip single-line comments from source lines.
  List<String> stripComments(List<String> lines) {
    return lines.map((line) {
      final commentIdx = line.indexOf('//');
      if (commentIdx == -1) return line;
      // Preserve indentation, remove comment.
      return line.substring(0, commentIdx);
    }).toList();
  }

  setUpAll(() {
    expect(
      mainShellFile.existsSync(),
      true,
      reason: 'main_shell.dart must exist',
    );
    expect(
      profileProvidersFile.existsSync(),
      true,
      reason: 'profile_providers.dart must exist',
    );
    mainShellSource = mainShellFile.readAsStringSync();
    mainShellLines = mainShellSource.split('\n');
    profileProvidersSource = profileProvidersFile.readAsStringSync();
  });

  // -----------------------------------------------------------------------
  // Drawer account error fallback
  // -----------------------------------------------------------------------
  group('Drawer account error fallback', () {
    test('error branch must call _buildProfileTile, not _DrawerMenuTile', () {
      // Extract _buildAccountSection method body.
      final methodLines = extractMethodBody(
        mainShellLines,
        RegExp(r'_buildAccountSection\s*\('),
      );
      expect(
        methodLines,
        isNotEmpty,
        reason: '_buildAccountSection method must exist in main_shell.dart',
      );

      final methodBody = methodLines.join('\n');

      // Locate the error: branch within the method body.
      final errorIdx = methodBody.indexOf('error:');
      expect(
        errorIdx,
        greaterThan(-1),
        reason: 'profileAsync.when must have an error: branch',
      );

      final afterError = methodBody.substring(errorIdx);

      // The error branch must reference _buildProfileTile.
      expect(
        afterError.contains('_buildProfileTile'),
        true,
        reason:
            'error branch must delegate to _buildProfileTile for '
            'consistent Guest / Not signed in display',
      );

      // The error branch must NOT use _DrawerMenuTile.
      // Only look at lines between error: and the next branch/close.
      final errorLines = afterError.split('\n');
      for (final line in errorLines) {
        if (line.contains('_DrawerMenuTile')) {
          fail(
            'error branch must NOT use _DrawerMenuTile — it shows a '
            'broken "Account" label instead of "Guest" / "Not signed in". '
            'Line: "$line"',
          );
        }
        // Stop scanning after the first ), which closes the error handler
        // expression within the when() call.
        if (line.trimLeft().startsWith(')')) break;
      }
    });

    test('error branch must not navigate to _drawerMenuItems[0]', () {
      final methodLines = extractMethodBody(
        mainShellLines,
        RegExp(r'_buildAccountSection\s*\('),
      );
      final methodBody = methodLines.join('\n');

      final errorIdx = methodBody.indexOf('error:');
      if (errorIdx != -1) {
        final afterError = methodBody.substring(errorIdx);
        expect(
          afterError.contains('_drawerMenuItems[0]'),
          false,
          reason:
              'error branch must NOT navigate to _drawerMenuItems[0] — '
              'that is a random menu item, not the account screen',
        );
      }
    });

    test('_buildProfileTile shows Guest when profile is null', () {
      expect(
        mainShellSource.contains("profile?.displayName ?? 'Guest'"),
        true,
        reason:
            '_buildProfileTile must fall back to "Guest" '
            'when profile is null',
      );
    });

    test('_buildProfileTile shows Not signed in when not authenticated', () {
      expect(
        mainShellSource.contains("'Not signed in'"),
        true,
        reason:
            '_buildProfileTile must show "Not signed in" subtitle '
            'when user is not authenticated',
      );

      final notSignedInPattern = RegExp(
        r"if\s*\(\s*!isSignedIn\s*\)\s*return\s*'Not signed in'",
      );
      expect(
        notSignedInPattern.hasMatch(mainShellSource),
        true,
        reason: 'Not signed in text must be returned when isSignedIn is false',
      );
    });

    test(
      'error branch navigates to AccountSubscriptionsScreen when not signed in',
      () {
        // Since the error branch delegates to _buildProfileTile,
        // verify that _buildProfileTile navigates correctly.
        // Match the method definition (Widget _buildProfileTile), not
        // call sites like `_buildProfileTile(context, ...)`.
        final profileTileLines = extractMethodBody(
          mainShellLines,
          RegExp(r'Widget\s+_buildProfileTile\s*\('),
        );
        final profileTileBody = profileTileLines.join('\n');

        expect(
          profileTileBody.contains('AccountSubscriptionsScreen'),
          true,
          reason:
              '_buildProfileTile must navigate to AccountSubscriptionsScreen '
              'when not signed in',
        );
        expect(
          profileTileBody.contains('ProfileScreen'),
          true,
          reason:
              '_buildProfileTile must navigate to ProfileScreen '
              'when signed in',
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // Profile provider Firebase safety
  // -----------------------------------------------------------------------
  group('Profile provider Firebase safety', () {
    test(
      'UserProfileNotifier.build must check firebaseReadyProvider before reading firebaseAuthProvider',
      () {
        final providerLines = profileProvidersSource.split('\n');
        final buildLines = extractMethodBody(
          providerLines,
          RegExp(r'Future<UserProfile\?>\s+build\(\)'),
        );
        expect(
          buildLines,
          isNotEmpty,
          reason: 'UserProfileNotifier.build() must exist',
        );

        final buildBody = buildLines.join('\n');

        // Must reference firebaseReadyProvider to check readiness first.
        expect(
          buildBody.contains('firebaseReadyProvider'),
          true,
          reason:
              'build() must check firebaseReadyProvider before reading '
              'firebaseAuthProvider to avoid StateError on Android',
        );

        // firebaseReadyProvider must appear BEFORE firebaseAuthProvider.
        final readyIdx = buildBody.indexOf('firebaseReadyProvider');
        final authReadIdx = buildBody.indexOf('ref.read(firebaseAuthProvider)');
        expect(
          readyIdx,
          lessThan(authReadIdx),
          reason:
              'firebaseReadyProvider check must appear BEFORE '
              'ref.read(firebaseAuthProvider) in build()',
        );
      },
    );

    test(
      'UserProfileNotifier.build must guard firebaseAuthProvider behind readiness check',
      () {
        final providerLines = profileProvidersSource.split('\n');
        final buildLines = extractMethodBody(
          providerLines,
          RegExp(r'Future<UserProfile\?>\s+build\(\)'),
        );
        final buildBody = buildLines.join('\n');

        // The firebaseAuthProvider read must be conditional on readiness.
        // Accepted patterns:
        //   firebaseReady ? ref.read(firebaseAuthProvider)...
        //   if (firebaseReady) { ... ref.read(firebaseAuthProvider) ... }
        //   try { ref.read(firebaseAuthProvider) } on StateError ...
        final conditionalTernary = RegExp(
          r'firebaseReady\s*\?\s*ref\.read\(firebaseAuthProvider\)',
        );
        final ifGuard = RegExp(
          r'if\s*\(\s*firebaseReady\s*\)[\s\S]*?ref\.read\(firebaseAuthProvider\)',
        );
        final tryCatch = RegExp(
          r'try\s*\{[\s\S]*?ref\.read\(firebaseAuthProvider\)[\s\S]*?\}\s*on\s+StateError',
        );

        final hasGuard =
            conditionalTernary.hasMatch(buildBody) ||
            ifGuard.hasMatch(buildBody) ||
            tryCatch.hasMatch(buildBody);

        expect(
          hasGuard,
          true,
          reason:
              'ref.read(firebaseAuthProvider) must be conditional on '
              'Firebase readiness (ternary, if-guard, or try/catch) — '
              'unguarded reads throw StateError on Android where '
              'Firebase initializes slowly',
        );
      },
    );

    test(
      'UserProfileNotifier.build must not have bare firebaseAuthProvider read',
      () {
        final providerLines = profileProvidersSource.split('\n');
        final buildLines = extractMethodBody(
          providerLines,
          RegExp(r'Future<UserProfile\?>\s+build\(\)'),
        );

        // Strip comments so we only inspect actual code.
        final codeLines = stripComments(buildLines);

        for (var i = 0; i < codeLines.length; i++) {
          final line = codeLines[i].trim();
          if (line.isEmpty) continue;

          // A bare assignment like:
          //   final firebaseAuth = ref.read(firebaseAuthProvider);
          // is dangerous — it throws when Firebase is not ready.
          final isBareAssignment = RegExp(
            r'^final\s+\w+\s*=\s*ref\.read\(firebaseAuthProvider\)',
          ).hasMatch(line);

          expect(
            isBareAssignment,
            false,
            reason:
                'Line ${i + 1} in build(): bare '
                'ref.read(firebaseAuthProvider) assignment will throw '
                'StateError when Firebase is not ready. '
                'Must be guarded by readiness check. '
                'Line: "$line"',
          );
        }
      },
    );
  });

  // -----------------------------------------------------------------------
  // Activity timeline identity rules (must match signal card pattern)
  // -----------------------------------------------------------------------
  group('Activity timeline identity — must match signal card pattern', () {
    test('actorId.hashCode must never be used for SigilAvatar', () {
      if (!activityTimelineFile.existsSync()) return;

      final source = activityTimelineFile.readAsStringSync();

      expect(
        source.contains('actorId.hashCode'),
        false,
        reason:
            'actorId.hashCode must NEVER be used to generate sigils — '
            'SigilAvatar must only receive real mesh node numbers',
      );
    });

    test('SigilAvatar in activity timeline must use resolved nodeNum only', () {
      if (!activityTimelineFile.existsSync()) return;

      final sourceLines = activityTimelineFile.readAsStringSync().split('\n');

      // Only inspect non-comment lines for actual SigilAvatar calls.
      final codeLines = stripComments(sourceLines);
      final codeSource = codeLines.join('\n');

      final sigilPattern = RegExp(r'SigilAvatar\s*\(([^)]*)\)');
      final matches = sigilPattern.allMatches(codeSource);

      for (final match in matches) {
        final args = match.group(1)!;

        // Must use meshNodeNum or nodeNum (the resolved value).
        final usesResolvedNodeNum =
            args.contains('meshNodeNum') || args.contains('nodeNum');
        expect(
          usesResolvedNodeNum,
          true,
          reason:
              'SigilAvatar must use a resolved mesh nodeNum, '
              'found: SigilAvatar($args)',
        );

        // Must NOT contain .hashCode
        expect(
          args.contains('hashCode'),
          false,
          reason:
              'SigilAvatar must not use hashCode: '
              'found SigilAvatar($args)',
        );
      }
    });

    test(
      'no .hashCode usage in activity timeline code (excluding comments)',
      () {
        if (!activityTimelineFile.existsSync()) return;

        final sourceLines = activityTimelineFile.readAsStringSync().split('\n');
        final codeLines = stripComments(sourceLines);

        for (var i = 0; i < codeLines.length; i++) {
          expect(
            codeLines[i].contains('.hashCode'),
            false,
            reason:
                'No .hashCode usage should exist in activity timeline code — '
                'sigils must only use real nodeNum values. '
                'Line ${i + 1}: "${sourceLines[i].trim()}"',
          );
        }
      },
    );

    test('must NOT import user_avatar.dart', () {
      if (!activityTimelineFile.existsSync()) return;

      final source = activityTimelineFile.readAsStringSync();

      expect(
        source.contains('user_avatar.dart'),
        false,
        reason:
            'activity_timeline_screen.dart must NOT import user_avatar.dart — '
            'UserAvatar with profile avatar/displayName is forbidden. '
            'Use SigilAvatar for mesh actors and a generic person icon '
            'for unknown actors (same as signal detail _ResponseTile)',
      );
    });

    test('must NOT use UserAvatar widget in code', () {
      if (!activityTimelineFile.existsSync()) return;

      final sourceLines = activityTimelineFile.readAsStringSync().split('\n');
      final codeLines = stripComments(sourceLines);

      for (var i = 0; i < codeLines.length; i++) {
        expect(
          codeLines[i].contains('UserAvatar'),
          false,
          reason:
              'UserAvatar must NEVER appear in activity timeline code — '
              'profile-specific avatar is forbidden. '
              'Line ${i + 1}: "${sourceLines[i].trim()}"',
        );
      }
    });

    test('must NOT reference actorSnapshot.avatarUrl in code', () {
      if (!activityTimelineFile.existsSync()) return;

      final sourceLines = activityTimelineFile.readAsStringSync().split('\n');
      final codeLines = stripComments(sourceLines);

      for (var i = 0; i < codeLines.length; i++) {
        final line = codeLines[i];
        if (line.contains('actorSnapshot') && line.contains('avatarUrl')) {
          fail(
            'actorSnapshot.avatarUrl must NEVER be used for display — '
            'profile-specific avatar is forbidden in activity timeline. '
            'Line ${i + 1}: "${sourceLines[i].trim()}"',
          );
        }
      }
    });

    test(
      'must NOT use actorSnapshot.displayName as fallback actor name in code',
      () {
        if (!activityTimelineFile.existsSync()) return;

        final sourceLines = activityTimelineFile.readAsStringSync().split('\n');
        final codeLines = stripComments(sourceLines);
        final codeSource = codeLines.join('\n');

        // The pattern "actorSnapshot?.displayName ?? 'Someone'" or any
        // variant that uses the snapshot's displayName as the rendered
        // actor name is forbidden. Name must come from
        // resolveMeshNodeName() or be 'Someone'.
        final displayNameFallback = RegExp(r'actorSnapshot\??\.\s*displayName');

        // Only flag if it appears in a context that assigns to actorName
        // or is used in a Text widget / TextSpan. References in doc
        // comments are fine (already stripped).
        final matches = displayNameFallback.allMatches(codeSource);
        for (final match in matches) {
          // Get surrounding context (100 chars each side)
          final start = (match.start - 100).clamp(0, codeSource.length);
          final end = (match.end + 100).clamp(0, codeSource.length);
          final context = codeSource.substring(start, end);

          // If it is used for display (actorName assignment, Text widget),
          // fail. Allow it in description getter or model code (not in
          // this file anyway).
          fail(
            'actorSnapshot.displayName must NOT be used as actor name '
            'in activity timeline — only resolveMeshNodeName() or '
            '"Someone" are allowed. '
            'Context: "...${context.replaceAll('\n', ' ')}..."',
          );
        }
      },
    );

    test(
      'non-mesh fallback must use generic person icon, not profile data',
      () {
        if (!activityTimelineFile.existsSync()) return;

        final sourceLines = activityTimelineFile.readAsStringSync().split('\n');
        final codeLines = stripComments(sourceLines);
        final codeSource = codeLines.join('\n');

        // The non-mesh fallback must use Icons.person_rounded (same as
        // signal detail _ResponseTile), not UserAvatar or Image.network
        // with profile URLs.
        //
        // Find the else branch after the SigilAvatar and verify it uses
        // a generic icon.
        final hasSigilAvatar = codeSource.contains('SigilAvatar');
        expect(
          hasSigilAvatar,
          true,
          reason: 'Activity tile must use SigilAvatar for mesh actors',
        );

        // After SigilAvatar there should be an else branch with
        // Icons.person_rounded — matching signal detail _ResponseTile.
        expect(
          codeSource.contains('Icons.person_rounded'),
          true,
          reason:
              'Non-mesh fallback must use Icons.person_rounded (generic '
              'person icon) — same as signal detail _ResponseTile. '
              'NEVER UserAvatar with profile-specific data.',
        );
      },
    );

    test(
      'actor name for non-mesh actors must be "Someone", not displayName',
      () {
        if (!activityTimelineFile.existsSync()) return;

        final sourceLines = activityTimelineFile.readAsStringSync().split('\n');
        final codeLines = stripComments(sourceLines);
        final codeSource = codeLines.join('\n');

        // The actorName assignment for non-mesh actors must be a static
        // string like 'Someone', not derived from actorSnapshot.
        // Pattern: isMeshActor ? resolveMeshNodeName(...) : 'Someone'
        final correctPattern = RegExp(r":\s*'Someone'");
        expect(
          correctPattern.hasMatch(codeSource),
          true,
          reason:
              'Non-mesh actor name must be the literal string "Someone" — '
              'never actorSnapshot.displayName or any profile-specific name',
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // Drawer account section structural integrity
  // -----------------------------------------------------------------------
  group('Drawer account section structural integrity', () {
    test('_buildAccountSection must exist and use profileAsync.when', () {
      expect(
        mainShellSource.contains('_buildAccountSection'),
        true,
        reason: '_buildAccountSection must exist in main_shell.dart',
      );
      expect(
        mainShellSource.contains('profileAsync.when'),
        true,
        reason:
            '_buildAccountSection must use profileAsync.when to handle '
            'data/loading/error states',
      );
    });

    test('all three .when branches must be present (data, loading, error)', () {
      // Extract the full _buildAccountSection method body which
      // contains the when() call with all its nested parentheses.
      final methodLines = extractMethodBody(
        mainShellLines,
        RegExp(r'_buildAccountSection\s*\('),
      );
      expect(methodLines, isNotEmpty);

      final methodBody = methodLines.join('\n');

      expect(
        methodBody.contains('data:'),
        true,
        reason: 'profileAsync.when must have a data: branch',
      );
      expect(
        methodBody.contains('loading:'),
        true,
        reason: 'profileAsync.when must have a loading: branch',
      );
      expect(
        methodBody.contains('error:'),
        true,
        reason: 'profileAsync.when must have an error: branch',
      );
    });

    test('data and error branches must both use _buildProfileTile', () {
      final methodLines = extractMethodBody(
        mainShellLines,
        RegExp(r'_buildAccountSection\s*\('),
      );
      final methodBody = methodLines.join('\n');

      // Count _buildProfileTile references — must be at least 2
      // (one in data:, one in error:).
      final profileTileCount = RegExp(
        r'_buildProfileTile',
      ).allMatches(methodBody).length;

      expect(
        profileTileCount,
        greaterThanOrEqualTo(2),
        reason:
            'Both data: and error: branches must call _buildProfileTile '
            'to ensure consistent Guest/Not signed in display. '
            'Found $profileTileCount references, need at least 2.',
      );
    });

    test('initials fallback must be ? for null profile', () {
      expect(
        mainShellSource.contains("profile?.initials ?? '?'"),
        true,
        reason:
            '_buildProfileTile must fall back to "?" initials '
            'when profile is null',
      );
    });
  });

  // -----------------------------------------------------------------------
  // Guaranteed nodeNum baking at activity creation
  // -----------------------------------------------------------------------
  group('Activity creation — guaranteed nodeNum baking', () {
    late String activityServiceSource;
    late String signalServiceSource;
    late String socialServiceSource;
    late String storyServiceSource;

    final activityServiceFile = File(
      'lib/services/social_activity_service.dart',
    );
    final signalServiceFile = File('lib/services/signal_service.dart');
    final socialServiceFile = File('lib/services/social_service.dart');
    final storyServiceFile = File('lib/services/story_service.dart');

    setUpAll(() {
      expect(
        activityServiceFile.existsSync(),
        true,
        reason: 'social_activity_service.dart must exist',
      );
      expect(
        signalServiceFile.existsSync(),
        true,
        reason: 'signal_service.dart must exist',
      );
      expect(
        socialServiceFile.existsSync(),
        true,
        reason: 'social_service.dart must exist',
      );
      expect(
        storyServiceFile.existsSync(),
        true,
        reason: 'story_service.dart must exist',
      );

      activityServiceSource = activityServiceFile.readAsStringSync();
      signalServiceSource = signalServiceFile.readAsStringSync();
      socialServiceSource = socialServiceFile.readAsStringSync();
      storyServiceSource = storyServiceFile.readAsStringSync();
    });

    // ----- SocialActivityService -----

    test('createActivity must accept actorNodeNum parameter', () {
      // The createActivity method signature must include actorNodeNum
      final pattern = RegExp(
        r'Future<void>\s+createActivity\s*\(\{[^}]*int\?\s+actorNodeNum',
        dotAll: true,
      );
      expect(
        pattern.hasMatch(activityServiceSource),
        true,
        reason:
            'createActivity() must accept an int? actorNodeNum parameter '
            'so callers can bake the node number into the activity document',
      );
    });

    test('_getActorSnapshot must accept overrideNodeNum parameter', () {
      final pattern = RegExp(
        r'_getActorSnapshot\s*\([^)]*overrideNodeNum',
        dotAll: true,
      );
      expect(
        pattern.hasMatch(activityServiceSource),
        true,
        reason:
            '_getActorSnapshot must accept overrideNodeNum so that the '
            'caller-provided nodeNum takes priority over Firestore profile',
      );
    });

    test('createActivity must pass actorNodeNum to _getActorSnapshot', () {
      final activityLines = activityServiceSource.split('\n');
      final methodLines = extractMethodBody(
        activityLines,
        RegExp(r'Future<void>\s+createActivity\s*\('),
      );
      final methodBody = methodLines.join('\n');

      expect(
        methodBody.contains('overrideNodeNum: actorNodeNum'),
        true,
        reason:
            'createActivity must forward actorNodeNum as overrideNodeNum '
            'to _getActorSnapshot',
      );
    });

    test('all signal convenience methods must accept actorNodeNum', () {
      // These are the convenience methods that wrap createActivity
      final signalMethods = [
        'createSignalLikeActivity',
        'createSignalCommentActivity',
        'createSignalCommentReplyActivity',
        'createSignalResponseVoteActivity',
      ];

      for (final method in signalMethods) {
        final pattern = RegExp(
          '$method\\s*\\(\\{[^}]*int\\?\\s+actorNodeNum',
          dotAll: true,
        );
        expect(
          pattern.hasMatch(activityServiceSource),
          true,
          reason:
              '$method must accept int? actorNodeNum parameter '
              'and forward it to createActivity',
        );
      }
    });

    test('all social convenience methods must accept actorNodeNum', () {
      final socialMethods = [
        'createFollowActivity',
        'createFollowRequestActivity',
        'createPostLikeActivity',
        'createCommentActivity',
        'createCommentReplyActivity',
        'createCommentLikeActivity',
        'createMentionActivity',
        'createStoryLikeActivity',
      ];

      for (final method in socialMethods) {
        final pattern = RegExp(
          '$method\\s*\\(\\{[^}]*int\\?\\s+actorNodeNum',
          dotAll: true,
        );
        expect(
          pattern.hasMatch(activityServiceSource),
          true,
          reason:
              '$method must accept int? actorNodeNum parameter '
              'and forward it to createActivity',
        );
      }
    });

    test('convenience methods must pass actorNodeNum to createActivity', () {
      // Every convenience method body that calls createActivity must
      // include actorNodeNum: actorNodeNum in the call.
      final convenienceMethods = [
        'createSignalLikeActivity',
        'createSignalCommentActivity',
        'createSignalCommentReplyActivity',
        'createSignalResponseVoteActivity',
        'createFollowActivity',
        'createFollowRequestActivity',
        'createPostLikeActivity',
        'createCommentActivity',
        'createCommentReplyActivity',
        'createCommentLikeActivity',
        'createMentionActivity',
        'createStoryLikeActivity',
      ];

      final activityLines = activityServiceSource.split('\n');
      for (final method in convenienceMethods) {
        final methodLines = extractMethodBody(
          activityLines,
          RegExp('$method\\s*\\('),
        );
        final methodBody = methodLines.join('\n');
        expect(
          methodBody.contains('actorNodeNum: actorNodeNum'),
          true,
          reason:
              '$method must forward actorNodeNum: actorNodeNum '
              'to createActivity',
        );
      }
    });

    // ----- SignalService -----

    test('SignalService.createResponse must accept actorNodeNum', () {
      final pattern = RegExp(
        r'createResponse\s*\(\{[^}]*int\?\s+actorNodeNum',
        dotAll: true,
      );
      expect(
        pattern.hasMatch(signalServiceSource),
        true,
        reason:
            'SignalService.createResponse() must accept int? actorNodeNum '
            'to bake into activity documents',
      );
    });

    test('SignalService.setVote must accept actorNodeNum', () {
      final pattern = RegExp(
        r'setVote\s*\(\{[^}]*int\?\s+actorNodeNum',
        dotAll: true,
      );
      expect(
        pattern.hasMatch(signalServiceSource),
        true,
        reason:
            'SignalService.setVote() must accept int? actorNodeNum '
            'to bake into vote activity documents',
      );
    });

    test('SignalService._createResponseActivity must accept actorNodeNum', () {
      final pattern = RegExp(
        r'_createResponseActivity\s*\(\{[^}]*int\?\s+actorNodeNum',
        dotAll: true,
      );
      expect(
        pattern.hasMatch(signalServiceSource),
        true,
        reason:
            '_createResponseActivity must accept int? actorNodeNum '
            'and forward it to activity service convenience methods',
      );
    });

    test('SignalService._createVoteActivity must accept actorNodeNum', () {
      final pattern = RegExp(
        r'_createVoteActivity\s*\(\{[^}]*int\?\s+actorNodeNum',
        dotAll: true,
      );
      expect(
        pattern.hasMatch(signalServiceSource),
        true,
        reason:
            '_createVoteActivity must accept int? actorNodeNum '
            'and forward it to createSignalResponseVoteActivity',
      );
    });

    // ----- SocialService -----

    test('SocialService.followUser must accept actorNodeNum', () {
      final pattern = RegExp(
        r'followUser\s*\(String\s+\w+,?\s*\{[^}]*int\?\s+actorNodeNum',
        dotAll: true,
      );
      expect(
        pattern.hasMatch(socialServiceSource),
        true,
        reason:
            'SocialService.followUser() must accept int? actorNodeNum '
            'to bake into follow activity documents',
      );
    });

    test('SocialService.acceptFollowRequest must accept actorNodeNum', () {
      final pattern = RegExp(
        r'acceptFollowRequest\s*\([^)]*int\?\s+actorNodeNum',
        dotAll: true,
      );
      expect(
        pattern.hasMatch(socialServiceSource),
        true,
        reason:
            'SocialService.acceptFollowRequest() must accept '
            'int? actorNodeNum to bake into follow activity documents',
      );
    });

    test('SocialService.createComment must accept actorNodeNum', () {
      final pattern = RegExp(
        r'createComment\s*\(\{[^}]*int\?\s+actorNodeNum',
        dotAll: true,
      );
      expect(
        pattern.hasMatch(socialServiceSource),
        true,
        reason:
            'SocialService.createComment() must accept int? actorNodeNum '
            'to bake into comment/reply/mention activity documents',
      );
    });

    test('SocialService.likePost must accept actorNodeNum', () {
      final pattern = RegExp(
        r'likePost\s*\(String\s+\w+,?\s*\{[^}]*int\?\s+actorNodeNum',
        dotAll: true,
      );
      expect(
        pattern.hasMatch(socialServiceSource),
        true,
        reason:
            'SocialService.likePost() must accept int? actorNodeNum '
            'to bake into like activity documents',
      );
    });

    test('SocialService.likeComment must accept actorNodeNum', () {
      final pattern = RegExp(
        r'likeComment\s*\(String\s+\w+,?\s*\{[^}]*int\?\s+actorNodeNum',
        dotAll: true,
      );
      expect(
        pattern.hasMatch(socialServiceSource),
        true,
        reason:
            'SocialService.likeComment() must accept int? actorNodeNum '
            'to bake into comment like activity documents',
      );
    });

    // ----- StoryService -----

    test('StoryService.likeStory must accept actorNodeNum', () {
      final pattern = RegExp(
        r'likeStory\s*\(String\s+\w+,?\s*\{[^}]*int\?\s+actorNodeNum',
        dotAll: true,
      );
      expect(
        pattern.hasMatch(storyServiceSource),
        true,
        reason:
            'StoryService.likeStory() must accept int? actorNodeNum '
            'to bake into story like activity documents',
      );
    });

    // ----- Provider/UI callers must pass myNodeNumProvider -----

    test('social_providers.dart callers must read myNodeNumProvider', () {
      final socialProvidersFile = File('lib/providers/social_providers.dart');
      expect(socialProvidersFile.existsSync(), true);
      final source = socialProvidersFile.readAsStringSync();

      // toggleFollow, acceptFollowRequest, addComment, toggleLike,
      // CreatePostNotifier.createPost — all must read myNodeNumProvider
      // and pass actorNodeNum to the service.
      final myNodeNumReads = RegExp(
        r'ref\.read\(myNodeNumProvider\)',
      ).allMatches(source).length;

      // At least 5 reads: toggleFollow, acceptFollowRequest, addComment,
      // toggleLike, CreatePostNotifier.createPost
      expect(
        myNodeNumReads,
        greaterThanOrEqualTo(5),
        reason:
            'social_providers.dart must read myNodeNumProvider at least '
            '5 times (toggleFollow, acceptFollowRequest, addComment, '
            'toggleLike, createPost). Found $myNodeNumReads reads.',
      );

      // Verify actorNodeNum is passed to service calls
      expect(
        source.contains('actorNodeNum: myNodeNum'),
        true,
        reason:
            'social_providers.dart must pass actorNodeNum: myNodeNum '
            'to service methods that create activities',
      );
    });

    test('story_providers.dart callers must read myNodeNumProvider', () {
      final storyProvidersFile = File('lib/providers/story_providers.dart');
      expect(storyProvidersFile.existsSync(), true);
      final source = storyProvidersFile.readAsStringSync();

      expect(
        source.contains('ref.read(myNodeNumProvider)'),
        true,
        reason:
            'story_providers.dart must read myNodeNumProvider to pass '
            'actorNodeNum when liking stories',
      );

      expect(
        source.contains('actorNodeNum: myNodeNum'),
        true,
        reason:
            'story_providers.dart must pass actorNodeNum: myNodeNum '
            'to likeStory()',
      );
    });

    test('signal_detail_screen.dart callers must read myNodeNumProvider', () {
      final signalDetailFile = File(
        'lib/features/signals/screens/signal_detail_screen.dart',
      );
      expect(signalDetailFile.existsSync(), true);
      final source = signalDetailFile.readAsStringSync();

      // Must read myNodeNumProvider for createResponse and setVote/clearVote
      final myNodeNumReads = RegExp(
        r'ref\.read\(myNodeNumProvider\)',
      ).allMatches(source).length;

      // At least 3: _setVote, _removeVote, _submitReply
      expect(
        myNodeNumReads,
        greaterThanOrEqualTo(3),
        reason:
            'signal_detail_screen.dart must read myNodeNumProvider at '
            'least 3 times (setVote, clearVote, createResponse). '
            'Found $myNodeNumReads reads.',
      );

      expect(
        source.contains('actorNodeNum: myNodeNum'),
        true,
        reason:
            'signal_detail_screen.dart must pass actorNodeNum: myNodeNum '
            'to SignalService methods',
      );
    });

    // ----- Snapshot override semantics -----

    test(
      '_getActorSnapshot must prefer overrideNodeNum over Firestore value',
      () {
        // The method must contain logic that prefers the override.
        // Pattern: overrideNodeNum ?? (data['primaryNodeId'] as int?)
        final pattern = RegExp(
          r"overrideNodeNum\s*\?\?\s*\(?\s*data\['primaryNodeId'\]",
        );
        expect(
          pattern.hasMatch(activityServiceSource),
          true,
          reason:
              '_getActorSnapshot must use '
              "overrideNodeNum ?? data['primaryNodeId'] "
              'to prefer the caller-provided nodeNum over the Firestore '
              'profile value',
        );
      },
    );

    test(
      '_getActorSnapshot must return minimal snapshot when Firebase is unavailable but nodeNum is provided',
      () {
        // When firestore is null but overrideNodeNum is present, the method
        // must still return a PostAuthorSnapshot with the nodeNum baked in.
        final activityLines = activityServiceSource.split('\n');
        final methodLines = extractMethodBody(
          activityLines,
          RegExp(r'Future<PostAuthorSnapshot\?>\s+_getActorSnapshot\s*\('),
        );
        final methodBody = methodLines.join('\n');

        // Must check: if overrideNodeNum != null, return snapshot
        // even when firestore is null or doc doesn't exist
        expect(
          methodBody.contains('overrideNodeNum != null'),
          true,
          reason:
              '_getActorSnapshot must check overrideNodeNum != null and '
              'return a minimal PostAuthorSnapshot when Firebase is '
              'unavailable, so the activity still gets a baked nodeNum',
        );

        // Must construct PostAuthorSnapshot with nodeNum: overrideNodeNum
        expect(
          methodBody.contains('nodeNum: overrideNodeNum'),
          true,
          reason:
              '_getActorSnapshot must construct PostAuthorSnapshot with '
              'nodeNum: overrideNodeNum in fallback paths',
        );
      },
    );
  });
}
