import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class ChatGPTService {
  final String backendUrl;

  ChatGPTService({String? backendUrl}) 
      : backendUrl = backendUrl ?? _getBackendUrl() {
    print('ChatGPTService 初始化，後端 URL: $backendUrl');
  }

  // 獲取後端 URL（統一使用 AppConfig 中的配置）
  static String _getBackendUrl() {
    // 生產環境：直接使用 AppConfig 中的 AWS URL
    return AppConfig.backendApiUrl;
    
    // 如果需要本地開發，可以取消下面的註釋並註釋掉上面的 return
    // if (kIsWeb) {
    //   return 'http://localhost:8000';
    // } else if (Platform.isAndroid) {
    //   // Android 模擬器需要使用 10.0.2.2 來訪問主機的 localhost
    //   return 'http://10.0.2.2:8000';
    // } else if (Platform.isIOS) {
    //   // iOS 模擬器可以使用 localhost
    //   return 'http://localhost:8000';
    // } else {
    //   return 'http://127.0.0.1:8000';
    // }
  }

  Future<String> getScaffoldingResponse(String question, int stage) async {
    // 獲取當前用戶的 JWT Token
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session == null || session.accessToken.isEmpty) {
      throw Exception('請先登入');
    }
    
    final url = '$backendUrl/api/chatgpt/scaffolding';
    print('發送請求到: $url');
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: jsonEncode({
        'question': question,
        'stage': stage,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'] as String;
    } else {
      // 不洩露後端詳細錯誤資訊
      print('ChatGPT API 錯誤: statusCode=${response.statusCode}, body=${response.body}');
      throw Exception('無法取得 ChatGPT 回應，請稍後再試');
    }
  }


  // 處理追加問題（基於對話歷史）
  Future<String> getAdditionalResponse(String userMessage, String question, int stage, List<Map<String, dynamic>> conversationHistory) async {
    // 獲取當前用戶的 JWT Token
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session == null || session.accessToken.isEmpty) {
      throw Exception('請先登入');
    }
    
    final url = '$backendUrl/api/chatgpt/additional';
    print('發送追加問題請求到: $url');
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: jsonEncode({
        'user_message': userMessage,
        'question': question,
        'stage': stage,
        'conversation_history': conversationHistory,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'] as String;
    } else {
      // 不洩露後端詳細錯誤資訊
      print('ChatGPT API 錯誤: statusCode=${response.statusCode}, body=${response.body}');
      throw Exception('無法取得 ChatGPT 回應，請稍後再試');
    }
  }
}

