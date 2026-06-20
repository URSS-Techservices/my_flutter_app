import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/pages/aspirant_my_bookings_page.dart';
import 'package:halo/screens/profile/profile_router_screen.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/common/profile_empty_state.dart';
import 'package:halo/services/booking_requests_service.dart';

/// Aspirant's own coaching / wellness booking requests.
class AspirantMyBookingsSection extends StatelessWidget {
  final String aspirantUserId;
  final bool isOwnProfile;

  const AspirantMyBookingsSection({
    super.key,
    required this.aspirantUserId,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwnProfile) return const SizedBox.shrink();

    final service = BookingRequestsService();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available_outlined, color: ProfileLayout.deepLavender),
              const SizedBox(width: 8),
              Text(
                'My Bookings',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AspirantMyBookingsPage(aspirantUserId: aspirantUserId),
                    ),
                  );
                },
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Sessions and visits you requested',
            style: GoogleFonts.poppins(fontSize: 12, color: ProfileLayout.textSecondary),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: service.requesterRequestsStream(aspirantUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }

              final all = snapshot.data ?? const [];
              final active = all
                  .where((r) =>
                      BookingRequestsService.isPending(r) ||
                      BookingRequestsService.isAccepted(r))
                  .take(3)
                  .toList();

              if (active.isEmpty) {
                return const ProfileEmptyState(
                  text: 'Book a coach or wellness spot from their profile — your requests show up here.',
                  card: true,
                );
              }

              return Column(
                children: active.map((request) {
                  return _BookingPreviewTile(request: request, service: service);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BookingPreviewTile extends StatefulWidget {
  final Map<String, dynamic> request;
  final BookingRequestsService service;

  const _BookingPreviewTile({required this.request, required this.service});

  @override
  State<_BookingPreviewTile> createState() => _BookingPreviewTileState();
}

class _BookingPreviewTileState extends State<_BookingPreviewTile> {
  String _providerName = 'Provider';
  String? _providerId;

  @override
  void initState() {
    super.initState();
    _loadProvider();
  }

  Future<void> _loadProvider() async {
    final info = await widget.service.resolveProvider(widget.request);
    if (mounted) {
      setState(() {
        _providerName = info.name;
        _providerId = info.userId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final status = request['status']?.toString() ?? BookingRequestsService.statusPending;

    return InkWell(
      onTap: _providerId == null
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileRouterScreen(profileUserId: _providerId!),
                ),
              ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_providerName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  Text(
                    BookingRequestsService.displayService(request),
                    style: GoogleFonts.poppins(fontSize: 12, color: ProfileLayout.textSecondary),
                  ),
                  Text(
                    BookingRequestsService.displayWhen(request),
                    style: GoogleFonts.poppins(fontSize: 11, color: ProfileLayout.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ProfileLayout.chipBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase(),
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
