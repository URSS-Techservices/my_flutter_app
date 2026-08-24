import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/services/guru_programs_service.dart';

/// Owner UI to manage unified guru programs, products, and class batches.
class GuruProgramsEditorPage extends StatefulWidget {
  final String guruUserId;
  final GuruProgramType initialTab;

  const GuruProgramsEditorPage({
    super.key,
    required this.guruUserId,
    this.initialTab = GuruProgramType.program,
  });

  @override
  State<GuruProgramsEditorPage> createState() => _GuruProgramsEditorPageState();
}

class _GuruProgramsEditorPageState extends State<GuruProgramsEditorPage> {
  final _service = GuruProgramsService();
  late GuruProgramType _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final durationCtrl = TextEditingController(text: existing?['duration']?.toString() ?? '');
    final scheduleCtrl = TextEditingController(text: existing?['schedule']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: '${existing?['price'] ?? 0}');
    final capacityCtrl = TextEditingController(text: '${existing?['capacity'] ?? 0}');
    final descCtrl = TextEditingController(text: existing?['description']?.toString() ?? '');
    final tagCtrl = TextEditingController(text: existing?['tag']?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit' : 'Add ${_label(_tab)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              if (_tab == GuruProgramType.classBatch)
                TextField(
                  controller: scheduleCtrl,
                  decoration: const InputDecoration(labelText: 'Schedule', border: OutlineInputBorder()),
                )
              else
                TextField(
                  controller: durationCtrl,
                  decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: 'Price (₹)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              if (_tab == GuruProgramType.classBatch) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: capacityCtrl,
                  decoration: const InputDecoration(labelText: 'Capacity', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ],
              if (_tab == GuruProgramType.product) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: tagCtrl,
                  decoration: const InputDecoration(labelText: 'Tag (e.g. Best Seller)', border: OutlineInputBorder()),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEdit ? 'Save' : 'Add')),
        ],
      ),
    );

    if (saved != true || nameCtrl.text.trim().isEmpty) return;

    await _service.upsert(
      guruId: widget.guruUserId,
      programId: existing?['id']?.toString(),
      type: _tab,
      name: nameCtrl.text.trim(),
      duration: durationCtrl.text.trim(),
      schedule: scheduleCtrl.text.trim(),
      price: int.tryParse(priceCtrl.text.trim()) ?? 0,
      capacity: int.tryParse(capacityCtrl.text.trim()) ?? 0,
      description: descCtrl.text.trim(),
      tag: tagCtrl.text.trim().isEmpty ? null : tagCtrl.text.trim(),
    );
  }

  Future<void> _delete(String programId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove item?'),
        content: const Text('This will hide the item from your profile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) {
      await _service.delete(guruId: widget.guruUserId, programId: programId);
    }
  }

  String _label(GuruProgramType type) {
    switch (type) {
      case GuruProgramType.program:
        return 'Program';
      case GuruProgramType.product:
        return 'Product';
      case GuruProgramType.classBatch:
        return 'Class Batch';
    }
  }

  List<Map<String, dynamic>> _filter(GuruProgramsLoadResult data) {
    switch (_tab) {
      case GuruProgramType.program:
        return data.programs;
      case GuruProgramType.product:
        return data.products;
      case GuruProgramType.classBatch:
        return data.classes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileLayout.bg,
      appBar: AppBar(
        title: Text('Manage Offerings', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: ProfileLayout.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<GuruProgramType>(
              segments: const [
                ButtonSegment(value: GuruProgramType.program, label: Text('Programs')),
                ButtonSegment(value: GuruProgramType.product, label: Text('Products')),
                ButtonSegment(value: GuruProgramType.classBatch, label: Text('Classes')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Expanded(
            child: StreamBuilder<GuruProgramsLoadResult>(
              stream: _service.stream(widget.guruUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = _filter(snapshot.data ?? const GuruProgramsLoadResult(all: []));
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'No ${_label(_tab).toLowerCase()}s yet',
                      style: GoogleFonts.poppins(color: ProfileLayout.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final subtitle = _tab == GuruProgramType.classBatch
                        ? item['schedule']?.toString() ?? ''
                        : item['duration']?.toString() ?? '';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(item['name']?.toString() ?? ''),
                        subtitle: Text('${subtitle.isNotEmpty ? '$subtitle • ' : ''}₹${item['price'] ?? 0}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _openEditor(existing: item),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                              onPressed: () => _delete(item['id']?.toString() ?? ''),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: ProfileLayout.deepLavender,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Add ${_label(_tab)}'),
      ),
    );
  }
}
