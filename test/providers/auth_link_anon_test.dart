// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Unit tests for `AuthService.linkAnonOrSignInWithCredential` and
// `AuthService.linkAnonOrSignInWithProvider` — the helpers that decide
// between linking a credential to an existing anonymous user vs. doing
// a plain sign-in.
//
// These helpers are the bridge between two states:
//   1. `_ensureAnonymousAuth` (in main.dart) creates an anon uid at
//      app launch.
//   2. The user later signs in with Google/Apple/email/etc.
//
// Without the link, the anon uid is discarded and any data keyed off
// it (profile, bug history, app-state Firestore docs) is orphaned. The
// 6 tests here pin every branch of the decision so a future refactor
// can't silently regress that contract.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:socialmesh/providers/auth_providers.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockUserCredential extends Mock implements UserCredential {}

class _MockAuthCredential extends Mock implements AuthCredential {}

class _MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  late _MockFirebaseAuth auth;
  late AuthService service;
  late _MockUserCredential signInResult;
  late _MockUserCredential linkResult;

  setUpAll(() {
    // Required by mocktail when stubbing methods that take these as
    // positional or named arguments.
    registerFallbackValue(_MockAuthCredential());
    registerFallbackValue(_MockAuthProvider());
  });

  setUp(() {
    auth = _MockFirebaseAuth();
    service = AuthService(auth);
    signInResult = _MockUserCredential();
    linkResult = _MockUserCredential();
  });

  // ---------------------------------------------------------------------------
  // linkAnonOrSignInWithCredential
  // ---------------------------------------------------------------------------

  group('linkAnonOrSignInWithCredential', () {
    test('no current user → falls through to signInWithCredential', () async {
      when(() => auth.currentUser).thenReturn(null);
      when(
        () => auth.signInWithCredential(any()),
      ).thenAnswer((_) async => signInResult);

      final credential = _MockAuthCredential();
      final result = await service.linkAnonOrSignInWithCredential(credential);

      expect(result, signInResult);
      // Critically: never even attempted to call link*.
      verify(() => auth.signInWithCredential(credential)).called(1);
    });

    test('non-anonymous current user → falls through to signInWithCredential '
        '(does not link an already-real account)', () async {
      // A user who is already signed in with a real provider
      // shouldn't be link-upgraded — that's a no-op or an error
      // depending on the credential. Plain sign-in is the right call
      // (e.g. switching accounts).
      final realUser = _MockUser();
      when(() => realUser.isAnonymous).thenReturn(false);
      when(() => realUser.uid).thenReturn('real-uid');
      when(() => auth.currentUser).thenReturn(realUser);
      when(
        () => auth.signInWithCredential(any()),
      ).thenAnswer((_) async => signInResult);

      final credential = _MockAuthCredential();
      final result = await service.linkAnonOrSignInWithCredential(credential);

      expect(result, signInResult);
      verifyNever(() => realUser.linkWithCredential(any()));
      verify(() => auth.signInWithCredential(credential)).called(1);
    });

    test('anonymous user + clean link → returns linked credential, '
        'preserves uid (no signInWithCredential fallback)', () async {
      // The happy path that justifies the whole helper. The anon
      // uid is preserved because we link instead of sign-in.
      final anonUser = _MockUser();
      when(() => anonUser.isAnonymous).thenReturn(true);
      when(() => anonUser.uid).thenReturn('anon-uid-12345');
      when(() => auth.currentUser).thenReturn(anonUser);
      when(
        () => anonUser.linkWithCredential(any()),
      ).thenAnswer((_) async => linkResult);

      final credential = _MockAuthCredential();
      final result = await service.linkAnonOrSignInWithCredential(credential);

      expect(result, linkResult);
      verify(() => anonUser.linkWithCredential(credential)).called(1);
      // MUST NOT have fallen through to sign-in — that would have
      // discarded the anon uid.
      verifyNever(() => auth.signInWithCredential(any()));
    });

    test(
      'anonymous user + link conflict (credential-already-in-use) → '
      'falls back to signInWithCredential (anon orphaned, but user gets in)',
      () async {
        // The credential belongs to an existing real account.
        // Surfacing the link error to the UI would block sign-in; we
        // pragmatically fall back to plain sign-in. Anon data orphaned
        // is the lesser evil vs. user can't sign in.
        final anonUser = _MockUser();
        when(() => anonUser.isAnonymous).thenReturn(true);
        when(() => anonUser.uid).thenReturn('anon-uid-12345');
        when(() => auth.currentUser).thenReturn(anonUser);
        when(
          () => anonUser.linkWithCredential(any()),
        ).thenThrow(FirebaseAuthException(code: 'credential-already-in-use'));
        when(
          () => auth.signInWithCredential(any()),
        ).thenAnswer((_) async => signInResult);

        final credential = _MockAuthCredential();
        final result = await service.linkAnonOrSignInWithCredential(credential);

        expect(result, signInResult);
        verify(() => anonUser.linkWithCredential(credential)).called(1);
        verify(() => auth.signInWithCredential(credential)).called(1);
      },
    );

    test('anonymous user + link conflict (email-already-in-use) → '
        'same fallback as credential-already-in-use', () async {
      // Same fallback for email-based credential reuse. Tests both
      // codes are handled identically.
      final anonUser = _MockUser();
      when(() => anonUser.isAnonymous).thenReturn(true);
      when(() => anonUser.uid).thenReturn('anon-uid-12345');
      when(() => auth.currentUser).thenReturn(anonUser);
      when(
        () => anonUser.linkWithCredential(any()),
      ).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
      when(
        () => auth.signInWithCredential(any()),
      ).thenAnswer((_) async => signInResult);

      final credential = _MockAuthCredential();
      final result = await service.linkAnonOrSignInWithCredential(credential);

      expect(result, signInResult);
    });

    test('anonymous user + non-conflict FirebaseAuthException → rethrows '
        '(no silent fallback for unrelated errors)', () async {
      // Critical: only credential/email conflicts should fall back.
      // Other errors (network-request-failed, invalid-credential,
      // user-disabled, etc.) MUST propagate so the UI can surface
      // them properly. Silent fallback on, say, a network error
      // would attempt a sign-in over the same broken connection
      // and probably fail the same way — but with confusing logs.
      final anonUser = _MockUser();
      when(() => anonUser.isAnonymous).thenReturn(true);
      when(() => anonUser.uid).thenReturn('anon-uid-12345');
      when(() => auth.currentUser).thenReturn(anonUser);
      when(
        () => anonUser.linkWithCredential(any()),
      ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      final credential = _MockAuthCredential();
      await expectLater(
        () => service.linkAnonOrSignInWithCredential(credential),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'network-request-failed',
          ),
        ),
      );
      // MUST NOT have fallen back to sign-in for a non-conflict error.
      verifyNever(() => auth.signInWithCredential(any()));
    });
  });

  // ---------------------------------------------------------------------------
  // linkAnonOrSignInWithProvider
  // ---------------------------------------------------------------------------

  group('linkAnonOrSignInWithProvider', () {
    test('no current user → falls through to signInWithProvider', () async {
      when(() => auth.currentUser).thenReturn(null);
      when(
        () => auth.signInWithProvider(any()),
      ).thenAnswer((_) async => signInResult);

      final provider = _MockAuthProvider();
      final result = await service.linkAnonOrSignInWithProvider(provider);

      expect(result, signInResult);
      verify(() => auth.signInWithProvider(provider)).called(1);
    });

    test(
      'anonymous user + clean link → returns linked credential, preserves uid',
      () async {
        final anonUser = _MockUser();
        when(() => anonUser.isAnonymous).thenReturn(true);
        when(() => anonUser.uid).thenReturn('anon-uid-12345');
        when(() => auth.currentUser).thenReturn(anonUser);
        when(
          () => anonUser.linkWithProvider(any()),
        ).thenAnswer((_) async => linkResult);

        final provider = _MockAuthProvider();
        final result = await service.linkAnonOrSignInWithProvider(provider);

        expect(result, linkResult);
        verify(() => anonUser.linkWithProvider(provider)).called(1);
        verifyNever(() => auth.signInWithProvider(any()));
      },
    );

    test(
      'anonymous user + provider link conflict → falls back to signInWithProvider',
      () async {
        final anonUser = _MockUser();
        when(() => anonUser.isAnonymous).thenReturn(true);
        when(() => anonUser.uid).thenReturn('anon-uid-12345');
        when(() => auth.currentUser).thenReturn(anonUser);
        when(
          () => anonUser.linkWithProvider(any()),
        ).thenThrow(FirebaseAuthException(code: 'credential-already-in-use'));
        when(
          () => auth.signInWithProvider(any()),
        ).thenAnswer((_) async => signInResult);

        final provider = _MockAuthProvider();
        final result = await service.linkAnonOrSignInWithProvider(provider);

        expect(result, signInResult);
        verify(() => anonUser.linkWithProvider(provider)).called(1);
        verify(() => auth.signInWithProvider(provider)).called(1);
      },
    );
  });
}
