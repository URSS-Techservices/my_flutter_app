import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/core/halo_theme.dart';

Future<void> showTermsAndConditionsDialog(BuildContext context) {
  return _showLegalDialog(
    context,
    title: 'Terms & Conditions',
    body: _termsBody,
  );
}

Future<void> showPrivacyPolicyDialog(BuildContext context) {
  return _showLegalDialog(
    context,
    title: 'Privacy Policy',
    body: _privacyBody.replaceFirst(
      '{year}',
      DateTime.now().year.toString(),
    ),
  );
}

Future<void> _showLegalDialog(
  BuildContext context, {
  required String title,
  required String body,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final textTheme =
          GoogleFonts.poppinsTextTheme(Theme.of(dialogContext).textTheme);
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Text(body, style: textTheme.bodyMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Close',
              style: textTheme.labelLarge?.copyWith(
                color: kSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    },
  );
}

const String _termsBody =
    '''By using this application, you agree to the following terms and conditions:

1. Acceptance of Terms
   By accessing and using this app, you accept and agree to be bound by these terms and conditions.

2. User Account
   • You are responsible for maintaining the confidentiality of your account
   • You must provide accurate and complete information
   • You are responsible for all activities under your account

3. User Conduct
   • You agree not to use the app for any unlawful purpose
   • You will not post or transmit any harmful, offensive, or inappropriate content
   • You will respect other users' privacy and rights

4. Intellectual Property
   • All content in this app is protected by copyright and other intellectual property laws
   • You may not reproduce, distribute, or create derivative works without permission

5. Privacy
   • Your use of this app is also governed by our Privacy Policy
   • We collect and use your information as described in our Privacy Policy

6. Limitation of Liability
   • The app is provided "as is" without warranties of any kind
   • We are not liable for any damages arising from your use of the app

7. Changes to Terms
   • We reserve the right to modify these terms at any time
   • Continued use after changes constitutes acceptance

8. Termination
   • We may terminate or suspend your account at any time for violations of these terms

If you have any questions about these Terms & Conditions, please contact us.''';

const String _privacyBody =
    '''This Privacy Policy describes how we collect, use, and protect your personal information.

1. Information We Collect
   • Account information (username, email, phone number)
   • Profile information (name, bio, photos)
   • Usage data and app activity
   • Device information and location data

2. How We Use Your Information
   • To provide and improve our services
   • To communicate with you
   • To personalize your experience
   • To ensure app security and prevent fraud

3. Information Sharing
   • We do not sell your personal information
   • We may share information with service providers
   • We may disclose information if required by law

4. Data Security
   • We implement security measures to protect your data
   • However, no method of transmission is 100% secure
   • You use the app at your own risk

5. Your Rights
   • You can access and update your personal information
   • You can request deletion of your account
   • You can opt-out of certain communications

6. Cookies and Tracking
   • We use cookies and similar technologies
   • You can manage cookie preferences in your device settings

7. Children's Privacy
   • Our app is not intended for users under 13 years of age
   • We do not knowingly collect information from children

8. Changes to Privacy Policy
   • We may update this policy from time to time
   • We will notify you of significant changes

9. Contact Us
   • If you have questions about this Privacy Policy, please contact us

Last updated: {year}''';
