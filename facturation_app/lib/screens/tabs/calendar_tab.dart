import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/calendar_event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../theme.dart';
import '../../utils/formatters.dart';
import '../jobs_screen.dart';

class CalendarTab extends ConsumerStatefulWidget {
  const CalendarTab({super.key});

  @override
  ConsumerState<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<CalendarTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider).value ?? [];
    final jobs = ref.watch(jobsProvider).value ?? [];

    final selStr = _fmt(_selectedDay);
    final selEvents = events.where((e) => e.date == selStr).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    final selJobs = jobs.where((j) => j.date == selStr).toList();

    return Scaffold(
      body: Column(children: [
        TableCalendar(
          firstDay: DateTime(2020),
          lastDay: DateTime(2030),
          focusedDay: _focusedDay,
          selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
          onDaySelected: (selected, focused) => setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          }),
          onPageChanged: (focused) => setState(() => _focusedDay = focused),
          eventLoader: (day) {
            final s = _fmt(day);
            return [
              if (events.any((e) => e.date == s)) 'event',
              if (jobs.any((j) => j.date == s)) 'job',
            ];
          },
          calendarStyle: CalendarStyle(
            markerDecoration:
                const BoxDecoration(color: kBlue, shape: BoxShape.circle),
            selectedDecoration:
                const BoxDecoration(color: kBlue, shape: BoxShape.circle),
            todayDecoration: BoxDecoration(
              color: kBlue.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            todayTextStyle:
                const TextStyle(color: kBlue, fontWeight: FontWeight.bold),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (ctx, day, markers) {
              if (markers.isEmpty) return const SizedBox.shrink();
              final s = _fmt(day);
              final hasEvent = events.any((e) => e.date == s);
              final hasJob = jobs.any((j) => j.date == s);
              return Positioned(
                bottom: 4,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (hasEvent)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: const BoxDecoration(
                          color: kBlue, shape: BoxShape.circle),
                    ),
                  if (hasJob)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: const BoxDecoration(
                          color: kGreen, shape: BoxShape.circle),
                    ),
                ]),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: selEvents.isEmpty && selJobs.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.event_note_outlined, size: 56, color: kSlate200),
                    const SizedBox(height: 8),
                    const Text('Aucun événement ce jour',
                        style: TextStyle(color: kSlate500)),
                  ]),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                  children: [
                    if (selJobs.isNotEmpty) ...[
                      _header('Travaux', kGreen, Icons.work_outline),
                      ...selJobs.map((j) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.work_outline,
                                  color: kGreen, size: 20),
                              title: Text(j.client,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: j.service.isNotEmpty
                                  ? Text(j.service)
                                  : null,
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(
                                  '${formatAmount2(j.price)} TND',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: kGreen,
                                      fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right,
                                    size: 16, color: kSlate500),
                              ]),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => JobEditorScreen(job: j)),
                              ),
                            ),
                          )),
                      const SizedBox(height: 8),
                    ],
                    if (selEvents.isNotEmpty) ...[
                      _header('Notes & Rappels', kBlue,
                          Icons.notifications_outlined),
                      ...selEvents.map((e) => _EventTile(
                            event: e,
                            onTap: () => _openForm(event: e),
                          )),
                    ],
                  ],
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
        onPressed: () => _openForm(),
      ),
    );
  }

  Widget _header(String label, Color color, IconData icon) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: color, fontSize: 13)),
        ]),
      );

  Future<void> _openForm({CalendarEvent? event}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EventForm(initialDate: _selectedDay, event: event),
    );
  }
}

// ─── Event tile ───────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onTap;

  const _EventTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kBlue.withValues(alpha: 0.1),
          child: Icon(
            event.time.isNotEmpty
                ? Icons.notifications_outlined
                : Icons.sticky_note_2_outlined,
            color: kBlue,
            size: 18,
          ),
        ),
        title: Text(event.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.time.isNotEmpty)
                Row(children: [
                  const Icon(Icons.access_time, size: 12, color: kBlue),
                  const SizedBox(width: 4),
                  Text(event.time,
                      style: const TextStyle(fontSize: 12, color: kBlue)),
                ]),
              if (event.note.isNotEmpty)
                Text(event.note,
                    style: const TextStyle(fontSize: 12, color: kSlate500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
            ]),
        isThreeLine: event.time.isNotEmpty && event.note.isNotEmpty,
        trailing: const Icon(Icons.edit_outlined, size: 16, color: kSlate500),
        onTap: onTap,
      ),
    );
  }
}

// ─── Event form (modal bottom sheet) ─────────────────────────────────────────

class _EventForm extends ConsumerStatefulWidget {
  final DateTime initialDate;
  final CalendarEvent? event;

  const _EventForm({required this.initialDate, this.event});

  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  TimeOfDay? _time;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e != null) {
      _titleCtrl.text = e.title;
      _noteCtrl.text = e.note;
      if (e.time.isNotEmpty) {
        final p = e.time.split(':');
        if (p.length == 2) {
          _time = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
        }
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String get _dateStr {
    final d = widget.initialDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String get _timeStr => _time == null
      ? ''
      : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le titre est obligatoire.')));
      return;
    }
    final userId = ref.read(currentUserIdProvider)!;
    setState(() => _saving = true);
    try {
      final event = CalendarEvent(
        id: widget.event?.id ?? '',
        userId: userId,
        title: _titleCtrl.text.trim(),
        note: _noteCtrl.text.trim(),
        date: _dateStr,
        time: _timeStr,
      );
      await ref.read(eventsServiceProvider).save(event, userId);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce rappel ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(eventsServiceProvider).delete(widget.event!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.event != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  isEdit ? 'Modifier le rappel' : 'Nouveau rappel',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              if (isEdit)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: kRed),
                  onPressed: _delete,
                ),
            ]),
            Text(
              formatDate(_dateStr),
              style: const TextStyle(color: kSlate500, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              autofocus: !isEdit,
              decoration: const InputDecoration(
                labelText: 'Titre *',
                prefixIcon: Icon(Icons.title, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note / Description',
                prefixIcon: Icon(Icons.notes_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time ?? TimeOfDay.now(),
                );
                if (picked != null) setState(() => _time = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Heure de rappel (optionnel)',
                  prefixIcon: Icon(Icons.alarm_outlined, size: 18),
                ),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      _time == null ? 'Pas de notification' : _timeStr,
                      style: TextStyle(
                          color: _time == null ? kSlate500 : kSlate900,
                          fontSize: 14),
                    ),
                  ),
                  if (_time != null)
                    GestureDetector(
                      onTap: () => setState(() => _time = null),
                      child: const Icon(Icons.close,
                          size: 16, color: kSlate500),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('Sauvegarder'),
                onPressed: _saving ? null : _save,
              ),
            ),
          ]),
    );
  }
}
