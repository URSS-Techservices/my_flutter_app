import 'package:flutter_test/flutter_test.dart';
import 'package:halo/core/session.dart';
import 'package:halo/features/auth/domain/session_mapper.dart';
import 'package:halo/screens/profile/core/profile_type.dart';

void main() {
  test('tryProfileKindFromAccountType is null until the user picks a type', () {
    expect(tryProfileKindFromAccountType(null), isNull);
    expect(tryProfileKindFromAccountType(''), isNull);
    expect(tryProfileKindFromAccountType('  '), isNull);
  });

  test('tryProfileKindFromAccountType maps wizard category labels', () {
    expect(tryProfileKindFromAccountType('Aspirant'), ProfileKind.aspirant);
    expect(tryProfileKindFromAccountType('guru'), ProfileKind.guru);
    expect(tryProfileKindFromAccountType('Wellness'), ProfileKind.wellness);
  });

  test('profileKindFromAccountType still defaults unknown to aspirant', () {
    expect(profileKindFromAccountType(null), ProfileKind.aspirant);
  });

  test('unverified email/password user is gated before onboarding', () {
    final session = sessionFromUserDoc(
      'u1',
      {'accountType': 'aspirant', 'username': 'pat'},
      email: 'a@b.com',
      requiresEmailVerification: true,
    );
    expect(session.status, SessionStatus.emailVerificationRequired);
    expect(session.email, 'a@b.com');
    expect(session.onboardingCompleted, isFalse);
  });

  test('no HALO doc routes to category selection', () {
    final session = sessionFromUserDoc('u1', null, email: 'a@b.com');
    expect(session.status, SessionStatus.onboardingRequired);
    expect(session.needsCategorySelection, isTrue);
    expect(session.needsProfileOnboarding, isFalse);
  });

  test('stub doc without account type routes to category selection', () {
    final session = sessionFromUserDoc('u1', {
      'email': 'a@b.com',
      'loginType': 'google',
      'onboardingCompleted': false,
    });
    expect(session.status, SessionStatus.onboardingRequired);
    expect(session.needsCategorySelection, isTrue);
  });

  test('account type chosen but profile unfinished resumes profile', () {
    final session = sessionFromUserDoc('u1', {
      'accountType': 'guru',
      'onboardingCompleted': false,
    });
    expect(session.status, SessionStatus.onboardingRequired);
    expect(session.accountType, 'guru');
    expect(session.needsProfileOnboarding, isTrue);
    expect(session.needsCategorySelection, isFalse);
  });

  test('onboardingCompleted true goes home', () {
    final session = sessionFromUserDoc('u1', {
      'accountType': 'wellness',
      'onboardingCompleted': true,
    });
    expect(session.status, SessionStatus.authenticated);
    expect(session.onboardingCompleted, isTrue);
  });

  test('legacy profile with username skips onboarding', () {
    final session = sessionFromUserDoc('u1', {
      'category': 'Guru',
      'username': 'olduser',
    });
    expect(session.status, SessionStatus.authenticated);
    expect(session.accountType, 'guru');
  });
}
