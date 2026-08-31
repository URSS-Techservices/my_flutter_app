import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/core/halo_theme.dart';
import 'package:halo/features/auth/presentation/phone_auth_controller.dart';

const _kFieldFill = Color(0xFFF7F5FA);
const _kFieldBorder = Color(0xFFE7E3ED);
const _kErrorColor = Color(0xFFFF3B30);
const _kSuccessColor = Color(0xFF34C759);

/// Phone OTP sign-in. Two steps in one page: number, then the 6-digit code.
/// No Firebase here — everything goes through [phoneAuthControllerProvider].
/// On success the session stream moves the app on, so this page only pops.
class PhoneLoginPage extends ConsumerStatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  ConsumerState<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends ConsumerState<PhoneLoginPage> {
  final _numberController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Send button enables itself once the number looks complete.
    _numberController.addListener(_onNumberChanged);
    // Fresh flow each time the page opens.
    Future.microtask(
      () => ref.read(phoneAuthControllerProvider.notifier).backToNumber(),
    );
  }

  @override
  void dispose() {
    _numberController
      ..removeListener(_onNumberChanged)
      ..dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _onNumberChanged() => setState(() {});

  bool get _numberLooksComplete => _numberController.text.length == 10;

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(phoneAuthControllerProvider.notifier)
        .sendOtp(rawNumber: _numberController.text);
  }

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(phoneAuthControllerProvider.notifier)
        .verifyOtp(_otpController.text);
  }

  void _backToNumber() {
    _otpController.clear();
    ref.read(phoneAuthControllerProvider.notifier).backToNumber();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    final onOtpStep = state.step == PhoneAuthStep.enterOtp;

    // A wrong code deserves a nudge the user can feel, not just read.
    ref.listen(phoneAuthControllerProvider, (previous, next) {
      final feedback = next.feedback;
      if (feedback == null || previous?.feedback == feedback) return;
      if (feedback.isError) HapticFeedback.mediumImpact();
    });

    return PopScope(
      canPop: !onOtpStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToNumber();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F7FC),
        body: Stack(
          children: [
            const _BackdropGlow(),
            SafeArea(
              child: Column(
                children: [
                  _TopBar(onBack: () => Navigator.maybePop(context)),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Column(
                            children: [
                              _Header(
                                textTheme: textTheme,
                                onOtpStep: onOtpStep,
                                phoneNumber: state.phoneNumber,
                                onChangeNumber: _backToNumber,
                              ),
                              const SizedBox(height: 24),
                              _Card(
                                child: AnimatedSize(
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topCenter,
                                  child: onOtpStep
                                      ? _OtpStep(
                                          state: state,
                                          textTheme: textTheme,
                                          controller: _otpController,
                                          onVerify: _verifyOtp,
                                          onResend: () => ref
                                              .read(phoneAuthControllerProvider
                                                  .notifier)
                                              .resendOtp(),
                                        )
                                      : _NumberStep(
                                          state: state,
                                          textTheme: textTheme,
                                          controller: _numberController,
                                          canSubmit: _numberLooksComplete,
                                          onSend: _sendOtp,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Standard SMS charges may apply.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.black38,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft brand-tinted glow so the flat background does not feel empty.
class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                kPrimaryColor.withValues(alpha: 0.10),
                const Color(0xFFF9F7FC),
                const Color(0xFFF9F7FC),
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(CupertinoIcons.chevron_left),
            color: Colors.black87,
            tooltip: 'Back',
          ),
          const Spacer(),
          Text(
            'Halo.',
            style: GoogleFonts.pacifico(
              fontSize: 22,
              fontStyle: FontStyle.italic,
              color: kPrimaryColor,
            ),
          ),
          const Spacer(),
          // Balances the leading IconButton so the wordmark sits centred.
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.textTheme,
    required this.onOtpStep,
    required this.phoneNumber,
    required this.onChangeNumber,
  });

  final TextTheme textTheme;
  final bool onOtpStep;
  final String? phoneNumber;
  final VoidCallback onChangeNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 62,
          width: 62,
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            onOtpStep
                ? CupertinoIcons.chat_bubble_text_fill
                : CupertinoIcons.device_phone_portrait,
            color: kPrimaryColor,
            size: 28,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          onOtpStep ? 'Enter the code' : 'Verify your number',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        if (!onOtpStep)
          Text(
            'We will text you a 6-digit code to confirm\nit is really you.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.black54,
              height: 1.45,
            ),
          )
        else ...[
          Text(
            'Sent to',
            style: textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          // Tappable so a typo never traps the user on this step.
          GestureDetector(
            onTap: onChangeNumber,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _kFieldBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    phoneNumber ?? '',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    CupertinoIcons.pencil,
                    size: 15,
                    color: kPrimaryColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withValues(alpha: 0.20),
            blurRadius: 30,
            spreadRadius: -12,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _NumberStep extends StatelessWidget {
  const _NumberStep({
    required this.state,
    required this.textTheme,
    required this.controller,
    required this.canSubmit,
    required this.onSend,
  });

  final PhoneAuthState state;
  final TextTheme textTheme;
  final TextEditingController controller;
  final bool canSubmit;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('number-step'),
      children: [
        Container(
          decoration: BoxDecoration(
            color: _kFieldFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kFieldBorder),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '+91',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(width: 1, height: 26, color: _kFieldBorder),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  enabled: !state.busy,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (canSubmit && !state.busy) onSend();
                  },
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                  decoration: InputDecoration(
                    hintText: '98765 43210',
                    hintStyle: textTheme.titleMedium?.copyWith(
                      color: Colors.black26,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.1,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _FeedbackLine(feedback: state.feedback, textTheme: textTheme),
        const SizedBox(height: 18),
        _PrimaryButton(
          label: 'Send OTP',
          busy: state.busy,
          // Disabled until the number is plausible, so a premature tap is
          // impossible rather than merely rejected.
          onPressed: canSubmit ? onSend : null,
          textTheme: textTheme,
        ),
      ],
    );
  }
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.state,
    required this.textTheme,
    required this.controller,
    required this.onVerify,
    required this.onResend,
  });

  final PhoneAuthState state;
  final TextTheme textTheme;
  final TextEditingController controller;
  final Future<void> Function() onVerify;
  final Future<void> Function() onResend;

  @override
  Widget build(BuildContext context) {
    final hasError = state.feedback?.isError ?? false;
    return Column(
      key: const ValueKey('otp-step'),
      children: [
        _OtpField(
          controller: controller,
          hasError: hasError,
          enabled: !state.busy,
          onCompleted: (_) => onVerify(),
        ),
        _FeedbackLine(feedback: state.feedback, textTheme: textTheme),
        const SizedBox(height: 18),
        _PrimaryButton(
          label: 'Verify & continue',
          busy: state.busy,
          onPressed: state.busy ? null : onVerify,
          textTheme: textTheme,
        ),
        const SizedBox(height: 6),
        _ResendRow(
          state: state,
          textTheme: textTheme,
          onResend: onResend,
        ),
      ],
    );
  }
}

/// Six boxes backed by one invisible field, so paste, backspace and SMS
/// autofill all behave the way the platform already knows how to do.
class _OtpField extends StatefulWidget {
  const _OtpField({
    required this.controller,
    required this.hasError,
    required this.enabled,
    required this.onCompleted,
  });

  final TextEditingController controller;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String> onCompleted;

  @override
  State<_OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<_OtpField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: List.generate(6, (index) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.5),
                  child: _box(index, code),
                ),
              );
            }),
          ),
          Positioned.fill(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: true,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              showCursor: false,
              enableInteractiveSelection: false,
              cursorColor: Colors.transparent,
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                setState(() {});
                if (value.length == 6) widget.onCompleted(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(int index, String code) {
    final filled = index < code.length;
    final active = index == code.length && _focus.hasFocus;

    final Color border;
    if (widget.hasError) {
      border = _kErrorColor;
    } else if (active) {
      border = kPrimaryColor;
    } else if (filled) {
      border = kPrimaryColor.withValues(alpha: 0.45);
    } else {
      border = _kFieldBorder;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 56,
      decoration: BoxDecoration(
        color: filled ? kPrimaryColor.withValues(alpha: 0.06) : _kFieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: active || filled ? 1.6 : 1),
      ),
      alignment: Alignment.center,
      child: Text(
        filled ? code[index] : '',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.state,
    required this.textTheme,
    required this.onResend,
  });

  final PhoneAuthState state;
  final TextTheme textTheme;
  final Future<void> Function() onResend;

  @override
  Widget build(BuildContext context) {
    final waiting = state.resendIn > 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Didn't get the code?",
          style: textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
        TextButton(
          onPressed: state.canResend ? onResend : null,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
          ),
          child: Text(
            // The countdown is the honest answer to "why can't I tap this".
            waiting ? 'Resend in ${state.resendIn}s' : 'Resend OTP',
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: waiting ? Colors.black38 : kPrimaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackLine extends StatelessWidget {
  const _FeedbackLine({required this.feedback, required this.textTheme});

  final PhoneAuthFeedback? feedback;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final message = feedback;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    message.isError
                        ? CupertinoIcons.exclamationmark_circle_fill
                        : CupertinoIcons.checkmark_circle_fill,
                    size: 15,
                    color: message.isError ? _kErrorColor : _kSuccessColor,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      message.text,
                      style: textTheme.bodySmall?.copyWith(
                        color: message.isError
                            ? _kErrorColor
                            : Colors.black.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
    required this.textTheme,
  });

  final String label;
  final bool busy;
  final Future<void> Function()? onPressed;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: kPrimaryColor.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white,
          elevation: enabled ? 2 : 0,
          shadowColor: kPrimaryColor.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}
