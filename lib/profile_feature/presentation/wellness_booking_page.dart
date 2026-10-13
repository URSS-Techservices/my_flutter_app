import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/profile_feature/domain/wellness_booking.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';
import 'package:intl/intl.dart';

/// "Book" from a wellness profile: a short request form (service, date,
/// time, note) and, below it, only MY earlier requests to this place.
/// The owner accepts or rejects requests from their own booking screen.
class WellnessBookingPage extends ConsumerStatefulWidget {
  const WellnessBookingPage({
    super.key,
    required this.wellnessId,
    required this.wellnessName,
  });

  final String wellnessId;
  final String wellnessName;

  @override
  ConsumerState<WellnessBookingPage> createState() =>
      _WellnessBookingPageState();
}

class _WellnessBookingPageState extends ConsumerState<WellnessBookingPage> {
  final _service = TextEditingController();
  final _note = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  bool _sending = false;

  static final _dateFormat = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    _service.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _service.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_sending &&
      _service.text.trim().isNotEmpty &&
      _date != null &&
      _time != null;

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _send() async {
    final myId = ref.read(myUserIdProvider);
    if (myId == null || !_canSend) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await ref.read(profileRepositoryProvider).requestWellnessBooking(
            wellnessId: widget.wellnessId,
            myId: myId,
            service: _service.text.trim(),
            preferredDate: _dateFormat.format(_date!),
            preferredTime: _time!.format(context),
            note: _note.text.trim(),
          );
      if (!mounted) return;
      _service.clear();
      _note.clear();
      setState(() {
        _date = null;
        _time = null;
      });
      HaloToast.success('Booking request sent');
    } catch (_) {
      HaloToast.error('Could not send request. Try again');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _cancel(WellnessBooking booking) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Cancel request?'),
        content: Text('Your request for ${booking.service} will be cancelled.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(profileRepositoryProvider).cancelWellnessBooking(booking.id);
      HaloToast.show('Request cancelled');
    } catch (_) {
      HaloToast.error('Could not cancel. Try again');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myWellnessBookingsProvider(widget.wellnessId));

    return Scaffold(
      backgroundColor: ProfileStyle.page,
      appBar: AppBar(
        backgroundColor: ProfileStyle.page,
        surfaceTintColor: ProfileStyle.page,
        title: Text(
          widget.wellnessName.isEmpty
              ? 'Book a service'
              : 'Book at ${widget.wellnessName}',
          style: ProfileStyle.name.copyWith(fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              ProfileStyle.sideGap, 8, ProfileStyle.sideGap, 32),
          children: [
            _Field(
              controller: _service,
              hint: 'Service (e.g. Yoga class, Massage)',
              icon: Icons.spa_outlined,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.calendar_today_outlined,
                    text: _date == null ? 'Date' : _dateFormat.format(_date!),
                    filled: _date != null,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.schedule_outlined,
                    text: _time == null ? 'Time' : _time!.format(context),
                    filled: _time != null,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Field(
              controller: _note,
              hint: 'Note for them (optional)',
              icon: Icons.notes_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _canSend ? _send : null,
                style: FilledButton.styleFrom(
                  backgroundColor: ProfileStyle.action,
                  disabledBackgroundColor: ProfileStyle.surface,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: ProfileStyle.mutedText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _sending
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : Text('Send Request', style: ProfileStyle.button),
              ),
            ),
            const SizedBox(height: 28),
            Text('Your requests',
                style: ProfileStyle.name.copyWith(fontSize: 17)),
            const SizedBox(height: 10),
            mine.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CupertinoActivityIndicator()),
              ),
              error: (_, __) => Text('Could not load your requests',
                  style: ProfileStyle.small),
              data: (list) => list.isEmpty
                  ? Text('No requests yet', style: ProfileStyle.small)
                  : Column(
                      children: [
                        for (final b in list)
                          _BookingTile(
                            booking: b,
                            onCancel:
                                b.status == 'pending' ? () => _cancel(b) : null,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      style: ProfileStyle.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: ProfileStyle.small.copyWith(fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: ProfileStyle.mutedText),
        filled: true,
        fillColor: ProfileStyle.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.text,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ProfileStyle.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: ProfileStyle.mutedText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: filled
                      ? ProfileStyle.body
                      : ProfileStyle.small.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking, this.onCancel});

  final WellnessBooking booking;
  final VoidCallback? onCancel;

  static const _green = Color(0xFF16A34A);
  static const _red = Color(0xFFDC2626);

  (String, Color) get _status => switch (booking.status) {
        'accepted' => ('Accepted', _green),
        'rejected' => ('Declined', _red),
        'cancelled' => ('Cancelled', ProfileStyle.mutedText),
        _ => ('Pending', ProfileStyle.action),
      };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _status;
    final when = [booking.preferredDate, booking.preferredTime]
        .where((s) => s.isNotEmpty)
        .join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: ProfileStyle.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.service.isEmpty ? 'Service' : booking.service,
                  style: ProfileStyle.body.copyWith(fontWeight: FontWeight.w600),
                ),
                if (when.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(when, style: ProfileStyle.small),
                ],
                if (booking.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(booking.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileStyle.small),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: ProfileStyle.small.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              if (onCancel != null)
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: _red,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.only(top: 6),
                    minimumSize: Size.zero,
                  ),
                  child: Text('Cancel',
                      style: ProfileStyle.small.copyWith(color: _red)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
