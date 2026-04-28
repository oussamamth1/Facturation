import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/categories_provider.dart';
import '../../providers/products_provider.dart';
import '../../utils/formatters.dart';
import '../../theme.dart';
import '../categories_screen.dart';

class ProductsTab extends ConsumerStatefulWidget {
  const ProductsTab({super.key});

  @override
  ConsumerState<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends ConsumerState<ProductsTab> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'TND');
  String? _editingId;
  String _selectedCategoryId = '';
  String _filterCategoryId = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() {
      _editingId = null;
      _selectedCategoryId = '';
    });
    _nameCtrl.clear();
    _descCtrl.clear();
    _priceCtrl.clear();
    _currencyCtrl.text = 'TND';
  }

  void _load(Product p, List<Category> categories) {
    final cat = categories.firstWhere(
      (c) => c.name == p.category,
      orElse: () => const Category(id: '', userId: '', name: ''),
    );
    setState(() {
      _editingId = p.id;
      _selectedCategoryId = cat.id;
    });
    _nameCtrl.text = p.name;
    _descCtrl.text = p.description;
    _priceCtrl.text = p.price == 0 ? '' : p.price.toString();
    _currencyCtrl.text = p.currency;
  }

  Future<void> _save(List<Category> categories) async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Le nom est obligatoire.')));
      return;
    }
    final userId = ref.read(currentUserIdProvider)!;
    final categoryName = _selectedCategoryId.isNotEmpty
        ? categories.firstWhere((c) => c.id == _selectedCategoryId,
            orElse: () => const Category(id: '', userId: '', name: '')).name
        : '';
    final p = Product(
      id: _editingId ?? '',
      userId: userId,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      price: double.tryParse(_priceCtrl.text) ?? 0,
      currency: _currencyCtrl.text.trim(),
      category: categoryName,
    );
    await ref.read(productsServiceProvider).save(p, userId);
    _clear();
  }

  Future<void> _delete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: Text(p.name),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok == true) await ref.read(productsServiceProvider).delete(p.id);
  }

  void _openManageCategories(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoriesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final products = productsAsync.value ?? [];
    final categories = ref.watch(categoriesProvider).value ?? [];

    final filterName = _filterCategoryId.isNotEmpty
        ? categories
            .firstWhere((c) => c.id == _filterCategoryId,
                orElse: () => const Category(id: '', userId: '', name: ''))
            .name
        : '';
    final filtered = filterName.isEmpty
        ? products
        : products.where((p) => p.category == filterName).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // ── Form card ──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _editingId == null ? 'Nouveau produit' : 'Modifier produit',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  if (_editingId != null)
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Nouveau'),
                      onPressed: _clear,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom du produit / service *',
                  prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Prix unitaire',
                      prefixIcon: Icon(Icons.attach_money, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _currencyCtrl,
                    decoration: const InputDecoration(labelText: 'Devise'),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              // ── Category selector ──
              Row(children: [
                const Icon(Icons.label_outline, size: 16, color: kSlate500),
                const SizedBox(width: 6),
                const Text('Catégorie',
                    style: TextStyle(fontSize: 13, color: kSlate500)),
                const Spacer(),
                if (categories.isNotEmpty)
                  GestureDetector(
                    onTap: () => _openManageCategories(context),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.tune, size: 14, color: kBlue),
                      const SizedBox(width: 3),
                      const Text('Gérer',
                          style: TextStyle(
                              fontSize: 12,
                              color: kBlue,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 8),
              if (categories.isEmpty)
                _AddCategoryButton(
                  onAdd: (name) async {
                    final userId = ref.read(currentUserIdProvider)!;
                    final id = await ref
                        .read(categoriesServiceProvider)
                        .create(name, userId);
                    setState(() => _selectedCategoryId = id);
                  },
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...categories.map((cat) => GestureDetector(
                          onTap: () => setState(() =>
                              _selectedCategoryId =
                                  _selectedCategoryId == cat.id ? '' : cat.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _selectedCategoryId == cat.id
                                  ? kBlue
                                  : kBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _selectedCategoryId == cat.id
                                    ? kBlue
                                    : kBlue.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _selectedCategoryId == cat.id
                                    ? Colors.white
                                    : kBlue,
                              ),
                            ),
                          ),
                        )),
                    _AddCategoryButton(
                      onAdd: (name) async {
                        final userId = ref.read(currentUserIdProvider)!;
                        final id = await ref
                            .read(categoriesServiceProvider)
                            .create(name, userId);
                        setState(() => _selectedCategoryId = id);
                      },
                    ),
                    if (_selectedCategoryId.isNotEmpty)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategoryId = ''),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: kRed.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: kRed.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.close, size: 13, color: kRed),
                                SizedBox(width: 4),
                                Text('Aucune',
                                    style: TextStyle(
                                        fontSize: 12, color: kRed)),
                              ]),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Sauvegarder'),
                  onPressed: () => _save(categories),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        // ── Product list with filter chips ──
        Card(
          child: Column(children: [
            if (categories.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Tous',
                        selected: _filterCategoryId.isEmpty,
                        onTap: () =>
                            setState(() => _filterCategoryId = ''),
                      ),
                      const SizedBox(width: 6),
                      ...categories.map((cat) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _FilterChip(
                              label: cat.name,
                              selected: _filterCategoryId == cat.id,
                              onTap: () => setState(() =>
                                  _filterCategoryId =
                                      _filterCategoryId == cat.id
                                          ? ''
                                          : cat.id),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            if (categories.isNotEmpty)
              const Divider(height: 1, color: kSlate200),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucun produit.',
                    style: TextStyle(color: kSlate500)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: kSlate200),
                itemBuilder: (_, i) {
                  final p = filtered[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          const Color(0xFF10B981).withValues(alpha: 0.1),
                      child: const Icon(Icons.inventory_2,
                          color: Color(0xFF10B981), size: 20),
                    ),
                    title: Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${formatAmount2(p.price)} ${p.currency}',
                            style: const TextStyle(color: kSlate700)),
                        if (p.category.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: kBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(p.category,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: kBlue,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    isThreeLine: p.category.isNotEmpty,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: kRed, size: 20),
                      onPressed: () => _delete(p),
                    ),
                    onTap: () => _load(p, categories),
                  );
                },
              ),
          ]),
        ),
      ]),
    );
  }
}

// ── Add category inline button ──

class _AddCategoryButton extends StatefulWidget {
  final Future<void> Function(String name) onAdd;
  const _AddCategoryButton({required this.onAdd});

  @override
  State<_AddCategoryButton> createState() => _AddCategoryButtonState();
}

class _AddCategoryButtonState extends State<_AddCategoryButton> {
  bool _editing = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _editing = false);
      return;
    }
    await widget.onAdd(name);
    _ctrl.clear();
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return GestureDetector(
        onTap: () => setState(() => _editing = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kSlate200),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add, size: 14, color: kSlate500),
            SizedBox(width: 4),
            Text('Nouvelle', style: TextStyle(fontSize: 12, color: kSlate500)),
          ]),
        ),
      );
    }
    return SizedBox(
      width: 160,
      height: 34,
      child: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Nom catégorie...',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          suffixIcon: IconButton(
            icon: const Icon(Icons.check, size: 16, color: kBlue),
            onPressed: _submit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        onSubmitted: (_) => _submit(),
        onTapOutside: (_) => setState(() {
          _editing = false;
          _ctrl.clear();
        }),
      ),
    );
  }
}

// ── Shared filter chip ──

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? kBlue : kBlue.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? kBlue : kBlue.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : kBlue,
            ),
          ),
        ),
      );
}
