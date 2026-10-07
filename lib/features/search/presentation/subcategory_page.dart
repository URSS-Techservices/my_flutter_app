import 'package:flutter/material.dart';
import 'package:halo/features/search/presentation/search_responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/features/search/domain/search_models.dart';
import 'package:halo/features/search/presentation/experts_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SUBCATEGORY PAGE
// Lists all subcategories for a chosen wellness category.
// ─────────────────────────────────────────────────────────────────────────────

class SubCategoryPage extends StatelessWidget {
  final WellnessCategory category;
  const SubCategoryPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final specs = category.subcategorySpecs;

    return Scaffold(
      backgroundColor: kSearchBackground,
      appBar: AppBar(
        title: Text(
          category.name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: context.sp(16),
            color: const Color(0xFF1F1033),
          ),
        ),
        backgroundColor: category.backgroundColor,
        foregroundColor: const Color(0xFF1F1033),
        elevation: 0,
      ),
      body: ResponsiveCenter(
          child: specs.isEmpty
              ? Center(
                  child: Text(
                    'No subcategories for this category.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(context.s(16)),
                  itemCount: specs.length,
                  separatorBuilder: (_, __) => SizedBox(height: context.s(10)),
                  itemBuilder: (context, index) {
                    final spec = specs[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(context.s(18)),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 6,
                            spreadRadius: -2,
                            offset: const Offset(0, 2),
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: context.s(16), vertical: context.s(4)),
                        leading: Container(
                          padding: EdgeInsets.all(context.s(8)),
                          decoration: BoxDecoration(
                            color: category.backgroundColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(spec.emoji,
                              style: TextStyle(fontSize: context.sp(18))),
                        ),
                        title: Text(
                          spec.displayName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: context.sp(14),
                            color: const Color(0xFF1F1033),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: kSearchSecondary),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExpertsPage(spec: spec),
                          ),
                        ),
                      ),
                    );
                  },
                )),
    );
  }
}
