import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShopHomeView extends StatefulWidget {
  const ShopHomeView({super.key});
  @override
  State<ShopHomeView> createState() => _ShopHomeViewState();
}

class _ShopHomeViewState extends State<ShopHomeView> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  int _userPoints = 0;
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait([_fetchPoints(), _fetchProducts()]);
    } catch (e) {
      _error = 'Błąd ładowania: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchPoints() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      _userPoints = 0;
      return;
    }
    final res = await supabase
        .from('users')
        .select('guideme_points')
        .eq('id', uid)
        .maybeSingle();
    _userPoints = (res?['guideme_points'] as int?) ?? 0;
  }

  Future<void> _fetchProducts() async {
    final rows = await supabase
        .from('shop_items')
        .select(
          'id,name,description,image_url,price_points,price_money,is_premium_only,is_temporary,duration_days',
        )
        .order('name');
    _products = (rows as List)
        .map((e) => Product.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  void _openProduct(BuildContext context, Product p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductSheet(product: p, userPoints: _userPoints),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgStart = Color(0xFF0C0F1C);
    const bgEnd = Color(0xFF0A1F2E);

    return Scaffold(
      backgroundColor: bgStart,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Sklep GuideMe', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          tooltip: 'Wstecz',
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh, color: Colors.white70),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bgStart, bgEnd],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  _PointsBar(points: _userPoints, loading: _loading),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(_error!, style: const TextStyle(color: Colors.white)),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _loading
                        ? const _LoadingGrid()
                        : _products.isEmpty
                            ? const _EmptyView()
                            : GridView.builder(
                                physics: const BouncingScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.78,
                                ),
                                itemCount: _products.length,
                                itemBuilder: (context, i) {
                                  final p = _products[i];
                                  return _ProductCard(
                                    product: p,
                                    onTap: () => _openProduct(context, p),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===== MODELE =====

class Product {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final int? pricePoints;
  final num? priceMoney;
  final bool? isPremiumOnly;
  final bool? isTemporary;
  final int? durationDays;

  Product({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.pricePoints,
    this.priceMoney,
    this.isPremiumOnly,
    this.isTemporary,
    this.durationDays,
  });

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? 'Bez nazwy',
        description: m['description'] as String?,
        imageUrl: m['image_url'] as String?,
        pricePoints: (m['price_points'] as int?),
        priceMoney: (m['price_money'] as num?),
        isPremiumOnly: m['is_premium_only'] as bool?,
        isTemporary: m['is_temporary'] as bool?,
        durationDays: m['duration_days'] as int?,
      );

  String priceLabel() {
    if (pricePoints != null && pricePoints! > 0) return '${pricePoints!} GP';
    if (priceMoney != null && priceMoney! > 0) return '${priceMoney!} zł';
    return 'FREE';
  }
}

/// ===== WIDOKI POMOCNICZE =====

class _PointsBar extends StatelessWidget {
  final int points;
  final bool loading;
  const _PointsBar({required this.points, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.token_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loading ? 'Ładowanie…' : 'Masz $points 🪙 GuidePoints',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: product.imageUrl == null || product.imageUrl!.isEmpty
                    ? Container(
                        color: Colors.black26,
                        child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white54)),
                      )
                    : Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.black26,
                          child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white54)),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.priceLabel(),
                    style: const TextStyle(color: Color(0xFF4AF2C5), fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductSheet extends StatelessWidget {
  final Product product;
  final int userPoints;
  const _ProductSheet({required this.product, required this.userPoints});

  @override
  Widget build(BuildContext context) {
    final canAfford = (product.pricePoints ?? 0) <= userPoints || (product.pricePoints == null);
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            color: const Color(0xFF101826).withOpacity(0.96),
            child: ListView(
              controller: controller,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: product.imageUrl == null || product.imageUrl!.isEmpty
                      ? Container(
                          height: 220,
                          color: Colors.black26,
                          child: const Center(
                            child: Icon(Icons.image_not_supported, color: Colors.white54),
                          ),
                        )
                      : Image.network(product.imageUrl!, height: 220, fit: BoxFit.cover),
                ),
                const SizedBox(height: 14),
                Text(
                  product.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      product.priceLabel(),
                      style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    const SizedBox(width: 10),
                    if (product.isPremiumOnly == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.withOpacity(0.35)),
                        ),
                        child: const Text('Premium only', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                  ],
                ),
                if (product.durationDays != null && product.durationDays! > 0) ...[
                  const SizedBox(height: 6),
                  Text('Czas trwania: ${product.durationDays} dni', style: const TextStyle(color: Colors.white70)),
                ],
                const SizedBox(height: 12),
                Text(
                  (product.description?.trim().isEmpty ?? true) ? 'Brak opisu.' : (product.description ?? ''),
                  style: const TextStyle(color: Colors.white70, height: 1.45),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: podłącz zakup (odejmij GP / zapisz purchase)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kupno: wkrótce dostępne.')),
                      );
                    },
                    icon: const Icon(Icons.shopping_cart_checkout_rounded),
                    label: Text(
                      canAfford ? 'KUP' : 'Za mało punktów',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford ? const Color(0xFF00E5FF) : Colors.grey,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          'Brak produktów.',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
      );
}
