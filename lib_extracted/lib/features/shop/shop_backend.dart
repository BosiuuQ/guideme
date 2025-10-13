import 'package:supabase_flutter/supabase_flutter.dart';

class ShopBackend {
  static final _client = Supabase.instance.client;

  /// Pobierz wszystkie dostępne produkty ze sklepu
  static Future<List<Map<String, dynamic>>> fetchShopItems() async {
    final response = await _client
        .from('shop_items')
        .select()
        .order('price_points', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Kup produkt za punkty GuideMe
  static Future<String?> buyItemWithPoints({
    required String userId,
    required Map<String, dynamic> item,
  }) async {
    final int itemPrice = item['price_points'] ?? 0;

    final userResponse = await _client
        .from('users')
        .select('guideme_points')
        .eq('id', userId)
        .single();

    final int userPoints = userResponse['guideme_points'] ?? 0;

    if (userPoints < itemPrice) {
      return 'Nie masz wystarczająco punktów';
    }

    // Odejmujemy punkty
    await _client
        .from('users')
        .update({'guideme_points': userPoints - itemPrice})
        .eq('id', userId);

    final now = DateTime.now();
    final expiresAt = item['is_temporary'] == true && item['duration_days'] != null
        ? now.add(Duration(days: item['duration_days']))
        : null;

    // Zapisz zakupiony produkt
    await _client.from('user_shop_items').insert({
      'user_id': userId,
      'item_id': item['id'],
      'bought_at': now.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    });

    return null; // Sukces
  }

  /// Sprawdź czy użytkownik ma aktywne Premium
  static Future<bool> hasActivePremium(String userId) async {
    final now = DateTime.now().toIso8601String();

    final response = await _client
        .from('user_shop_items')
        .select('expires_at, shop_items(name)')
        .eq('user_id', userId)
        .eq('item_id', 3) // Zakładamy, że id = 3 to Premium
        .gte('expires_at', now)
        .maybeSingle();

    return response != null;
  }
}
