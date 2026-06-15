import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'main.dart';
import 'utils/search_utils.dart';

const Color _kPrimary = Color(0xFFA58CE3);
const Color _kSecondary = Color(0xFF5B3FA3);
const Color _kBg = Color(0xFFF4F1FB);

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  // Step 1 — credentials
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Step 2 — profile
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  String? _selectedGender;

  int _currentStep = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickDOB() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a password';
    if (value.length < 8) return 'At least 8 characters required';
    if (!RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#\$&*~]).{8,}$')
        .hasMatch(value)) {
      return 'Need: uppercase, lowercase, number & symbol';
    }
    return null;
  }

  void _goToStep2() {
    if (_step1Key.currentState?.validate() ?? false) {
      setState(() => _currentStep = 1);
    }
  }

  Future<void> _register() async {
    if (!(_step2Key.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final username = _usernameController.text.trim();
      final name = _nameController.text.trim();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'username': username,
        'username_lower': username.toLowerCase(),
        'name': name,
        'email': _emailController.text.trim(),
        'dob': _dobController.text.trim(),
        'gender': _selectedGender,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'searchTerms': buildSearchTerms(name: name, username: username),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Account created! Please sign in.'),
        ),
      );
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => LoginPage()));
    } on FirebaseAuthException catch (e) {
      String msg = 'Registration failed';
      if (e.code == 'email-already-in-use') msg = 'Email already registered';
      if (e.code == 'weak-password') msg = 'Password is too weak';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _field({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black45, fontSize: 14),
      prefixIcon: Icon(icon, color: _kSecondary, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF9F6FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _kPrimary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.red, width: 1.6),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    return Theme(
      data: Theme.of(context).copyWith(textTheme: tt),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF5EDFF), Color(0xFFE8E4FF), _kBg],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 28),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.97),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 32,
                          spreadRadius: -12,
                          offset: const Offset(0, 24),
                          color: Colors.black.withOpacity(0.08),
                        ),
                      ],
                      border: Border.all(
                          color: Colors.white.withOpacity(0.6), width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Halo.',
                          style: GoogleFonts.poppins(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: _kSecondary,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentStep == 0
                              ? 'Create your account'
                              : 'Your profile details',
                          style: tt.titleMedium?.copyWith(
                            color: Colors.grey.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Progress bar
                        Row(
                          children: [
                            _ProgressSegment(active: true),
                            const SizedBox(width: 8),
                            _ProgressSegment(active: _currentStep >= 1),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Step ${_currentStep + 1} of 2',
                                  style: tt.bodySmall?.copyWith(
                                      color: Colors.grey.shade500)),
                              Text(
                                  _currentStep == 0
                                      ? 'Credentials'
                                      : 'Profile',
                                  style: tt.bodySmall?.copyWith(
                                      color: _kSecondary,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: _currentStep == 0
                              ? _Step1(
                                  key: const ValueKey(0),
                                  formKey: _step1Key,
                                  emailCtrl: _emailController,
                                  passCtrl: _passwordController,
                                  confirmCtrl: _confirmPasswordController,
                                  obscurePass: _obscurePassword,
                                  obscureConfirm: _obscureConfirm,
                                  onTogglePass: () => setState(
                                      () => _obscurePassword =
                                          !_obscurePassword),
                                  onToggleConfirm: () => setState(
                                      () => _obscureConfirm =
                                          !_obscureConfirm),
                                  validatePass: _validatePassword,
                                  fieldDecor: _field,
                                  onNext: _goToStep2,
                                  tt: tt,
                                )
                              : _Step2(
                                  key: const ValueKey(1),
                                  formKey: _step2Key,
                                  usernameCtrl: _usernameController,
                                  nameCtrl: _nameController,
                                  dobCtrl: _dobController,
                                  selectedGender: _selectedGender,
                                  onGenderChanged: (v) =>
                                      setState(() => _selectedGender = v),
                                  onPickDOB: _pickDOB,
                                  fieldDecor: _field,
                                  onBack: () =>
                                      setState(() => _currentStep = 0),
                                  onSubmit: _register,
                                  isLoading: _isLoading,
                                  tt: tt,
                                ),
                        ),

                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account?  ',
                              style: tt.bodySmall
                                  ?.copyWith(color: Colors.grey.shade700),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => LoginPage()),
                              ),
                              child: Text(
                                'Sign in',
                                style: tt.bodySmall?.copyWith(
                                  color: _kSecondary,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressSegment extends StatelessWidget {
  final bool active;
  const _ProgressSegment({required this.active});
  @override
  Widget build(BuildContext context) => Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 4,
          decoration: BoxDecoration(
            color: active ? _kPrimary : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

// ---- Step 1: Credentials ----

class _Step1 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final bool obscurePass;
  final bool obscureConfirm;
  final VoidCallback onTogglePass;
  final VoidCallback onToggleConfirm;
  final FormFieldValidator<String> validatePass;
  final InputDecoration Function(
      {required String hint,
      required IconData icon,
      Widget? suffix}) fieldDecor;
  final VoidCallback onNext;
  final TextTheme tt;

  const _Step1({
    Key? key,
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.obscurePass,
    required this.obscureConfirm,
    required this.onTogglePass,
    required this.onToggleConfirm,
    required this.validatePass,
    required this.fieldDecor,
    required this.onNext,
    required this.tt,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Label('Email', tt),
          const SizedBox(height: 6),
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.black),
            decoration:
                fieldDecor(hint: 'you@example.com', icon: Icons.email_outlined),
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 16),
          _Label('Password', tt),
          const SizedBox(height: 6),
          TextFormField(
            controller: passCtrl,
            obscureText: obscurePass,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.black),
            decoration: fieldDecor(
              hint: 'Min 8 chars, uppercase, symbol',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                icon: Icon(
                    obscurePass
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20),
                onPressed: onTogglePass,
              ),
            ),
            validator: validatePass,
          ),
          const SizedBox(height: 16),
          _Label('Confirm Password', tt),
          const SizedBox(height: 6),
          TextFormField(
            controller: confirmCtrl,
            obscureText: obscureConfirm,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: Colors.black),
            decoration: fieldDecor(
              hint: 'Repeat your password',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                icon: Icon(
                    obscureConfirm
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20),
                onPressed: onToggleConfirm,
              ),
            ),
            validator: (v) =>
                v != passCtrl.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Next',
                      style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Step 2: Profile ----

class _Step2 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController usernameCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController dobCtrl;
  final String? selectedGender;
  final ValueChanged<String?> onGenderChanged;
  final VoidCallback onPickDOB;
  final InputDecoration Function(
      {required String hint,
      required IconData icon,
      Widget? suffix}) fieldDecor;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final bool isLoading;
  final TextTheme tt;

  const _Step2({
    Key? key,
    required this.formKey,
    required this.usernameCtrl,
    required this.nameCtrl,
    required this.dobCtrl,
    required this.selectedGender,
    required this.onGenderChanged,
    required this.onPickDOB,
    required this.fieldDecor,
    required this.onBack,
    required this.onSubmit,
    required this.isLoading,
    required this.tt,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onBack,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_rounded,
                    size: 16, color: _kSecondary),
                const SizedBox(width: 4),
                Text('Back',
                    style: tt.bodySmall?.copyWith(
                        color: _kSecondary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Label('Username', tt),
          const SizedBox(height: 6),
          TextFormField(
            controller: usernameCtrl,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.black),
            decoration: fieldDecor(
                hint: 'your_username',
                icon: Icons.alternate_email_rounded),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter a username' : null,
          ),
          const SizedBox(height: 16),
          _Label('Full Name', tt),
          const SizedBox(height: 6),
          TextFormField(
            controller: nameCtrl,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.black),
            decoration: fieldDecor(
                hint: 'Your full name',
                icon: Icons.person_outline_rounded),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
          ),
          const SizedBox(height: 16),
          _Label('Date of Birth', tt),
          const SizedBox(height: 6),
          TextFormField(
            controller: dobCtrl,
            readOnly: true,
            style: const TextStyle(color: Colors.black),
            decoration:
                fieldDecor(hint: 'Tap to select', icon: Icons.cake_outlined),
            onTap: onPickDOB,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Select your date of birth' : null,
          ),
          const SizedBox(height: 16),
          _Label('Gender', tt),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: selectedGender,
            style: const TextStyle(color: Colors.black),
            decoration:
                fieldDecor(hint: 'Select gender', icon: Icons.wc_rounded),
            items: ['Male', 'Female', 'Other']
                .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g,
                        style: const TextStyle(color: Colors.black))))
                .toList(),
            onChanged: onGenderChanged,
            validator: (v) => v == null ? 'Please select gender' : null,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kSecondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white)),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Create Account',
                            style: tt.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final TextTheme tt;
  const _Label(this.text, this.tt);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: tt.labelMedium
            ?.copyWith(fontWeight: FontWeight.w600, color: Colors.grey.shade800),
      );
}
