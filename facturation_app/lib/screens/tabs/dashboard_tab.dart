import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/calendar_event.dart';
import '../../providers/clients_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/invoices_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../utils/formatters.dart';
import '../../theme.dart';
import '../jobs_screen.dart';
import '../invoice_editor_screen.dart';

class DashboardTab extends ConsumerWidget {
  final void Function(int index) onNavigate;
  const DashboardTab({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);
    final products = ref.watch(productsProvider);
    final invoices = ref.watch(invoicesProvider);
    final jobs = ref.watch(jobsProvider);
    final events = ref.watch(eventsProvider);

    final clientCount = clients.value?.length ?? 0;
    final productCount = products.value?.length ?? 0;
    final invoiceCount = invoices.value?.length ?? 0;
    final jobCount = jobs.value?.length ?? 0;
    final lastInvoices = invoices.value?.take(3).toList() ?? [];

    final now = DateTime.now();
    final today = todayIso();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final todayJobs =
        (jobs.value ?? []).where((j) => j.date == today).toList();

    // Events for today and yesterday
    final relevantEvents = (events.value ?? [])
        .where((e) => e.date == today || e.date == yesterdayStr)
        .toList()
      ..sort((a, b) {
        final dateCmp = a.date.compareTo(b.date);
        if (dateCmp != 0) return -dateCmp; // today before yesterday
        return a.time.compareTo(b.time);
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Stats grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _StatCard(
              label: 'Clients',
              count: clientCount,
              icon: Icons.people,
              gradient: const [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
              onTap: () => onNavigate(1),
            ),
            _StatCard(
              label: 'Produits',
              count: productCount,
              icon: Icons.inventory_2,
              gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
              onTap: () => onNavigate(2),
            ),
            _StatCard(
              label: 'Factures',
              count: invoiceCount,
              icon: Icons.receipt,
              gradient: const [Color(0xFF6366F1), Color(0xFF818CF8)],
              onTap: () => onNavigate(3),
            ),
            _StatCard(
              label: 'Travaux',
              count: jobCount,
              icon: Icons.work,
              gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
              onTap: () => onNavigate(4),
            ),
          ],
        ),

        // ── Notes & events (today + yesterday) ──
        if (relevantEvents.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.notifications_outlined,
                          size: 18, color: Color(0xFF6366F1)),
                      const SizedBox(width: 8),
                      Text(
                        'Notes & rappels (${relevantEvents.length})',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: kSlate900),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    ...relevantEvents
                        .map((e) => _EventRow(event: e, now: now, today: today)),
                  ]),
            ),
          ),
        ],

        // ── Today's jobs ──
        if (todayJobs.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: kGreen, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Travaux d'aujourd'hui (${todayJobs.length})",
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: kSlate900),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    ...todayJobs.map((j) => InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => JobEditorScreen(job: j)),
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: kGreen.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: kGreen.withValues(alpha: 0.2)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.work_outline,
                                  color: kGreen, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(j.client,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                      if (j.service.isNotEmpty)
                                        Text(j.service,
                                            style: const TextStyle(
                                                color: kSlate500,
                                                fontSize: 12)),
                                    ]),
                              ),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${formatAmount2(j.price)} TND',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: kGreen,
                                            fontSize: 12)),
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _statusColor(j.status)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(j.status,
                                          style: TextStyle(
                                              color: _statusColor(j.status),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ]),
                            ]),
                          ),
                        )),
                  ]),
            ),
          ),
        ],
        const SizedBox(height: 16),

        // ── Last 3 invoices ──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.receipt_long, size: 18, color: kBlue),
                    SizedBox(width: 6),
                    Text('Dernières factures',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: kSlate900)),
                  ]),
                  const SizedBox(height: 12),
                  if (lastInvoices.isEmpty)
                    const Text('Aucune facture enregistrée.',
                        style: TextStyle(color: kSlate500))
                  else
                    ...lastInvoices.map((inv) => InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    InvoiceEditorScreen(invoice: inv)),
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: kBlue.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: kBlue.withValues(alpha: 0.15)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.receipt_outlined,
                                  color: kBlue, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'N° ${inv.number}  •  ${formatDate(inv.date)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                      Text(inv.clientName,
                                          style: const TextStyle(
                                              color: kSlate500, fontSize: 12),
                                          overflow: TextOverflow.ellipsis),
                                    ]),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${formatAmount(inv.total)} TND',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: kBlue,
                                            fontSize: 12)),
                                    const Icon(Icons.chevron_right,
                                        size: 16, color: kSlate500),
                                  ]),
                            ]),
                          ),
                        )),
                ]),
          ),
        ),
      ]),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Terminé':
        return kGreen;
      case 'En cours':
        return kBlue;
      case 'Annulé':
        return kRed;
      default:
        return const Color(0xFFF59E0B);
    }
  }
}

// ── Event row widget ──

class _EventRow extends StatelessWidget {
  final CalendarEvent event;
  final DateTime now;
  final String today;

  const _EventRow(
      {required this.event, required this.now, required this.today});

  bool get _isPast {
    if (event.date.compareTo(today) < 0) return true;
    if (event.time.isEmpty) return false;
    final parts = event.time.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final eventDt = DateTime(now.year, now.month, now.day, h, m);
    return now.isAfter(eventDt);
  }

  bool get _isYesterday => event.date.compareTo(today) < 0;

  String get _timeLabel {
    if (event.time.isEmpty) return '';
    if (_isPast) return event.time;
    // compute "in X h Ym"
    final parts = event.time.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final eventDt = DateTime(now.year, now.month, now.day, h, m);
    final diff = eventDt.difference(now);
    if (diff.inMinutes < 60) return 'dans ${diff.inMinutes} min';
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return mins == 0 ? 'dans ${hours}h' : 'dans ${hours}h${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    // Color scheme
    final Color bg;
    final Color border;
    final Color iconColor;
    final Color timeColor;

    if (_isYesterday || (_isPast && event.time.isNotEmpty)) {
      // Passed — amber/muted
      bg = const Color(0xFFFFF7ED);
      border = const Color(0xFFFED7AA);
      iconColor = const Color(0xFFEA580C);
      timeColor = const Color(0xFF9A3412);
    } else if (event.time.isNotEmpty) {
      // Upcoming with time — blue
      bg = const Color(0xFFEFF6FF);
      border = const Color(0xFFBFDBFE);
      iconColor = kBlue;
      timeColor = kBlue;
    } else {
      // Today, no time — neutral purple
      bg = const Color(0xFFF5F3FF);
      border = const Color(0xFFDDD6FE);
      iconColor = const Color(0xFF6366F1);
      timeColor = const Color(0xFF4338CA);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Icon(
          _isYesterday
              ? Icons.history_outlined
              : (event.time.isNotEmpty
                  ? Icons.alarm_outlined
                  : Icons.sticky_note_2_outlined),
          color: iconColor,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              event.title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _isPast ? const Color(0xFF6B7280) : kSlate900,
                  decoration: _isPast ? TextDecoration.lineThrough : null,
                  decorationColor: const Color(0xFF9CA3AF)),
            ),
            if (event.note.isNotEmpty)
              Text(event.note,
                  style: TextStyle(
                      color: _isPast
                          ? const Color(0xFF9CA3AF)
                          : kSlate500,
                      fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (_isYesterday)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFED7AA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Hier',
                  style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9A3412),
                      fontWeight: FontWeight.w600)),
            ),
          if (event.time.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.access_time, size: 11, color: timeColor),
              const SizedBox(width: 2),
              Text(
                event.time,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: timeColor),
              ),
            ]),
            if (!_isPast && _timeLabel.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(_timeLabel,
                  style: TextStyle(
                      fontSize: 10,
                      color: timeColor.withValues(alpha: 0.7))),
            ],
          ],
        ]),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon,
                  color: Colors.white.withValues(alpha: 0.85), size: 22),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                ),
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11)),
              ]),
            ],
          ),
        ),
      );
}
