import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/role_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/marketplace_provider.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/clients_tab.dart';
import 'tabs/products_tab.dart';
import 'tabs/invoices_tab.dart';
import 'tabs/calendar_tab.dart';
import 'tabs/marketplace_tab.dart';
import 'tabs/chat_list_tab.dart';
import 'tabs/posts_tab.dart';
import 'jobs_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/categories_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  // ── Worker: full app ──────────────────────────────────────────────────────
  List<Widget> _workerTabs() => [
    DashboardTab(onNavigate: (i) => setState(() => _index = i)),
    const ClientsTab(),
    const ProductsTab(),
    const InvoicesTab(),
    const JobsScreen(),
    const CalendarTab(),
    const MarketplaceTab(),
    const PostsTab(),
    const ChatListTab(),
  ];

  static const _workerLabels = [
    'Tableau de bord', 'Clients', 'Produits', 'Factures',
    'Travaux', 'Calendrier', 'Marketplace', 'Annonces', 'Messages',
  ];
  static const _workerIcons = [
    Icons.dashboard_outlined, Icons.people_outline,
    Icons.inventory_2_outlined, Icons.receipt_outlined,
    Icons.work_outline, Icons.calendar_month_outlined,
    Icons.store_outlined, Icons.article_outlined, Icons.chat_bubble_outline,
  ];
  static const _workerSelectedIcons = [
    Icons.dashboard, Icons.people,
    Icons.inventory_2, Icons.receipt,
    Icons.work, Icons.calendar_month,
    Icons.store, Icons.article, Icons.chat_bubble,
  ];

  // ── Client: find workers + post needs + chat ──────────────────────────────
  static List<Widget> _clientTabs() => [
    const MarketplaceTab(),
    const PostsTab(),
    const ChatListTab(),
  ];

  static const _clientLabels = ['Marketplace', 'Annonces', 'Messages'];
  static const _clientIcons = [
    Icons.store_outlined, Icons.article_outlined, Icons.chat_bubble_outline,
  ];
  static const _clientSelectedIcons = [
    Icons.store, Icons.article, Icons.chat_bubble,
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(userRoleProvider).value ?? 'worker';
    final isClient = role == 'client';

    final tabs = isClient ? _clientTabs() : _workerTabs();
    final labels = isClient ? _clientLabels : _workerLabels;
    final icons = isClient ? _clientIcons : _workerIcons;
    final selectedIcons = isClient ? _clientSelectedIcons : _workerSelectedIcons;

    // Clamp index when switching roles
    final safeIndex = _index.clamp(0, tabs.length - 1);
    if (safeIndex != _index) WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _index = safeIndex);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(labels[safeIndex]),
        actions: [
          // Categories button only for workers on the products tab
          if (!isClient && safeIndex == 2)
            IconButton(
              icon: const Icon(Icons.label_outlined),
              tooltip: 'Gérer les catégories',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CategoriesScreen())),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
         
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Déconnexion'),
                  content: Text('Connecté en tant que ${user?.email ?? ''}'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annuler')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Déconnexion')),
                  ],
                ),
              );
              if (ok == true) ref.read(authServiceProvider).signOut();
            },
          ),
        ],
      ),
      body: tabs[safeIndex],
      bottomNavigationBar: _NavBar(
        selectedIndex: safeIndex,
        onSelected: (i) => setState(() => _index = i),
        labels: labels,
        icons: icons,
        selectedIcons: selectedIcons,
        isClient: isClient,
      ),
    );
  }
}

// ── Navigation bar with badges ────────────────────────────────────────────────

class _NavBar extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<String> labels;
  final List<IconData> icons;
  final List<IconData> selectedIcons;
  final bool isClient;

  const _NavBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.labels,
    required this.icons,
    required this.selectedIcons,
    required this.isClient,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadMessages = ref.watch(totalUnreadProvider);
    final pendingRequests = isClient ? 0 : ref.watch(pendingIncomingCountProvider);

    // Indices of special tabs (Messages and Marketplace) vary by role
    // Client:  0=Marketplace, 1=Annonces, 2=Messages
    // Worker:  0..5=existing, 6=Marketplace, 7=Annonces, 8=Messages
    final marketplaceIdx = isClient ? 0 : 6;
    final messagesIdx = isClient ? 2 : 8;

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      destinations: List.generate(labels.length, (i) {
        Widget icon = Icon(icons[i]);
        Widget selIcon = Icon(selectedIcons[i]);

        if (i == messagesIdx && unreadMessages > 0) {
          final label = unreadMessages > 99 ? '99+' : '$unreadMessages';
          icon = Badge(label: Text(label), child: Icon(icons[i]));
          selIcon = Badge(label: Text(label), child: Icon(selectedIcons[i]));
        } else if (i == marketplaceIdx && pendingRequests > 0) {
          final label = pendingRequests > 99 ? '99+' : '$pendingRequests';
          icon = Badge(label: Text(label), child: Icon(icons[i]));
          selIcon = Badge(label: Text(label), child: Icon(selectedIcons[i]));
        }

        return NavigationDestination(
          icon: icon,
          selectedIcon: selIcon,
          label: labels[i],
        );
      }),
    );
  }
}
