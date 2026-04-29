import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/worker_profile.dart';
import '../../models/job_request.dart';
import '../../providers/marketplace_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/role_provider.dart';
import '../worker_detail_screen.dart';
import '../worker_registration_screen.dart';

class MarketplaceTab extends ConsumerStatefulWidget {
  const MarketplaceTab({super.key});

  @override
  ConsumerState<MarketplaceTab> createState() => _MarketplaceTabState();
}

class _MarketplaceTabState extends ConsumerState<MarketplaceTab>
    with TickerProviderStateMixin {
  TabController? _tabCtrl;
  String _serviceFilter = 'Tous';
  bool? _wasClient;

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  TabController _getController(bool isClient) {
    final tabCount = isClient ? 2 : 3;
    if (_wasClient != isClient) {
      _tabCtrl?.dispose();
      _tabCtrl = TabController(length: tabCount, vsync: this);
      _wasClient = isClient;
    }
    return _tabCtrl!;
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider).value ?? 'worker';
    final isClient = role == 'client';
    final ctrl = _getController(isClient);

    return Column(
      children: [
        TabBar(
          controller: ctrl,
          tabs: [
            const Tab(text: 'Artisans'),
            const Tab(text: 'Mes demandes'),
            if (!isClient) const Tab(text: 'Reçues'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: ctrl,
            children: [
              _WorkerListView(
                  serviceFilter: _serviceFilter,
                  isClient: isClient,
                  onFilterChanged: (f) => setState(() => _serviceFilter = f)),
              const _SentRequestsView(),
              if (!isClient) const _ReceivedRequestsView(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Worker List ─────────────────────────────────────────────────────────────

class _WorkerListView extends ConsumerWidget {
  final String serviceFilter;
  final bool isClient;
  final ValueChanged<String> onFilterChanged;

  const _WorkerListView(
      {required this.serviceFilter,
      required this.isClient,
      required this.onFilterChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workers = ref.watch(workersProvider);
    final myProfile = ref.watch(myWorkerProfileProvider).value;
    final myId = ref.watch(currentUserIdProvider) ?? '';

    return Column(
      children: [
        // Service filter chips
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: ['Tous', ...WorkerProfile.allServices].map((s) {
              final selected = serviceFilter == s;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(s),
                  selected: selected,
                  onSelected: (_) => onFilterChanged(s),
                ),
              );
            }).toList(),
          ),
        ),
        // Register as worker banner — workers only
        if (!isClient && myProfile == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.engineering_outlined),
                title: const Text('Proposer vos services'),
                subtitle:
                    const Text('Créez votre profil artisan pour être trouvé'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const WorkerRegistrationScreen()),
                ),
              ),
            ),
          ),
        // Workers list
        Expanded(
          child: workers.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (list) {
              final filtered = serviceFilter == 'Tous'
                  ? list
                  : list
                      .where((w) => w.services.contains(serviceFilter))
                      .toList();
              if (filtered.isEmpty) {
                return const Center(
                    child: Text('Aucun artisan trouvé',
                        style: TextStyle(color: Colors.grey)));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _WorkerCard(
                  worker: filtered[i],
                  isMe: filtered[i].userId == myId,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WorkerCard extends StatelessWidget {
  final WorkerProfile worker;
  final bool isMe;

  const _WorkerCard({required this.worker, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
        ),
        title: Row(
          children: [
            Text(worker.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isMe) ...[
              const SizedBox(width: 6),
              const Text('(moi)',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(worker.services.join(' • '),
                style: const TextStyle(fontSize: 12)),
            if (worker.location.isNotEmpty)
              Text(worker.location,
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle,
                size: 10,
                color: worker.available ? Colors.green : Colors.grey),
            Text(worker.available ? 'Dispo' : 'Indispo',
                style: TextStyle(
                    fontSize: 10,
                    color: worker.available ? Colors.green : Colors.grey)),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => WorkerDetailScreen(worker: worker)),
        ),
      ),
    );
  }
}

// ─── Sent Requests ───────────────────────────────────────────────────────────

class _SentRequestsView extends ConsumerWidget {
  const _SentRequestsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(jobRequestsProvider);
    return requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
              child: Text('Aucune demande envoyée',
                  style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (_, i) => _RequestCard(request: list[i], isSent: true),
        );
      },
    );
  }
}

// ─── Received Requests ───────────────────────────────────────────────────────

class _ReceivedRequestsView extends ConsumerWidget {
  const _ReceivedRequestsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(incomingRequestsProvider);
    return requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
              child: Text('Aucune demande reçue',
                  style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (_, i) =>
              _RequestCard(request: list[i], isSent: false),
        );
      },
    );
  }
}

class _RequestCard extends ConsumerWidget {
  final JobRequest request;
  final bool isSent;

  const _RequestCard({required this.request, required this.isSent});

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'declined':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(request.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isSent ? request.workerName : request.clientName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    JobRequest.statusLabel(request.status),
                    style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(request.service,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13)),
            if (request.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(request.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
            if (!isSent && request.status == 'pending') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red),
                      onPressed: () => ref
                          .read(marketplaceServiceProvider)
                          .updateRequestStatus(request.id, 'declined'),
                      child: const Text('Refuser'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => ref
                          .read(marketplaceServiceProvider)
                          .updateRequestStatus(request.id, 'accepted'),
                      child: const Text('Accepter'),
                    ),
                  ),
                ],
              ),
            ],
            if (isSent && request.status == 'pending')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Annuler'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => ref
                      .read(marketplaceServiceProvider)
                      .deleteRequest(request.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
