import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/products_provider.dart';
import '../../utils/formatters.dart';
import '../../theme.dart';

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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() => _editingId = null);
    _nameCtrl.clear();
    _descCtrl.clear();
    _priceCtrl.clear();
    _currencyCtrl.text = 'TND';
  }

  void _load(Product p) {
    setState(() => _editingId = p.id);
    _nameCtrl.text = p.name;
    _descCtrl.text = p.description;
    _priceCtrl.text = p.price == 0 ? '' : p.price.toString();
    _currencyCtrl.text = p.currency;
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Le nom est obligatoire.')));
      return;
    }
    final userId = ref.read(currentUserIdProvider)!;
    final p = Product(
      id: _editingId ?? '',
      userId: userId,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      price: double.tryParse(_priceCtrl.text) ?? 0,
      currency: _currencyCtrl.text.trim(),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok == true) await ref.read(productsServiceProvider).delete(p.id);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final products = productsAsync.value ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Sauvegarder'),
                  onPressed: _save,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: products.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aucun produit.', style: TextStyle(color: kSlate500)),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: kSlate200),
                  itemBuilder: (_, i) {
                    final p = products[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                        child: const Icon(Icons.inventory_2, color: Color(0xFF10B981), size: 20),
                      ),
                      title: Text(p.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${formatAmount2(p.price)} ${p.currency}',
                          style: const TextStyle(color: kSlate700)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: kRed, size: 20),
                        onPressed: () => _delete(p),
                      ),
                      onTap: () => _load(p),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
