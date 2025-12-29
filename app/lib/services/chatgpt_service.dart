import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ChatGPTService {
  final String backendUrl;

  ChatGPTService({String? backendUrl}) 
      : backendUrl = backendUrl ?? _getBackendUrl() {
    print('ChatGPTService 初始化，後端 URL: $backendUrl');
  }

  // 根據平台自動選擇正確的後端 URL
  static String _getBackendUrl() {
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else if (Platform.isAndroid) {
      // Android 模擬器需要使用 10.0.2.2 來訪問主機的 localhost
      // 實體設備需要使用電腦的 IP 地址（例如：192.168.1.100）
      return 'http://10.0.2.2:8000';
    } else if (Platform.isIOS) {
      // iOS 模擬器可以使用 localhost
      return 'http://localhost:8000';
    } else {
      return 'http://127.0.0.1:8000';
    }
  }

  Future<String> getScaffoldingResponse(String question, int stage) async {
    final url = '$backendUrl/api/chatgpt/scaffolding';
    print('發送請求到: $url');
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
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
      throw Exception('Failed to get ChatGPT response: ${response.body}');
    }
  }


  // 處理追加問題（基於對話歷史）
  Future<String> getAdditionalResponse(String userMessage, String question, int stage, List<Map<String, dynamic>> conversationHistory) async {
    final url = '$backendUrl/api/chatgpt/additional';
    print('發送追加問題請求到: $url');
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
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
      throw Exception('Failed to get ChatGPT response: ${response.body}');
    }
  }
}

