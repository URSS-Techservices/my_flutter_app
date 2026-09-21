// ─────────────────────────────────────────────────────────────────────────────
// SEARCH PAGE — Entry point (Bottom Navigation)
//
// This file re-exports the refactored SearchPage from the clean architecture
// feature module. All logic, state, and UI now live in:
//   lib/features/search/
//     ├── data/         → Firestore + SharedPreferences
//     ├── domain/       → Pure Dart models, contracts, use-cases
//     └── presentation/ → Riverpod providers, state, UI widgets
//
// The bottom nav bar references 'SearchPage' — this export keeps it working
// without any changes needed in the nav or home_page.dart.
// ─────────────────────────────────────────────────────────────────────────────

export 'package:halo/features/search/presentation/search_page.dart';

// Sub-pages are also exported so any existing Navigator.push() calls
// referencing SubCategoryPage or ExpertsListPage continue to work.
export 'package:halo/features/search/presentation/subcategory_page.dart';
export 'package:halo/features/search/presentation/experts_page.dart' show ExpertsPage;

// Domain models exported for any widget that still references WellnessCategory
// (e.g. category detail pages, deep links, tests)
export 'package:halo/features/search/domain/search_models.dart';