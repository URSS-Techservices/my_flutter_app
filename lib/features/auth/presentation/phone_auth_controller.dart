import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/auth/domain/auth_repository.dart';
import 'package:halo/features/auth/presentation/session_controller.dart';

/// Which half of the phone flow the UI should show.
enum PhoneAuthStep { enterNumber, enterOtp }

/// A single user-facing message. [isError] drives colour and icon so the page
/// needs no second channel for warnings.
class PhoneAuthFeedback {
  const PhoneAuthFeedback(this.text, {this.isError = true});

  final String text;
  final bool isError;
}

class PhoneAuthState {
  const PhoneAuthState({
    this.step = PhoneAuthStep.enterNumber,
    this.verificationId,
    this.resendToken,
    this.phoneNumber,
    this.busy = false,
    this.feedback,
    this.resendIn = 0,
  });

  final PhoneAuthStep step;
  final String? verificationId;
  final int? resendToken;
  final String? phoneNumber;
  final bool busy;
  final PhoneAuthFeedback? feedback;

  /// Seconds left before another SMS is allowed. Zero means resend is open.
  final int resendIn;

  bool get canResend => phoneNumber != null && !busy && resendIn == 0;

  PhoneAuthState copyWith({
    PhoneAuthStep? step,
    String? verificationId,
    int? resendToken,
    String? phoneNumber,
    bool? busy,
    PhoneAuthFeedback? feedback,
    bool clearFeedback = false,
    int? resendIn,
  }) {
    return PhoneAuthState(
      step: step ?? this.step,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      busy: busy ?? this.busy,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      resendIn: resendIn ?? this.resendIn,
    );
  }
}

final phoneAuthControllerProvider =
    StateNotifierProvider<PhoneAuthController, PhoneAuthState>((ref) {
  return PhoneAuthController(ref.watch(authRepositoryProvider));
});

/// Drives phone OTP sign-in. Holds no Firebase types — everything goes through
/// [AuthRepository], so this stays testable.
///
/// Every SMS costs money and Firebase rate-limits aggressively, so a request is
/// only ever in flight once and a cooldown blocks repeat sends.
class PhoneAuthController extends StateNotifier<PhoneAuthState> {
  PhoneAuthController(this._repo) : super(const PhoneAuthState());

  final AuthRepository _repo;

  static const _cooldownSeconds = 45;

  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// [rawNumber] is the digits the user typed; [dialCode] is like `+91`.
  Future<void> sendOtp({
    required String rawNumber,
    String dialCode = '+91',
  }) async {
    if (state.busy) {
      _flash('Sending your OTP, one moment…', isError: false);
      return;
    }
    final e164 = _toE164(rawNumber, dialCode);
    if (e164 == null) {
      _flash('Enter a valid 10-digit mobile number');
      return;
    }
    // Re-tapping Send for a number that already has a live code should not
    // burn another SMS.
    if (state.resendIn > 0 && state.phoneNumber == e164) {
      _flash(
        'OTP already sent to $e164. You can resend in ${state.resendIn}s.',
        isError: false,
      );
      state = state.copyWith(step: PhoneAuthStep.enterOtp);
      return;
    }
    await _requestOtp(phoneNumber: e164);
  }

  /// Resends to the same number, reusing the token so Android does not
  /// restart verification from scratch.
  Future<void> resendOtp() async {
    if (state.busy) return;
    final number = state.phoneNumber;
    if (number == null) return;
    if (state.resendIn > 0) {
      _flash(
        'OTP already sent. You can resend in ${state.resendIn}s.',
        isError: false,
      );
      return;
    }
    await _requestOtp(phoneNumber: number, resendToken: state.resendToken);
  }

  Future<void> _requestOtp({
    required String phoneNumber,
    int? resendToken,
  }) async {
    state = state.copyWith(
      busy: true,
      phoneNumber: phoneNumber,
      clearFeedback: true,
    );
    try {
      final session = await _repo.sendPhoneOtp(
        phoneNumber: phoneNumber,
        resendToken: resendToken,
        // Can arrive a minute after this future resolves, while the user is
        // still typing. Keeping the newest id is what prevents a bogus
        // "OTP expired" on an otherwise correct code.
        onVerificationId: (id) {
          if (!mounted) return;
          state = state.copyWith(verificationId: id);
        },
      );
      if (!mounted) return;
      if (session.autoVerified) {
        // Already signed in; the session stream moves the app on.
        _ticker?.cancel();
        state = state.copyWith(busy: false);
        return;
      }
      state = state.copyWith(
        busy: false,
        step: PhoneAuthStep.enterOtp,
        verificationId: session.verificationId,
        resendToken: session.resendToken,
        feedback: PhoneAuthFeedback(
          'OTP sent to $phoneNumber',
          isError: false,
        ),
      );
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(busy: false, feedback: PhoneAuthFeedback(_message(e)));
    }
  }

  Future<void> verifyOtp(String smsCode) async {
    if (state.busy) return;
    final verificationId = state.verificationId;
    if (verificationId == null) {
      _flash('Request a new OTP.');
      return;
    }
    final code = smsCode.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _flash('Enter the 6-digit OTP');
      return;
    }
    state = state.copyWith(busy: true, clearFeedback: true);
    try {
      await _repo.verifyPhoneOtp(
        verificationId: verificationId,
        smsCode: code,
      );
      if (!mounted) return;
      _ticker?.cancel();
      state = state.copyWith(busy: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(busy: false, feedback: PhoneAuthFeedback(_message(e)));
    }
  }

  void backToNumber() {
    _ticker?.cancel();
    state = const PhoneAuthState();
  }

  void clearFeedback() {
    if (state.feedback == null) return;
    state = state.copyWith(clearFeedback: true);
  }

  void _flash(String text, {bool isError = true}) {
    state = state.copyWith(feedback: PhoneAuthFeedback(text, isError: isError));
  }

  void _startCooldown() {
    _ticker?.cancel();
    state = state.copyWith(resendIn: _cooldownSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = state.resendIn - 1;
      state = state.copyWith(resendIn: next < 0 ? 0 : next);
      if (next <= 0) timer.cancel();
    });
  }

  /// Firebase needs E.164. Accepts `9876543210`, `09876543210`,
  /// `+91 98765 43210`, and spaced or dashed variants.
  static String? _toE164(String raw, String dialCode) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('+')) {
      final digits = trimmed.substring(1).replaceAll(RegExp(r'\D'), '');
      return digits.length >= 10 ? '+$digits' : null;
    }
    var digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length != 10) return null;
    return '$dialCode$digits';
  }

  static String _message(Object error) {
    final text = error.toString();
    if (text.contains('invalid-phone-number')) {
      return 'That mobile number is not valid.';
    }
    if (text.contains('invalid-verification-code')) {
      return 'Wrong OTP. Please check and try again.';
    }
    if (text.contains('session-expired')) {
      return 'OTP expired. Tap resend to get a new one.';
    }
    if (text.contains('too-many-requests')) {
      return 'Too many attempts. Try again later.';
    }
    if (text.contains('network-request-failed')) {
      return 'No internet connection. Check your network.';
    }
    if (text.contains('billing-not-enabled') ||
        text.contains('BILLING_NOT_ENABLED')) {
      return 'SMS is not enabled on this Firebase project yet.';
    }
    return 'Could not verify your number. Please try again.';
  }
}
