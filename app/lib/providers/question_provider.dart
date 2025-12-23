import 'package:flutter/foundation.dart';
import '../models/question_model.dart';
import '../services/supabase_service.dart';

class QuestionProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  List<QuestionModel> _questions = [];
  QuestionModel? _currentQuestion;
  bool _isLoading = false;

  List<QuestionModel> get questions => _questions;
  QuestionModel? get currentQuestion => _currentQuestion;
  bool get isLoading => _isLoading;

  Future<void> loadQuestions(String studentId, {String? grammarTopicId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _questions = await _supabaseService.getQuestions(studentId, grammarTopicId: grammarTopicId);
    } catch (e) {
      // Handle error
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String> createQuestion(QuestionModel question) async {
    final id = await _supabaseService.createQuestion(question);
    await loadQuestions(question.studentId, grammarTopicId: question.grammarTopicId);
    return id;
  }

  Future<void> updateQuestion(String id, Map<String, dynamic> updates) async {
    await _supabaseService.updateQuestion(id, updates);
    if (_currentQuestion != null && _currentQuestion!.id == id) {
      _currentQuestion = QuestionModel(
        id: _currentQuestion!.id,
        studentId: _currentQuestion!.studentId,
        grammarTopicId: _currentQuestion!.grammarTopicId,
        type: _currentQuestion!.type,
        question: updates['question'] ?? _currentQuestion!.question,
        options: updates['options'] ?? _currentQuestion!.options,
        correctAnswer: updates['correct_answer'] ?? _currentQuestion!.correctAnswer,
        explanation: updates['explanation'] ?? _currentQuestion!.explanation,
        stage: updates['stage'] ?? _currentQuestion!.stage,
        createdAt: _currentQuestion!.createdAt,
        updatedAt: DateTime.now(),
      );
    }
    await loadQuestions(_currentQuestion?.studentId ?? '', grammarTopicId: _currentQuestion?.grammarTopicId);
    notifyListeners();
  }

  void setCurrentQuestion(QuestionModel question) {
    _currentQuestion = question;
    notifyListeners();
  }

  Future<void> deleteQuestion(String id, String studentId, {String? grammarTopicId}) async {
    await _supabaseService.deleteQuestion(id);
    await loadQuestions(studentId, grammarTopicId: grammarTopicId);
  }
}

