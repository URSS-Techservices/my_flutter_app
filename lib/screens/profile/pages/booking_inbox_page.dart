import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/services/booking_requests_service.dart';

/// Full-screen inbox for guru / wellness owners to manage booking requests.
class BookingInboxPage extends StatefulWidget {
  final String providerId;
  final BookingProviderKind providerKind;

  const BookingInboxPage({
    super.key,
    required this.providerId,
    required this.providerKind,
  });

  @override
  State<BookingInboxPage> createState() => _BookingInboxPageState();
}

class _BookingInboxPageState extends State<BookingInboxPage>
    with SingleTickerProviderStateMixin {
  final _service = BookingRequestsService();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(
    List<Map<String, dynamic>> all,
    int tabIndex,
  ) {
    switch (tabIndex) {
      case 0:
        return all.where(BookingRequestsService.isPending).toList();
      case 1:
        return all.where(BookingRequestsService.isAccepted).toList();
      default:
        return all.where((r) {
          final s = r['status']?.toString() ?? '';
          return s == BookingRequestsService.statusDeclined ||
              s == BookingRequestsService.statusCancelled ||
              s == 'rejected';
        }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.providerKind == BookingProviderKind.guru
        ? 'Session Requests'
        : 'Booking Requests';

    return Scaffold(
      backgroundColor: ProfileLayout.bg,
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: ProfileLayout.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: ProfileLayout.deepLavender,
          unselectedLabelColor: ProfileLayout.textSecondary,
          indicatorColor: ProfileLayout.deepLavender,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'Closed'),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _service.providerRequestsStream(
          providerId: widget.providerId,
          kind: widget.providerKind,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data ?? const [];

          return TabBarView(
            controller: _tabController,
            children: List.generate(3, (tabIndex) {
              final items = _filter(all, tabIndex);
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    tabIndex == 0
                        ? 'No pending requests'
                        : tabIndex == 1
                            ? 'No accepted bookings'
                            : 'No closed requests',
                    style: GoogleFonts.poppins(color: ProfileLayout.textSecondary),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _InboxTile(
                    request: items[index],
                    service: _service,
                    canRespond: tabIndex == 0,
                  );
                },
              );
            }),
          );
        },
      ),
    );
  }
}

class _InboxTile extends StatefulWidget {
  final Map<String, dynamic> request;
  final BookingRequestsService service;
  final bool canRespond;

  const _InboxTile({
    required this.request,
    required this.service,
    required this.canRespond,
  });

  @override
  State<_InboxTile> createState() => _InboxTileState();
}

class _InboxTileState extends State<_InboxTile> {
  String _requesterName = 'Client';
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final userId = widget.request['userId']?.toString() ?? '';
    final name = await widget.service.fetchUserDisplayName(userId);
    if (mounted) setState(() => _requesterName = name);
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

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final status = request['status']?.toString() ?? BookingRequestsService.statusPending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: ProfileLayout.chipBg,
                  child: Text(
                    _requesterName.isNotEmpty ? _requesterName[0].toUpperCase() : '?',
                    style: GoogleFonts.poppins(color: ProfileLayout.deepLavender),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_requesterName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      Text(
                        BookingRequestsService.displayService(request),
                        style: GoogleFonts.poppins(fontSize: 12, color: ProfileLayout.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: ProfileLayout.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: ProfileLayout.deepLavender),
                const SizedBox(width: 6),
                Text(
                  BookingRequestsService.displayWhen(request),
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ],
            ),
            if (request['note']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(request['note'].toString(), style: GoogleFonts.poppins(fontSize: 13)),
            ],
            if (widget.canRespond) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
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
      ),
    );
  }
}
