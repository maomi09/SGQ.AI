import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/class_model.dart';
import '../services/supabase_service.dart';

/// 與班級選擇器 [kAllClassesMenuValue] 相同，用於持久化「所有班級」。
const String kTeacherAllClassesPersistValue = '__all_classes__';

class ClassProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  static String _teacherClassPrefsKey(String teacherId) =>
      'teacher_last_selected_class_$teacherId';

  List<ClassModel> _classes = [];
  ClassModel? _selectedClass;
  ClassModel? _studentClass;
  bool _isLoading = false;
  String? _error;
  String? _activeTeacherId;

  List<ClassModel> get classes => _classes;
  ClassModel? get selectedClass => _selectedClass;
  ClassModel? get studentClass => _studentClass;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _restoreTeacherClassSelection(String teacherId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_teacherClassPrefsKey(teacherId));
      if (saved == null) {
        return;
      }
      if (saved == kTeacherAllClassesPersistValue) {
        _selectedClass = null;
        return;
      }
      if (_classes.any((c) => c.id == saved)) {
        _selectedClass = _classes.firstWhere((c) => c.id == saved);
      } else {
        _selectedClass = null;
        unawaited(_persistTeacherClassSelection(teacherId));
      }
    } catch (e) {
      print('Restore teacher class selection failed: $e');
    }
  }

  Future<void> _persistTeacherClassSelection(String teacherId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _teacherClassPrefsKey(teacherId);
      if (_selectedClass == null) {
        await prefs.setString(key, kTeacherAllClassesPersistValue);
      } else {
        await prefs.setString(key, _selectedClass!.id);
      }
    } catch (e) {
      print('Persist teacher class selection failed: $e');
    }
  }

  // 載入老師的所有班級
  Future<void> loadTeacherClasses(String teacherId) async {
    _activeTeacherId = teacherId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _classes = await _supabaseService.getTeacherClasses(teacherId);
      _selectedClass = null;
      await _restoreTeacherClassSelection(teacherId);

      // 如果已選擇的班級被刪除，清除選擇
      if (_selectedClass != null) {
        final stillExists = _classes.any((c) => c.id == _selectedClass!.id);
        if (!stillExists) {
          _selectedClass = null;
          unawaited(_persistTeacherClassSelection(teacherId));
        }
      }
    } catch (e) {
      _error = '載入班級失敗：$e';
      print(_error);
    }

    _isLoading = false;
    notifyListeners();
  }

  // 載入學生所屬的班級
  Future<void> loadStudentClass(String studentId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _studentClass = await _supabaseService.getStudentClass(studentId);
    } catch (e) {
      _error = '載入班級失敗：$e';
      print(_error);
    }

    _isLoading = false;
    notifyListeners();
  }

  // 選擇班級（老師端使用）
  void selectClass(ClassModel? classModel) {
    _selectedClass = classModel;
    final teacherId = _activeTeacherId;
    if (teacherId != null) {
      unawaited(_persistTeacherClassSelection(teacherId));
    }
    notifyListeners();
  }

  /// 更新本地班級 AI 小幫手開關狀態（與伺服器同步後呼叫）。
  void updateLocalClassAiHelper(String classId, bool enabled) {
    final index = _classes.indexWhere((c) => c.id == classId);
    if (index >= 0) {
      _classes[index] = _classes[index].copyWith(aiHelperEnabled: enabled);
    }
    if (_selectedClass?.id == classId) {
      _selectedClass = _selectedClass!.copyWith(aiHelperEnabled: enabled);
    }
    notifyListeners();
  }

  // 通過 ID 選擇班級；[classId] 為 null 或 [kAllClassesMenuValue] 表示所有班級
  void selectClassById(String? classId) {
    if (classId == null || classId == kTeacherAllClassesPersistValue) {
      _selectedClass = null;
    } else if (_classes.isEmpty) {
      _selectedClass = null;
    } else {
      _selectedClass = _classes.firstWhere(
        (c) => c.id == classId,
        orElse: () => _classes.first,
      );
    }
    final teacherId = _activeTeacherId;
    if (teacherId != null) {
      unawaited(_persistTeacherClassSelection(teacherId));
    }
    notifyListeners();
  }

  // 創建班級
  Future<ClassModel?> createClass(String name, String teacherId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newClass = await _supabaseService.createClass(name, teacherId);
      if (newClass != null) {
        _classes.insert(0, newClass);
        notifyListeners();
      }
      return newClass;
    } catch (e) {
      _error = '建立班級失敗：$e';
      print(_error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 更新班級
  Future<bool> updateClass(String classId, String name) async {
    _error = null;

    try {
      final success = await _supabaseService.updateClass(classId, name);
      if (success) {
        // 更新本地列表
        final index = _classes.indexWhere((c) => c.id == classId);
        if (index >= 0) {
          _classes[index] = _classes[index].copyWith(
            name: name,
            updatedAt: DateTime.now(),
          );
        }
        
        // 更新已選擇的班級
        if (_selectedClass?.id == classId) {
          _selectedClass = _selectedClass!.copyWith(
            name: name,
            updatedAt: DateTime.now(),
          );
        }
        
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = '更新班級失敗：$e';
      print(_error);
      return false;
    }
  }

  // 刪除班級
  Future<bool> deleteClass(String classId) async {
    _error = null;

    try {
      await _supabaseService.deleteClass(classId);
      
      // 從本地列表移除
      _classes.removeWhere((c) => c.id == classId);
      
      // 如果刪除的是已選擇的班級，清除選擇
      if (_selectedClass?.id == classId) {
        _selectedClass = null;
        final teacherId = _activeTeacherId;
        if (teacherId != null) {
          unawaited(_persistTeacherClassSelection(teacherId));
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('刪除班級失敗：$_error');
      rethrow;
    }
  }

  // 學生加入班級
  Future<bool> joinClass(String studentId, String classCode) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabaseService.joinClass(studentId, classCode);
      // 重新載入學生的班級資訊
      await loadStudentClass(studentId);
      return true;
    } catch (e) {
      _error = e.toString();
      print('加入班級失敗：$_error');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // 學生退出班級
  Future<bool> leaveClass(String studentId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _supabaseService.leaveClass(studentId);
      if (success) {
        _studentClass = null;
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = '退出班級失敗：$e';
      print(_error);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 獲取班級學生數量
  Future<int> getClassStudentCount(String classId) async {
    return await _supabaseService.getClassStudentCount(classId);
  }

  // 通過代碼查找班級
  Future<ClassModel?> findClassByCode(String code) async {
    return await _supabaseService.getClassByCode(code);
  }

  // 清除錯誤
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // 清除狀態（登出時使用；班級選擇偏好保留於本機供下次登入還原）
  void clear() {
    _classes = [];
    _selectedClass = null;
    _studentClass = null;
    _activeTeacherId = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
