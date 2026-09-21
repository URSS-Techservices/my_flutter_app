import 'package:flutter/material.dart';
import 'package:halo/features/search/presentation/search_responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/features/search/domain/category_feed.dart';
import 'package:halo/features/search/domain/search_models.dart';
import 'package:halo/features/search/presentation/search_providers.dart';
import 'package:halo/features/search/presentation/search_results.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EXPERTS PAGE
// People for one subcategory. Tabs = profile type (Gurus / Wellness /
// Aspirants); inside each tab, sections: people you know → matching interests
// → popular → new → nearby → more. Ranking lives in domain/category_feed.dart.
// ─────────────────────────────────────────────────────────────────────────────

const _tabs = <({String type, String label})>[
  (type: 'guru', label: 'Gurus'),
  (type: 'wellness', label: 'Wellness'),
  (type: 'aspirant', label: 'Aspirants'),
];

class ExpertsPage extends ConsumerWidget {
  final SubcategorySpec spec;

  const ExpertsPage({super.key, required this.spec});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(categoryFeedProvider(spec));

    return Scaffold(
      backgroundColor: kSearchBackground,
      appBar: AppBar(
        title: Text(
          spec.displayName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: context.sp(16),
            color: const Color(0xFF1F1033),
          ),
        ),
        backgroundColor: kSearchBackground,
        foregroundColor: const Color(0xFF1F1033),
        elevation: 0,
      ),
      body: ResponsiveCenter(
        child: feed.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: kSearchSecondary),
          ),
          error: (_, __) => _RetryMessage(
            icon: Icons.error_outline,
            text: 'Unable to load. Pull down to retry.',
            onRefresh: () => ref.refresh(categoryFeedProvider(spec).future),
          ),
          data: (data) => data.isEmpty
              ? _RetryMessage(
                  text: 'No people found for "${spec.displayName}" yet.',
                  onRefresh: () =>
                      ref.refresh(categoryFeedProvider(spec).future),
                )
              : _FeedTabs(
                  feed: data,
                  onRefresh: () =>
                      ref.refresh(categoryFeedProvider(spec).future),
                ),
        ),
      ),
    );
  }
}

class _FeedTabs extends StatelessWidget {
  final CategoryFeed feed;
  final Future<void> Function() onRefresh;

  const _FeedTabs({required this.feed, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    // Open on the first tab that actually has people.
    final firstWithPeople = _tabs
        .indexWhere((t) => feed.countFor(t.type) > 0)
        .clamp(0, _tabs.length - 1);

    return DefaultTabController(
      length: _tabs.length,
      initialIndex: firstWithPeople,
      child: Column(
        children: [
          TabBar(
            labelColor: kSearchSecondary,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: kSearchSecondary,
            labelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: context.sp(13)),
            tabs: [
              for (final t in _tabs)
                Tab(text: '${t.label} (${feed.countFor(t.type)})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final t in _tabs)
                  _SectionedList(
                    sections: feed.sectionsFor(t.type),
                    emptyText: 'No ${t.label.toLowerCase()} here yet.',
                    onRefresh: onRefresh,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionedList extends StatelessWidget {
  final List<FeedSection> sections;
  final String emptyText;
  final Future<void> Function() onRefresh;

  const _SectionedList({
    required this.sections,
    required this.emptyText,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return _RetryMessage(text: emptyText, onRefresh: onRefresh);
    }

    // Flatten to one list so only visible rows are built.
    final rows = <Object>[
      for (final s in sections) ...[s, ...s.users],
    ];

    return RefreshIndicator(
      color: kSearchSecondary,
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: context.s(24)),
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final row = rows[i];
          if (row is FeedSection) return _SectionHeader(row.title);
          return UserResultCard(
            key: ValueKey((row as UserResult).userId),
            user: row,
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          context.s(16), context.s(18), context.s(16), context.s(6)),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: context.sp(15),
          color: const Color(0xFF1F1033),
        ),
      ),
    );
  }
}

/// Scrollable message so pull-to-refresh works on empty and error states.
class _RetryMessage extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Future<void> Function() onRefresh;

  const _RetryMessage({this.icon, required this.text, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: kSearchSecondary,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(context.s(32)),
        children: [
          if (icon != null) ...[
            Icon(icon, size: context.s(48), color: Colors.grey.shade400),
            SizedBox(height: context.s(12)),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
