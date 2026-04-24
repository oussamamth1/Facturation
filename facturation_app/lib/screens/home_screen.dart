import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/clients_tab.dart';
import 'tabs/products_tab.dart';
import 'tabs/invoices_tab.dart';
import 'jobs_screen.dart';
import '../screens/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  static const _tabs = [
    DashboardTab(),
    ClientsTab(),
    ProductsTab(),
    InvoicesTab(),
    JobsScreen(),
  ];

  static const _labels = [
    'Tableau de bord',
    'Clients',
    'Produits',
    'Factures',
    'Travaux',
  ];

  static const _icons = [
    Icons.dashboard_outlined,
    Icons.people_outline,
    Icons.inventory_2_outlined,
    Icons.receipt_outlined,
    Icons.work_outline,
  ];

  static const _selectedIcons = [
    Icons.dashboard,
    Icons.people,
    Icons.inventory_2,
    Icons.receipt,
    Icons.work,
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_labels[_index]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
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
      body: _tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: List.generate(
          5,
          (i) => NavigationDestination(
            icon: Icon(_icons[i]),
            selectedIcon: Icon(_selectedIcons[i]),
            label: _labels[i],
          ),
        ),
      ),
    );
  }
}
