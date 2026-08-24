import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/pages/booking_inbox_page.dart';
import 'package:halo/services/booking_requests_service.dart';

/// Compact booking request list with accept/decline for profile business tabs.
class BookingInboxSection extends StatelessWidget {
  final String providerId;
  final BookingProviderKind providerKind;
  final bool isOwner;
  final int previewLimit;

  const BookingInboxSection({
    super.key,
    required this.providerId,
    required this.providerKind,
    required this.isOwner,
    this.previewLimit = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwner) return const SizedBox.shrink();

    final service = BookingRequestsService();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Booking Inbox',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingInboxPage(
                        providerId: providerId,
                        providerKind: providerKind,
                      ),
                    ),
                  );
                },
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: service.providerRequestsStream(
              providerId: providerId,
              kind: providerKind,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final all = snapshot.data ?? const [];
              final pending = all.where(BookingRequestsService.isPending).toList();
              final preview = pending.isNotEmpty
                  ? pending.take(previewLimit).toList()
                  : all.take(previewLimit).toList();

              if (preview.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'No booking requests yet. Share your profile so clients can book open slots.',
                    style: GoogleFonts.poppins(fontSize: 13, color: ProfileLayout.textSecondary),
                  ),
                );
              }

              return Column(
                children: preview.map((request) {
                  return _BookingRequestTile(
                    request: request,
                    showActions: BookingRequestsService.isPending(request),
                    service: service,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BookingRequestTile extends StatefulWidget {
  final Map<String, dynamic> request;
  final bool showActions;
  final BookingRequestsService service;

  const _BookingRequestTile({
    required this.request,
    required this.showActions,
    required this.service,
  });

  @override
  State<_BookingRequestTile> createState() => _BookingRequestTileState();
}

class _BookingRequestTileState extends State<_BookingRequestTile> {
  String _requesterName = 'Client';
  bool _loadingName = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final userId = widget.request['userId']?.toString() ?? '';
    final name = await widget.service.fetchUserDisplayName(userId);
    if (mounted) setState(() {
      _requesterName = name;
      _loadingName = false;
    });
  }

  Future<void> _respond(String status) async {
    setState(() => _updating = true);
    try {
      await widget.service.updateStatus(
        requestId: widget.request['id']?.toString() ?? '',
        status: status,
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case BookingRequestsService.statusAccepted:
        return Colors.green.shade100;
      case BookingRequestsService.statusDeclined:
        return Colors.red.shade100;
      case BookingRequestsService.statusCancelled:
        return Colors.grey.shade200;
      default:
        return Colors.orange.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final status = request['status']?.toString() ?? BookingRequestsService.statusPending;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _loadingName ? 'Loading…' : _requesterName,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            BookingRequestsService.displayService(request),
            style: GoogleFonts.poppins(fontSize: 13, color: ProfileLayout.textSecondary),
          ),
          Text(
            BookingRequestsService.displayWhen(request),
            style: GoogleFonts.poppins(fontSize: 12, color: ProfileLayout.textSecondary),
          ),
          if (request['note']?.toString().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              request['note'].toString(),
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ],
          if (widget.showActions) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _updating
                      ? null
                      : () => _respond(BookingRequestsService.statusDeclined),
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _updating
                      ? null
                      : () => _respond(BookingRequestsService.statusAccepted),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ProfileLayout.deepLavender,
                    foregroundColor: Colors.white,
                  ),
                  child: _updating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Accept'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
