import 'package:flutter/foundation.dart';
import '../models/class_model.dart';
import '../services/supabase_service.dart';

class ClassProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  
  List<ClassModel> _classes = [];
  ClassModel? _selectedClass;
  ClassModel? _studentClass;
  bool _isLoading = false;
  String? _error;

  List<ClassModel> get classes => _classes;
  ClassModel? get selectedClass => _selectedClass;
  ClassModel? get studentClass => _studentClass;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 載入老師的所有班級
  Future<void> loadTeacherClasses(String teacherId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _classes = await _supabaseService.getTeacherClasses(teacherId);
      
      // 如果已選擇的班級被刪除，清除選擇
      if (_selectedClass != null) {
        final stillExists = _classes.any((c) => c.id == _selectedClass!.id);
        if (!stillExists) {
          _selectedClass = null;
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
    notifyListeners();
  }

  // 通過 ID 選擇班級
  void selectClassById(String? classId) {
    if (classId == null) {
      _selectedClass = null;
    } else {
      _selectedClass = _classes.firstWhere(
        (c) => c.id == classId,
        orElse: () => _classes.first,
      );
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

  // 清除狀態（登出時使用）
  void clear() {
    _classes = [];
    _selectedClass = null;
    _studentClass = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
