import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/features/shop/shop_backend.dart';
import 'package:guide_me/features/shop/premium_tab_view.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';

class ShopHomeView extends StatefulWidget {
  const ShopHomeView({super.key});

  @override
  State<ShopHomeView> createState() => _ShopHomeViewState();
}

class _ShopHomeViewState extends State<ShopHomeView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> items = [];
  bool isLoading = true;
  int userPoints = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchData();
  }

  Future<void> fetchData() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    final products = await ShopBackend.fetchShopItems();
    final user = await supabase.from('users').select('guideme_points').eq('id', uid).single();

    setState(() {
      items = products.where((e) => e['name'] != 'Premium').toList();
      userPoints = user['guideme_points'] ?? 0;
      isLoading = false;
    });
  }

  Future<void> handleBuy(Map<String, dynamic> item) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    final error = await ShopBackend.buyItemWithPoints(userId: uid, item: item);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zakupiono pomyślnie')));
      fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sklep GuideMe'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.goNamed(AppRoutes.mainView);
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_cart), text: 'Sklep'),
            Tab(icon: Icon(Icons.stars), text: 'Premium'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text('Masz $userPoints 🪙 GuidePoints',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final item = items[i];
                          final name = item['name'] ?? 'Produkt';
                          final description = item['description'] ?? '';
                          final imageUrl = item['image_url'] ?? 'https://via.placeholder.com/80';

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Card(
                              color: Colors.black.withOpacity(0.9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 6,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Obrazek
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        imageUrl,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.image_not_supported, color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Nazwa i opis
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name,
                                              style: const TextStyle(
                                                  color: Colors.white, fontWeight: FontWeight.bold)),
                                          Text(description, style: const TextStyle(color: Colors.white70)),
                                        ],
                                      ),
                                    ),

                                    // Cena i przycisk
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (item['price_points'] != null)
                                          Text('${item['price_points']} 🪙',
                                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                                        if (item['price_money'] != null)
                                          Text('${item['price_money']} zł',
                                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                                        const SizedBox(height: 6),
                                        if (item['price_points'] != null)
                                          SizedBox(
                                            height: 30,
                                            child: ElevatedButton(
                                              onPressed: () => handleBuy(item),
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 12, vertical: 0),
                                                minimumSize: const Size(0, 30),
                                              ),
                                              child: const Text('Kup', style: TextStyle(fontSize: 12)),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          const PremiumTabView(),
        ],
      ),
    );
  }
}
