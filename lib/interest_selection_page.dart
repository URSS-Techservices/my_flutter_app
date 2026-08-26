import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Light Halo theme (NO black background here)
const Color kPrimaryColor = Color(0xFFA58CE3);      // Lavender
const Color kSecondaryColor = Color(0xFF5B3FA3);    // Deep Purple
const Color kBackgroundColor = Color(0xFFF4F1FB);   // Light lavender-gray

class InterestSelectionPage extends StatefulWidget {
  final bool isFromSettings;

  const InterestSelectionPage({super.key, this.isFromSettings = false});

  @override
  State<InterestSelectionPage> createState() => _InterestSelectionPageState();
}

class _InterestSelectionPageState extends State<InterestSelectionPage> {
  final List<_Interest> _allInterests = const [
    _Interest(key: 'fitness', label: 'Fitness', icon: Icons.fitness_center),
    _Interest(key: 'yoga', label: 'Yoga', icon: Icons.self_improvement),
    _Interest(key: 'nutrition', label: 'Nutrition', icon: Icons.restaurant),
    _Interest(key: 'mental_health', label: 'Mental Health', icon: Icons.favorite),
    _Interest(key: 'productivity', label: 'Productivity', icon: Icons.timer),
    _Interest(key: 'music', label: 'Music', icon: Icons.music_note),
    _Interest(key: 'reading', label: 'Reading', icon: Icons.menu_book),
    _Interest(key: 'travel', label: 'Travel', icon: Icons.flight_takeoff),
  ];

  final Set<String> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('user_interests') ?? [];
    setState(() {
      _selected.addAll(existing);
      _loading = false;
    });
  }

  Future<void> _saveAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_interests', _selected.toList());
    await prefs.setBool('interests_completed', true);

    // Also persist to Firestore if a user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'interests': _selected.toList()}, SetOptions(merge: true));
      } catch (_) {
        // ignore write errors silently; local prefs still saved
      }
    }

    if (mounted) {
      if (widget.isFromSettings) {
        Navigator.pop(context);
      } else {
        Navigator.pop(context, true); // let caller route to home
      }
    }
  }

  Future<void> _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('interests_completed', true);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Light lavender background (not black)
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF5EDFF),
              Color(0xFFE8E4FF),
              kBackgroundColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              // Top AppBar-style row
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    if (Navigator.of(context).canPop())
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    if (!Navigator.of(context).canPop())
                      const SizedBox(width: 48),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Choose your interests',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2C244A),
                          ),
                        ),
                      ),
                    ),
                    if (!widget.isFromSettings)
                      TextButton(
                        onPressed: _skip,
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: kSecondaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pick 2–5 to personalize your feed',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5A5770),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Grid of interests
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    // more square & slightly smaller
                    childAspectRatio: 1.0,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                  ),
                  itemCount: _allInterests.length,
                  itemBuilder: (context, index) {
                    final interest = _allInterests[index];
                    final selected = _selected.contains(interest.key);
                    return _InterestTile(
                      interest: interest,
                      selected: selected,
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selected.remove(interest.key);
                          } else {
                            _selected.add(interest.key);
                          }
                        });
                      },
                    );
                  },
                ),
              ),

              // Continue button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveAndContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSecondaryColor,
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterestTile extends StatelessWidget {
  final _Interest interest;
  final bool selected;
  final VoidCallback onTap;

  const _InterestTile({
    required this.interest,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Slightly smaller internal padding than before
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? kSecondaryColor : Colors.white.withValues(alpha:0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? kSecondaryColor.withValues(alpha: 0.9)
                : Colors.deepPurple.withValues(alpha:0.15),
            width: 1.1,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              blurRadius: 16,
              spreadRadius: -4,
              offset: const Offset(0, 10),
              color: kSecondaryColor.withValues(alpha:0.35),
            ),
          ]
              : [
            BoxShadow(
              blurRadius: 10,
              spreadRadius: -6,
              offset: const Offset(0, 6),
              color: Colors.black.withValues(alpha:0.06),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              interest.icon,
              size: 30, // slightly smaller than before
              color: selected ? Colors.white : const Color(0xFF3B345C),
            ),
            const SizedBox(height: 10),
            Text(
              interest.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: selected ? Colors.white : const Color(0xFF27213F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Interest {
  final String key;
  final String label;
  final IconData icon;

  const _Interest({
    required this.key,
    required this.label,
    required this.icon,
  });
}
