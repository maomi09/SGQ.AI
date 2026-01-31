import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';

class AuthProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentSessionId; // 當前活動的 session ID

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get errorMessage => _errorMessage;
  
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> signUp(String email, String password, String name, String role, {String? studentId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _supabaseService.signUp(email, password, name, role, studentId: studentId);
      if (response.user != null) {
        // 等待一下讓資料庫有時間寫入
        await Future.delayed(const Duration(milliseconds: 500));
        
        _currentUser = await _supabaseService.getUser(response.user!.id);
        
        // 如果還是沒有找到用戶記錄，從 auth metadata 創建
        if (_currentUser == null) {
          final authUser = response.user!;
          final userMetadata = authUser.userMetadata;
          _currentUser = UserModel(
            id: authUser.id,
            email: authUser.email ?? email,
            name: userMetadata?['name'] as String? ?? name,
            role: userMetadata?['role'] as String? ?? role,
            studentId: userMetadata?['student_id'] as String? ?? studentId,
          );
          
          // 再次嘗試創建用戶記錄
          try {
            await _supabaseService.createUserIfNotExists(_currentUser!);
            // 等待一下讓資料庫有時間寫入
            await Future.delayed(const Duration(milliseconds: 300));
            // 重新獲取用戶資料
            _currentUser = await _supabaseService.getUser(response.user!.id);
            // 如果還是獲取不到，使用從 auth metadata 創建的用戶對象
            if (_currentUser == null) {
              print('Warning: Could not retrieve user from database after creation, using auth metadata');
              // _currentUser 已經設置為從 auth metadata 創建的對象，繼續使用它
            }
          } catch (e) {
            print('Warning: Failed to create user record after signup: $e');
            // 即使創建失敗，也使用從 auth metadata 創建的用戶對象
          }
        } else {
          // 如果從 users 表獲取成功，優先使用 users 表的 email（因為它是最新的）
          // 如果 users 表的 email 為空，才使用 auth email
          final authUser = response.user!;
          final authEmail = authUser.email ?? email;
          final usersTableEmail = _currentUser!.email;
          
          // 優先使用 users 表的 email，因為它可能比 auth email 更新（例如剛修改過 email）
          // 只有在 users 表的 email 為空時，才使用 auth email
          final finalEmail = usersTableEmail.isNotEmpty ? usersTableEmail : authEmail;
          
          // 只有在 email 真的不同時才更新（避免不必要的更新）
          if (_currentUser!.email != finalEmail) {
            _currentUser = UserModel(
              id: _currentUser!.id,
              email: finalEmail,
              name: _currentUser!.name,
              role: _currentUser!.role,
              studentId: _currentUser!.studentId,
            );
            
            // 只有在 users 表的 email 為空且 auth email 不為空時，才同步更新 users 表
            // 不要用 auth email 覆蓋 users 表的 email（因為 users 表的 email 可能更新）
            if (usersTableEmail.isEmpty && authEmail.isNotEmpty) {
              try {
                await _supabaseService.updateUserEmail(authEmail);
              } catch (e) {
                print('Warning: Failed to sync email: $e');
              }
            }
          }
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('Sign up error: $e');
      _isLoading = false;
      
      // 設置詳細的錯誤訊息
      final errorStr = e.toString();
      if (errorStr.contains('email_address_invalid') || errorStr.contains('Invalid email') || errorStr.contains('Invalid email format')) {
        _errorMessage = '註冊失敗：電子郵件格式無效';
      } else if (errorStr.contains('User already registered') || 
                 errorStr.contains('already registered') || 
                 errorStr.contains('Email already registered')) {
        _errorMessage = '註冊失敗：此電子郵件已被註冊';
      } else if (errorStr.contains('Password') || errorStr.contains('password')) {
        _errorMessage = '註冊失敗：密碼不符合要求（至少6個字符）';
      } else if (errorStr.contains('Email rate limit')) {
        _errorMessage = '註冊失敗：請求過於頻繁，請稍後再試';
      } else {
        _errorMessage = '註冊失敗，請稍後再試';
      }
      
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    // 先清除之前的狀態和錯誤訊息
    _currentUser = null;
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabaseService.signIn(email, password);
      
      if (response.user != null) {
        _currentUser = await _supabaseService.getUser(response.user!.id);
        
        // 如果 users 表中沒有記錄，從 auth metadata 創建用戶
        if (_currentUser == null) {
          final authUser = response.user!;
          final userMetadata = authUser.userMetadata;
          final role = userMetadata?['role'] as String?;
          
          // 如果 auth metadata 中沒有 role，嘗試再次查詢 users 表
          if (role == null) {
            print('Warning: No role found in auth metadata, retrying getUser...');
            await Future.delayed(const Duration(milliseconds: 500));
            _currentUser = await _supabaseService.getUser(response.user!.id);
            
            // 如果還是沒有，嘗試直接查詢（繞過可能的 RLS 問題）
            if (_currentUser == null) {
              print('Error: Could not retrieve user data from database, user may need to be created manually');
              _isLoading = false;
              notifyListeners();
              return false;
            }
          } else {
            _currentUser = UserModel(
              id: authUser.id,
              email: authUser.email ?? email,
              name: userMetadata?['name'] as String? ?? 'User',
              role: role,
              studentId: userMetadata?['student_id'] as String?,
            );
            
            // 嘗試將用戶資料插入 users 表（非阻塞）
            _supabaseService.createUserIfNotExists(_currentUser!).catchError((e) {
              // 如果記錄已存在，忽略錯誤
              if (e.toString().contains('duplicate key') || e.toString().contains('23505')) {
                print('User record already exists, skipping creation');
              } else {
                print('Warning: Failed to create user record: $e');
              }
            });
          }
        } else {
          // 如果從 users 表獲取成功，但 email 為空或與 auth 不一致，則更新
          final authUser = response.user!;
          if (_currentUser!.email.isEmpty || _currentUser!.email != (authUser.email ?? email)) {
            _currentUser = UserModel(
              id: _currentUser!.id,
              email: authUser.email ?? email,
              name: _currentUser!.name,
              role: _currentUser!.role,
              studentId: _currentUser!.studentId,
            );
            // 同步更新 users 表
            try {
              await _supabaseService.updateUserEmail(_currentUser!.email);
            } catch (e) {
              print('Warning: Failed to sync email: $e');
            }
          }
        }
        
        // 如果是學生，創建 session 記錄使用時間
        if (_currentUser != null && _currentUser!.role == 'student') {
          try {
            // 先結束任何未結束的 session
            await _supabaseService.endAllActiveSessions(_currentUser!.id);
            // 創建新的 session
            _currentSessionId = await _supabaseService.createSession(_currentUser!.id);
            print('Session created for student: ${_currentUser!.id}, session ID: $_currentSessionId');
          } catch (e) {
            print('Error creating session: $e');
            // 不影響登入流程，繼續執行
          }
        }
        
        // 確保狀態更新
        _isLoading = false;
        notifyListeners();
        
        // 額外確保 UI 更新
        await Future.delayed(const Duration(milliseconds: 100));
        notifyListeners();
        
        return true;
      }
      
      _isLoading = false;
      _errorMessage = '登入失敗：帳號或密碼錯誤';
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      print('Sign in AuthException: ${e.message}, statusCode: ${e.statusCode}');
      _currentUser = null;
      _isLoading = false;
      
      // 根據 Supabase AuthException 的錯誤碼和訊息設置錯誤訊息
      if (e.statusCode == '400' || 
          e.message.contains('Invalid login credentials') || 
          e.message.contains('invalid_credentials') ||
          e.message.contains('Invalid login')) {
        _errorMessage = '登入失敗：帳號或密碼錯誤';
      } else if (e.message.contains('Email not confirmed') || 
                 e.message.contains('email_not_confirmed')) {
        _errorMessage = '登入失敗：請先確認您的電子郵件';
      } else if (e.message.contains('Too many requests') || 
                 e.message.contains('rate_limit')) {
        _errorMessage = '登入失敗：嘗試次數過多，請稍後再試';
      } else if (e.message.contains('User not found')) {
        _errorMessage = '登入失敗：找不到此帳號';
      } else {
        _errorMessage = '登入失敗：${e.message}';
      }
      
      notifyListeners();
      return false;
    } catch (e) {
      print('Sign in error: $e');
      _currentUser = null;
      _isLoading = false;
      
      // 處理其他類型的錯誤
      final errorStr = e.toString();
      if (errorStr.contains('Invalid login credentials') || 
          errorStr.contains('invalid_credentials')) {
        _errorMessage = '登入失敗：帳號或密碼錯誤';
      } else {
        _errorMessage = '登入失敗：請檢查帳號密碼是否正確';
      }
      
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _supabaseService.signInWithGoogle();
      
      // signInWithOAuth 會開啟瀏覽器，所以這裡不需要等待
      // 認證完成後會通過深度連結返回，並觸發 onAuthStateChange
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      print('Google sign in error: $e');
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateEmail(String newEmail) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabaseService.updateUserEmail(newEmail);
      
      // 等待一下確保更新完成
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 重新獲取用戶資料（直接從 users 表獲取，確保獲取到最新的 email）
      final user = _supabaseService.getCurrentUser();
      if (user != null) {
        // 先從 users 表獲取最新的用戶資料
        _currentUser = await _supabaseService.getUser(user.id);
        if (_currentUser != null) {
          // 使用新 email 更新本地狀態（即使 auth email 還沒更新，users 表的 email 已經更新了）
          _currentUser = UserModel(
            id: _currentUser!.id,
            email: newEmail.toLowerCase().trim(), // 使用新 email
            name: _currentUser!.name,
            role: _currentUser!.role,
            studentId: _currentUser!.studentId,
          );
          print('Updated local user email to: ${_currentUser!.email}');
        } else {
          // 如果無法從 users 表獲取，至少更新本地狀態
          if (_currentUser != null) {
            _currentUser = UserModel(
              id: _currentUser!.id,
              email: newEmail.toLowerCase().trim(),
              name: _currentUser!.name,
              role: _currentUser!.role,
              studentId: _currentUser!.studentId,
            );
          }
        }
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Update email error: $e');
      _isLoading = false;
      
      // 設置詳細的錯誤訊息
      final errorStr = e.toString();
      if (errorStr.contains('Invalid email') || errorStr.contains('Invalid email format')) {
        _errorMessage = '電子郵件格式無效';
      } else if (errorStr.contains('Email already registered') || 
                 errorStr.contains('already registered')) {
        _errorMessage = '此電子郵件已被其他帳號使用';
      } else if (errorStr.contains('User not authenticated')) {
        _errorMessage = '用戶未登入，請重新登入';
      } else {
        _errorMessage = '更新失敗，請稍後再試';
      }
      
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabaseService.updateUserPassword(currentPassword, newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Update password error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateName(String newName) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabaseService.updateUserName(newName);
      
      // 更新本地用戶資料
      if (_currentUser != null) {
        _currentUser = UserModel(
          id: _currentUser!.id,
          email: _currentUser!.email,
          name: newName,
          role: _currentUser!.role,
          studentId: _currentUser!.studentId,
        );
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Update name error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateStudentId(String newStudentId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabaseService.updateUserStudentId(newStudentId);
      
      // 更新本地用戶資料
      if (_currentUser != null) {
        _currentUser = UserModel(
          id: _currentUser!.id,
          email: _currentUser!.email,
          name: _currentUser!.name,
          role: _currentUser!.role,
          studentId: newStudentId,
        );
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Update student ID error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // 如果是學生，結束當前的 session
      if (_currentUser != null && _currentUser!.role == 'student') {
        try {
          if (_currentSessionId != null) {
            await _supabaseService.endSession(_currentSessionId!);
          } else {
            // 如果沒有 session ID，結束所有活動的 session
            await _supabaseService.endAllActiveSessions(_currentUser!.id);
          }
          print('Session ended for student: ${_currentUser!.id}');
        } catch (e) {
          print('Error ending session: $e');
          // 不影響登出流程，繼續執行
        }
      }
      
      await _supabaseService.signOut();
      _currentUser = null;
      _currentSessionId = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Sign out error: $e');
      // 即使出錯也清除本地狀態
      _currentUser = null;
      _currentSessionId = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendSignupOTP(String email) async {
    // 使用一個標記來追蹤是否正在發送驗證碼
    // 但不設置 isLoading，避免觸發 AuthWrapper 跳轉
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabaseService.sendSignupOTP(email);
      notifyListeners();
      return true;
    } catch (e) {
      print('Send signup OTP error: $e');
      
      final errorStr = e.toString();
      if (errorStr.contains('email_address_invalid') || errorStr.contains('Invalid email')) {
        _errorMessage = '電子郵件格式無效';
      } else if (errorStr.contains('Email rate limit') || errorStr.contains('rate_limit')) {
        _errorMessage = '請求過於頻繁，請稍後再試';
      } else if (errorStr.contains('otp_disabled') || 
                 errorStr.contains('Signups not allowed') ||
                 errorStr.contains('無法發送驗證碼')) {
        _errorMessage = '無法發送驗證碼，請稍後再試';
      } else {
        _errorMessage = '發送驗證碼失敗，請稍後再試';
      }
      
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifySignupOTP(String email, String token) async {
    _isLoading = true;
    _errorMessage = null;
    
    // 保存當前用戶狀態（如果是修改信箱場景，需要保持登入狀態）
    final wasLoggedIn = _currentUser != null;
    final savedUser = _currentUser;
    
    notifyListeners();

    try {
      // 只有在註冊場景（未登入）時才清除用戶狀態
      if (!wasLoggedIn) {
        _currentUser = null;
      }
      
      // 如果之前已登入（修改信箱場景），傳遞 keepLoggedIn=true 以保持登入狀態
      final verified = await _supabaseService.verifySignupOTP(email, token, keepLoggedIn: wasLoggedIn);
      
      // 如果驗證成功且之前已登入，恢復用戶狀態
      if (verified && wasLoggedIn && savedUser != null) {
        _currentUser = savedUser;
      } else if (!wasLoggedIn) {
        // 註冊場景：確保清除登入狀態
        _currentUser = null;
      }
      
      _isLoading = false;
      notifyListeners();
      return verified;
    } catch (e) {
      print('Verify signup OTP error: $e');
      _isLoading = false;
      
      // 如果之前已登入，恢復用戶狀態（驗證失敗不應該影響已登入的用戶）
      if (wasLoggedIn && savedUser != null) {
        _currentUser = savedUser;
      } else {
        _currentUser = null;
      }
      
      final errorStr = e.toString();
      // 優先檢查後端 API 返回的具體錯誤訊息
      if (errorStr.contains('驗證碼錯誤')) {
        _errorMessage = '驗證碼錯誤';
      } else if (errorStr.contains('驗證碼已過期') || errorStr.contains('驗證碼不存在或已過期')) {
        _errorMessage = '驗證碼已過期，請重新發送';
      } else if (errorStr.contains('Invalid token') || errorStr.contains('invalid_token')) {
        _errorMessage = '驗證碼錯誤';
      } else if (errorStr.contains('Token expired') || errorStr.contains('expired')) {
        _errorMessage = '驗證碼已過期，請重新發送';
      } else if (errorStr.contains('User not found') || errorStr.contains('not found')) {
        _errorMessage = '驗證碼無效，請重新發送';
      } else {
        _errorMessage = '驗證失敗，請稍後再試';
      }
      
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabaseService.resetPasswordForEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Send password reset email error: $e');
      _isLoading = false;
      
      final errorStr = e.toString();
      if (errorStr.contains('email_address_invalid') || errorStr.contains('Invalid email')) {
        _errorMessage = '電子郵件格式無效';
      } else if (errorStr.contains('User not found') || errorStr.contains('not found')) {
        _errorMessage = '找不到此電子郵件地址的帳號';
      } else if (errorStr.contains('Email rate limit') || errorStr.contains('rate_limit')) {
        _errorMessage = '請求過於頻繁，請稍後再試';
      } else {
        _errorMessage = '發送重設密碼郵件失敗，請稍後再試';
      }
      
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabaseService.resetPassword(newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Reset password error: $e');
      _isLoading = false;
      
      final errorStr = e.toString();
      if (errorStr.contains('Password') || errorStr.contains('password')) {
        _errorMessage = '密碼不符合要求（至少6個字符）';
      } else if (errorStr.contains('Invalid token') || errorStr.contains('invalid_token')) {
        _errorMessage = '重設密碼連結無效或已過期';
      } else {
        _errorMessage = '重設密碼失敗，請稍後再試';
      }
      
      notifyListeners();
      return false;
    }
  }

  // 發送忘記密碼驗證碼
  Future<bool> sendForgotPasswordOTP(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabaseService.sendForgotPasswordOTP(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Send forgot password OTP error: $e');
      _isLoading = false;
      
      final errorStr = e.toString();
      if (errorStr.contains('email_address_invalid') || errorStr.contains('Invalid email')) {
        _errorMessage = '電子郵件格式無效';
      } else if (errorStr.contains('User not found') || errorStr.contains('not found')) {
        _errorMessage = '找不到此電子郵件地址的帳號';
      } else if (errorStr.contains('Email rate limit') || errorStr.contains('rate_limit')) {
        _errorMessage = '請求過於頻繁，請稍後再試';
      } else {
        _errorMessage = '發送驗證碼失敗，請稍後再試';
      }
      
      notifyListeners();
      return false;
    }
  }

  // 驗證忘記密碼 OTP
  Future<bool> verifyForgotPasswordOTP(String email, String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final verified = await _supabaseService.verifyForgotPasswordOTP(email, token);
      _isLoading = false;
      notifyListeners();
      return verified;
    } catch (e) {
      print('Verify forgot password OTP error: $e');
      _isLoading = false;
      
      final errorStr = e.toString();
      // 優先檢查後端 API 返回的具體錯誤訊息
      if (errorStr.contains('驗證碼錯誤')) {
        _errorMessage = '驗證碼錯誤';
      } else if (errorStr.contains('驗證碼已過期') || errorStr.contains('驗證碼不存在或已過期')) {
        _errorMessage = '驗證碼已過期，請重新發送';
      } else if (errorStr.contains('Invalid token') || errorStr.contains('invalid_token')) {
        _errorMessage = '驗證碼錯誤';
      } else if (errorStr.contains('Token expired') || errorStr.contains('expired')) {
        _errorMessage = '驗證碼已過期，請重新發送';
      } else if (errorStr.contains('User not found') || errorStr.contains('not found')) {
        _errorMessage = '驗證碼無效，請重新發送';
      } else {
        _errorMessage = '驗證失敗，請稍後再試';
      }
      
      notifyListeners();
      return false;
    }
  }

  // 更新密碼（用於忘記密碼流程，OTP 驗證後使用）
  Future<bool> updatePasswordAfterOTP(String email, String verificationCode, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabaseService.updatePassword(email, verificationCode, newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Update password after OTP error: $e');
      _isLoading = false;
      
      final errorStr = e.toString();
      if (errorStr.contains('Password') || errorStr.contains('password')) {
        _errorMessage = '密碼不符合要求（至少6個字符）';
      } else if (errorStr.contains('驗證碼錯誤')) {
        _errorMessage = '驗證碼錯誤，請重新驗證';
      } else if (errorStr.contains('驗證碼已過期') || errorStr.contains('驗證碼不存在或已過期')) {
        _errorMessage = '驗證碼已過期，請重新發送驗證碼';
      } else if (errorStr.contains('驗證碼') || errorStr.contains('code')) {
        _errorMessage = '驗證碼錯誤，請重新驗證';
      } else {
        _errorMessage = '更新密碼失敗，請稍後再試';
      }
      
      notifyListeners();
      return false;
    }
  }

  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final user = _supabaseService.getCurrentUser();
      if (user != null) {
        _currentUser = await _supabaseService.getUser(user.id);
        
        // 如果是學生，檢查並創建 session
        if (_currentUser != null && _currentUser!.role == 'student') {
          try {
            // 檢查是否有活動的 session
            final activeSessionId = await _supabaseService.getActiveSessionId(_currentUser!.id);
            if (activeSessionId == null) {
              // 如果沒有活動的 session，創建新的
              _currentSessionId = await _supabaseService.createSession(_currentUser!.id);
              print('Session created for student: ${_currentUser!.id}, session ID: $_currentSessionId');
            } else {
              _currentSessionId = activeSessionId;
              print('Active session found for student: ${_currentUser!.id}, session ID: $_currentSessionId');
            }
          } catch (e) {
            print('Error managing session in checkAuth: $e');
            // 不影響認證流程，繼續執行
          }
        }
        
        // 如果 users 表中沒有記錄，從 auth metadata 創建用戶
        if (_currentUser == null) {
          final userMetadata = user.userMetadata;
          final authEmail = user.email ?? '';
          _currentUser = UserModel(
            id: user.id,
            email: authEmail,
            name: userMetadata?['name'] as String? ?? 'User',
            role: userMetadata?['role'] as String? ?? 'student',
            studentId: userMetadata?['student_id'] as String?,
          );
          
          // 嘗試將用戶資料插入 users 表
          try {
            await _supabaseService.createUserIfNotExists(_currentUser!);
            // 重新獲取用戶資料
            _currentUser = await _supabaseService.getUser(user.id);
          } catch (e) {
            print('Warning: Failed to create user record: $e');
          }
        } else {
          // 如果從 users 表獲取成功，優先使用 users 表的 email（因為它可能比 auth email 更新）
          // 只有在 users 表的 email 為空時，才使用 auth email 並同步
          final authEmail = user.email ?? '';
          final usersTableEmail = _currentUser!.email;
          
          // 優先使用 users 表的 email，因為它可能比 auth email 更新（例如剛修改過 email）
          // 只有在 users 表的 email 為空時，才使用 auth email
          final finalEmail = usersTableEmail.isNotEmpty ? usersTableEmail : authEmail;
          
          // 只有在 email 真的不同時才更新（避免不必要的更新）
          if (_currentUser!.email != finalEmail) {
            _currentUser = UserModel(
              id: _currentUser!.id,
              email: finalEmail,
              name: _currentUser!.name,
              role: _currentUser!.role,
              studentId: _currentUser!.studentId,
            );
            
            // 只有在 users 表的 email 為空且 auth email 不為空時，才同步更新 users 表
            // 不要用 auth email 覆蓋 users 表的 email（因為 users 表的 email 可能更新）
            if (usersTableEmail.isEmpty && authEmail.isNotEmpty) {
              try {
                await _supabaseService.updateUserEmail(authEmail);
              } catch (e) {
                print('Warning: Failed to sync email: $e');
              }
            }
          }
        }
      } else {
        // 如果沒有用戶，確保清除狀態
        _currentUser = null;
        _currentSessionId = null;
      }
    } catch (e) {
      print('checkAuth error: $e');
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

