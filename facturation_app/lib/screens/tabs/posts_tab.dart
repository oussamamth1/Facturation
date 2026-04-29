import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/job_post.dart';
import '../../models/worker_profile.dart';
import '../../providers/posts_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/role_provider.dart';
import '../create_post_screen.dart';
import '../post_detail_screen.dart';

class PostsTab extends ConsumerStatefulWidget {
  const PostsTab({super.key});

  @override
  ConsumerState<PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends ConsumerState<PostsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _serviceFilter = 'Tous';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider).value ?? 'worker';
    final isClient = role == 'client';

    return Scaffold(
      body: Column(
        children: [
          if (isClient)
            TabBar(
              controller: _tabCtrl,
              tabs: const [
                Tab(text: 'Toutes les annonces'),
                Tab(text: 'Mes annonces'),
              ],
            ),
          Expanded(
            child: isClient
                ? TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _PostsList(
                        serviceFilter: _serviceFilter,
                        onFilterChanged: (f) =>
                            setState(() => _serviceFilter = f),
                        myOnly: false,
                      ),
                      const _PostsList(
                        serviceFilter: 'Tous',
                        myOnly: true,
                      ),
                    ],
                  )
                : _PostsList(
                    serviceFilter: _serviceFilter,
                    onFilterChanged: (f) =>
                        setState(() => _serviceFilter = f),
                    myOnly: false,
                  ),
          ),
        ],
      ),
      floatingActionButton: isClient
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CreatePostScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Publier'),
            )
          : null,
    );
  }
}

class _PostsList extends ConsumerWidget {
  final String serviceFilter;
  final bool myOnly;
  final ValueChanged<String>? onFilterChanged;

  const _PostsList({
    required this.serviceFilter,
    required this.myOnly,
    this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync =
        myOnly ? ref.watch(myPostsProvider) : ref.watch(jobPostsProvider);

    return postsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (allPosts) {
        final posts = serviceFilter == 'Tous'
            ? allPosts
            : allPosts.where((p) => p.service == serviceFilter).toList();

        return Column(
          children: [
            // Service filter (not shown in "mes annonces" tab)
            if (!myOnly && onFilterChanged != null)
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  children: ['Tous', ...WorkerProfile.allServices]
                      .map((s) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(s),
                              selected: serviceFilter == s,
                              onSelected: (_) => onFilterChanged!(s),
                            ),
                          ))
                      .toList(),
                ),
              ),
            Expanded(
              child: posts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.article_outlined,
                              size: 56,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(
                            myOnly
                                ? 'Vous n\'avez pas encore publié d\'annonce'
                                : 'Aucune annonce trouvée',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                      itemCount: posts.length,
                      itemBuilder: (_, i) => _PostCard(post: posts[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PostCard extends ConsumerWidget {
  final JobPost post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(currentUserIdProvider) ?? '';
    final isOwner = post.clientId == myId;
    final colorScheme = Theme.of(context).colorScheme;
    final isOpen = post.status == 'open';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PostDetailScreen(post: post)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Service chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(post.service,
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  // Status
                  Icon(Icons.circle,
                      size: 8,
                      color: isOpen ? Colors.green : Colors.grey),
                  const SizedBox(width: 3),
                  Text(isOpen ? 'Ouverte' : 'Clôturée',
                      style: TextStyle(
                          fontSize: 11,
                          color: isOpen ? Colors.green : Colors.grey)),
                  const Spacer(),
                  if (isOwner)
                    const Icon(Icons.person_outline,
                        size: 14, color: Colors.grey),
                  if (post.createdAt != null)
                    Text(
                      DateFormat('dd/MM').format(post.createdAt!),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(post.clientName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(post.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: Colors.grey),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(post.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.access_time_outlined,
                      size: 13, color: Colors.grey),
                  const SizedBox(width: 3),
                  Text(post.availableTime,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 12),
                  const Icon(Icons.comment_outlined,
                      size: 13, color: Colors.grey),
                  const SizedBox(width: 3),
                  Text('${post.commentCount}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
