import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_router_screen.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/services/booking_requests_service.dart';

/// Full list of an aspirant's booking requests with cancel support.
class AspirantMyBookingsPage extends StatefulWidget {
  final String aspirantUserId;

  const AspirantMyBookingsPage({super.key, required this.aspirantUserId});

  @override
  State<AspirantMyBookingsPage> createState() => _AspirantMyBookingsPageState();
}

class _AspirantMyBookingsPageState extends State<AspirantMyBookingsPage>
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

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> all, int tab) {
    switch (tab) {
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
    return Scaffold(
      backgroundColor: ProfileLayout.bg,
      appBar: AppBar(
        title: Text('My Bookings', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
            Tab(text: 'Confirmed'),
            Tab(text: 'Closed'),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _service.requesterRequestsStream(widget.aspirantUserId),
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
                            ? 'No confirmed bookings'
                            : 'No closed bookings',
                    style: GoogleFonts.poppins(color: ProfileLayout.textSecondary),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _RequesterBookingTile(
                    request: items[index],
                    service: _service,
                    canCancel: tabIndex == 0,
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

class _RequesterBookingTile extends StatefulWidget {
  final Map<String, dynamic> request;
  final BookingRequestsService service;
  final bool canCancel;

  const _RequesterBookingTile({
    required this.request,
    required this.service,
    required this.canCancel,
  });

  @override
  State<_RequesterBookingTile> createState() => _RequesterBookingTileState();
}

class _RequesterBookingTileState extends State<_RequesterBookingTile> {
  BookingProviderInfo _provider = const BookingProviderInfo(name: 'Provider');
  bool _loading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await widget.service.resolveProvider(widget.request);
    if (mounted) {
      setState(() {
        _provider = info;
        _loading = false;
      });
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel request?'),
        content: const Text('The coach or facility will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel booking')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _updating = true);
    try {
      await widget.service.cancel(widget.request['id']?.toString() ?? '');
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
                Expanded(
                  child: InkWell(
                    onTap: _provider.userId == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProfileRouterScreen(profileUserId: _provider.userId!),
                              ),
                            ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loading ? 'Loading…' : _provider.name,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        if (_provider.kindLabel.isNotEmpty)
                          Text(
                            _provider.kindLabel,
                            style: GoogleFonts.poppins(fontSize: 11, color: ProfileLayout.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
                Text(status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              BookingRequestsService.displayService(request),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: ProfileLayout.deepLavender),
                const SizedBox(width: 6),
                Text(BookingRequestsService.displayWhen(request)),
              ],
            ),
            if (request['note']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(request['note'].toString(), style: GoogleFonts.poppins(fontSize: 13)),
            ],
            if (widget.canCancel) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: _updating ? null : _cancel,
                  child: _updating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Cancel request'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
