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

  test('sessionFromUserDoc asks for type when the user doc has none', () {
    final session = sessionFromUserDoc('u1', {'email': 'a@b.com'});
    expect(session.status, SessionStatus.needsAccountType);
    expect(session.uid, 'u1');
  });

  test('sessionFromUserDoc is ready when category is set', () {
    final session = sessionFromUserDoc('u1', {'category': 'Guru'});
    expect(session.status, SessionStatus.ready);
    expect(session.accountType, 'guru');
  });
}
