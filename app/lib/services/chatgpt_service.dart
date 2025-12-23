import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatGPTService {
  final String apiKey;
  final String baseUrl = 'https://api.openai.com/v1/chat/completions';

  // System prompt 用於所有對話
  static const String _systemPrompt = 'You are an instructional AI tutor designed to support university EFL students in student-generated grammar question (SGQ) activities.\n\nYour role is to provide scaffolding, not answers.\n\nIMPORTANT RULES:\n1. Do NOT rewrite the student\'s question.\n2. Do NOT provide the correct answer to the question.\n3. Do NOT generate a complete sample question.\n4. Focus on guiding, prompting, and raising awareness.\n5. Use clear, supportive, and instructional language.\n6. When appropriate, ask reflective questions instead of giving direct judgments.\n\nYour scaffolding should support four dimensions:\n- Form-focused scaffolding\n- Linguistic scaffolding\n- Cognitive scaffolding\n- Metacognitive scaffolding';

  ChatGPTService({required this.apiKey});

  Future<String> getScaffoldingResponse(String question, int stage) async {
    String prompt = _getPromptForStage(question, stage);

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'messages': [
          {
            'role': 'system',
            'content': _systemPrompt,
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.7,
        'max_tokens': 500,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('Failed to get ChatGPT response: ${response.body}');
    }
  }

  String _getPromptForStage(String question, int stage) {
    switch (stage) {
      case 1:
        return '''【階段一：認知鷹架 Prompt（Cognitive Scaffolding）】
Here is the grammar question I created:
$question
Please help me reflect on the thinking behind this question:
1. What grammar rule or language feature does this question mainly test?
2. Is the target rule clearly focused, or might learners be confused?
3. Are there any elements that distract from the grammar focus?''';

      case 2:
        return '''【階段二：形式鷹架 Prompt（Form-focused Scaffolding）】
This is the grammar question I am revising:
$question
Please provide form-focused guidance only:
1. Which grammatical forms are involved in this question
   (e.g., tense, word order, voice, agreement)?
2. Which forms are most likely to cause difficulty for learners?
3. Do NOT correct or rewrite the sentence.''';

      case 3:
        return '''【階段三：語言鷹架 Prompt（Linguistic Scaffolding）】
Here is my grammar question:
$question
Please help with linguistic clarity:
1. Is the wording natural and clear for EFL learners?
2. Are there any unnatural or confusing expressions?
3. Suggest minor language improvements WITHOUT changing
   the grammar rule being tested.''';

      case 4:
        return '''【階段四：後設認知鷹架 Prompt（Metacognitive Scaffolding）】
This is my final grammar question:
$question
Please help me evaluate this question:
1. Is this a good grammar question for learners at my target level?
2. What are the strengths of this question?
3. What possible weaknesses should I be aware of?
4. What could I improve when creating my next question?''';

      default:
        throw Exception('Invalid stage: $stage');
    }
  }

  // 處理追加問題（基於對話歷史）
  Future<String> getAdditionalResponse(String userMessage, String question, int stage, List<Map<String, dynamic>> conversationHistory) async {
    // 構建消息列表
    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': _systemPrompt,
      },
    ];

    // 添加對話歷史（conversationHistory 已經過濾了當前階段的消息）
    for (var msg in conversationHistory) {
      final role = msg['type'] == 'user' ? 'user' : 'assistant';
      messages.add({
        'role': role,
        'content': msg['content'] as String,
      });
    }

    // 添加用戶的新問題
    messages.add({
      'role': 'user',
      'content': userMessage,
    });

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 500,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('Failed to get ChatGPT response: ${response.body}');
    }
  }
}

