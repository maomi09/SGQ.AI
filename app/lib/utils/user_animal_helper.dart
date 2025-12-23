import 'package:shared_preferences/shared_preferences.dart';

class UserAnimalHelper {
  // 可愛動物 emoji 列表
  static const List<String> animalEmojis = [
    '🐱', '🐶', '🐰', '🐻', '🐼', '🐨', '🐯', '🦁',
    '🐸', '🐷', '🐮', '🐹', '🐭', '🦊', '🐺', '🐨',
    '🦄', '🐝', '🦋', '🐢', '🐠', '🐬', '🐳', '🦉',
    '🐤', '🐧', '🦆', '🦅', '🦇', '🐿️', '🦔', '🦝',
  ];

  // 根據用戶ID生成穩定的隨機數
  static int _getStableRandomIndex(String seed, int max) {
    int hash = seed.hashCode;
    return hash.abs() % max;
  }

  // 獲取用戶的專屬動物（優先使用用戶選擇的，否則使用基於ID的隨機動物）
  static Future<String> getUserAnimal(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedAnimal = prefs.getString('user_animal_$userId');
      if (selectedAnimal != null && animalEmojis.contains(selectedAnimal)) {
        return selectedAnimal;
      }
    } catch (e) {
      print('Error loading user animal: $e');
    }
    // 如果沒有選擇，使用基於ID的隨機動物
    final index = _getStableRandomIndex(userId, animalEmojis.length);
    return animalEmojis[index];
  }

  // 獲取默認動物（基於ID，不需要異步）
  static String getDefaultAnimal(String userId) {
    final index = _getStableRandomIndex(userId, animalEmojis.length);
    return animalEmojis[index];
  }
}

