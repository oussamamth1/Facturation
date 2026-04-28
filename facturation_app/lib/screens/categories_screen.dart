import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../providers/auth_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/products_provider.dart';
import '../theme.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final _addCtrl = TextEditingController();
  bool _adding = false;
  String? _renamingId;
  final _renameCtrl = TextEditingController();

  @override
  void dispose() {
    _addCtrl.dispose();
    _renameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _addCtrl.text.trim();
    if (name.isEmpty) return;
    final userId = ref.read(currentUserIdProvider)!;
    setState(() => _adding = true);
    try {
      await ref.read(categoriesServiceProvider).create(name, userId);
      _addCtrl.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _startRename(Category cat) {
    _renameCtrl.text = cat.name;
    setState(() => _renamingId = cat.id);
  }

  Future<void> _submitRename(Category cat) async {
    final newName = _renameCtrl.text.trim();
    if (newName.isEmpty || newName == cat.name) {
      setState(() => _renamingId = null);
      return;
    }
    await ref.read(categoriesServiceProvider).rename(cat.id, newName);
    if (mounted) setState(() => _renamingId = null);
  }

  Future<void> _delete(Category cat, int productCount) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer la catégorie ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF334155)),
                children: [
                  const TextSpan(text: 'Catégorie : '),
                  TextSpan(
                    text: cat.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (productCount > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$productCount produit${productCount > 1 ? 's' : ''} utilise${productCount > 1 ? 'nt' : ''} cette catégorie.',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ]),
              ),
            ],
          ],
        ),
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
    if (ok == true) {
      await ref.read(categoriesServiceProvider).delete(cat.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? [];
    final products = ref.watch(productsProvider).value ?? [];

    // count products per category name
    final Map<String, int> countByName = {};
    for (final p in products) {
      if (p.category.isNotEmpty) {
        countByName[p.category] = (countByName[p.category] ?? 0) + 1;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des catégories'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(children: [
          // ── Add new category ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: kSlate200)),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _addCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Nom de la nouvelle catégorie...',
                    prefixIcon:
                        const Icon(Icons.label_outline, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kSlate200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kSlate200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kBlue, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (_) => _create(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _adding ? null : _create,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _adding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add, size: 18),
                          SizedBox(width: 4),
                          Text('Ajouter'),
                        ]),
                ),
              ),
            ]),
          ),

          // ── Category list ──
          Expanded(
            child: categories.isEmpty
                ? _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final cat = categories[i];
                      final count = countByName[cat.name] ?? 0;
                      final isRenaming = _renamingId == cat.id;

                      return _CategoryCard(
                        category: cat,
                        productCount: count,
                        isRenaming: isRenaming,
                        renameCtrl: _renameCtrl,
                        onEdit: () => _startRename(cat),
                        onRenameSubmit: () => _submitRename(cat),
                        onRenameCancel: () =>
                            setState(() => _renamingId = null),
                        onDelete: () => _delete(cat, count),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

// ── Category card ──

class _CategoryCard extends StatelessWidget {
  final Category category;
  final int productCount;
  final bool isRenaming;
  final TextEditingController renameCtrl;
  final VoidCallback onEdit;
  final VoidCallback onRenameSubmit;
  final VoidCallback onRenameCancel;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.productCount,
    required this.isRenaming,
    required this.renameCtrl,
    required this.onEdit,
    required this.onRenameSubmit,
    required this.onRenameCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRenaming ? kBlue : kSlate200,
          width: isRenaming ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.label_rounded, color: kBlue, size: 20),
          ),
          const SizedBox(width: 12),

          // Name / rename field
          Expanded(
            child: isRenaming
                ? TextField(
                    controller: renameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: kBlue, width: 1.5),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check,
                            size: 18, color: kBlue),
                        onPressed: onRenameSubmit,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    onSubmitted: (_) => onRenameSubmit(),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        productCount == 0
                            ? 'Aucun produit'
                            : '$productCount produit${productCount > 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
          ),

          // Actions
          if (isRenaming)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: kSlate500),
              onPressed: onRenameCancel,
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: kBlue),
              tooltip: 'Renommer',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: kRed),
              tooltip: 'Supprimer',
              onPressed: onDelete,
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Empty state ──

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.label_outline,
                  size: 40, color: kBlue),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucune catégorie',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ajoutez une catégorie pour organiser\nvos produits et services.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
}
