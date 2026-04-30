import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/user_model.dart';
import '../models/grammar_topic_model.dart';
import '../models/question_model.dart';
import '../models/badge_model.dart';
import '../models/grammar_key_point_model.dart';
import '../models/reminder_model.dart';
import '../models/class_model.dart';
import '../config/app_config.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  
  // 獲取後端 API URL（統一使用 AppConfig 中的配置）
  String get _backendUrl {
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

  // 檢查信箱是否已被使用
  Future<bool> isEmailTaken(String email, {String? excludeUserId}) async {
    try {
      final cleanedEmail = email.trim().toLowerCase();
      
      // 檢查 users 表（主要檢查點）
      // 先獲取所有用戶（或使用合理的限制），然後在應用層面進行不區分大小寫的匹配
      // 這樣可以處理 email 欄位可能為空或格式不一致的情況
      var query = _client
          .from('users')
          .select('id, email')
          .limit(1000); // 設置合理的限制
      
      final response = await query;
      
      print('Found ${response.length} users in database');
      
      // 如果查詢返回空結果，可能是 RLS 政策限制
      if (response.isEmpty) {
        print('Warning: Query returned empty result. This might be due to RLS policy restrictions.');
        print('Please run database/allow_email_check_policy.sql to allow email checking.');
        // 如果無法查詢，為了安全起見，假設信箱已被使用
        return true;
      }
      
      // 在應用層面進行不區分大小寫的匹配
      for (var user in response) {
        final userEmail = (user['email'] as String?)?.trim().toLowerCase();
        print('Checking user ${user['id']}: email = "$userEmail"');
        
        if (userEmail != null && userEmail.isNotEmpty && userEmail == cleanedEmail) {
          final userId = user['id'] as String;
          print('Found matching email for user: $userId (email: $userEmail)');
          
          // 如果要排除的用戶 ID 與找到的用戶 ID 相同，則不算被使用
          if (excludeUserId != null && userId == excludeUserId) {
            print('Email belongs to excluded user, returning false');
            return false;
          }
          print('Email is taken by user: $userId');
          return true;
        }
      }
      
      print('Email "$cleanedEmail" not found in users table after checking ${response.length} users');
      
      // 如果 users 表中沒有找到，嘗試通過 Supabase Auth API 檢查
      // 注意：在客戶端無法直接查詢 auth.users，但可以通過嘗試 signUp 來檢查
      // 不過這會創建用戶，所以我們不這樣做
      // 更好的方法是檢查 Supabase Auth 的用戶（但需要 admin API）
      
      return false;
    } catch (e, stackTrace) {
      print('Error checking email: $e');
      print('Stack trace: $stackTrace');
      // 如果檢查失敗，為了安全起見，假設信箱已被使用
      return true;
    }
  }

  // Authentication
  Future<AuthResponse> signUp(String email, String password, String name, String role, {String? studentId}) async {
    // 清理和驗證 Email
    final cleanedEmail = email.trim().toLowerCase();
    
    // 基本 Email 格式驗證
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(cleanedEmail)) {
      throw Exception('Invalid email format');
    }
    
    // 檢查信箱是否已被使用
    final emailTaken = await isEmailTaken(cleanedEmail);
    if (emailTaken) {
      throw Exception('Email already registered');
    }
    
    final response = await _client.auth.signUp(
      email: cleanedEmail,
      password: password,
      emailRedirectTo: null, // 不需要重定向
      data: {
        'name': name,
        'role': role,
        'student_id': studentId,
      },
    );

    // 注意：用戶記錄應該由 Database Trigger 自動創建
    // 等待一下讓 Trigger 有時間執行
    if (response.user != null) {
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // 驗證記錄是否已創建
      try {
        final checkResult = await _client
            .from('users')
            .select('id')
            .eq('id', response.user!.id)
            .maybeSingle();
        
        if (checkResult == null) {
          print('Warning: User record not found after signup, Trigger may not be working');
          // 嘗試手動創建（如果 Trigger 失敗）
          try {
            await _client.from('users').insert({
              'id': response.user!.id,
              'email': email,
              'name': name,
              'role': role,
              'student_id': studentId,
            });
            print('Successfully created user record manually');
          } catch (insertError) {
            print('Error creating user record manually: $insertError');
            // 即使失敗也繼續，後續可以通過 createUserIfNotExists 處理
          }
        } else {
          print('User record successfully created (likely by Trigger)');
        }
      } catch (checkError) {
        print('Error checking user record: $checkError');
      }
    }

    return response;
  }

  Future<AuthResponse> signIn(String email, String password) async {
    // Supabase 的 signInWithPassword 在錯誤時會直接拋出異常
    // 不需要額外檢查，讓異常自然傳播到上層
    return await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  // 依學號查找學生 email（僅學生）
  Future<String?> getStudentEmailByStudentId(String studentId) async {
    final normalizedStudentId = studentId.trim();
    if (normalizedStudentId.isEmpty) return null;

    try {
      final response = await _client
          .from('users')
          .select('email')
          .eq('role', 'student')
          .eq('student_id', normalizedStudentId)
          .maybeSingle();

      if (response == null) return null;
      final email = (response['email'] as String?)?.trim();
      if (email == null || email.isEmpty) return null;
      return email;
    } catch (e) {
      print('Error getting email by student_id: $e');
      return null;
    }
  }

  // 登入分流：有 @ 當 email，否則當學號（學生）
  Future<AuthResponse> signInWithIdentifier(String identifier, String password) async {
    final normalized = identifier.trim();
    if (normalized.isEmpty) {
      throw Exception('請輸入帳號');
    }

    if (normalized.contains('@')) {
      return await signIn(normalized, password);
    }

    final mappedEmail = await getStudentEmailByStudentId(normalized);
    if (mappedEmail == null) {
      throw Exception('找不到此學號對應的學生帳號');
    }

    return await signIn(mappedEmail, password);
  }

  Future<bool> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AppConfig.getDeepLinkUrl('login-callback'),
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return true;
    } catch (e) {
      print('Google sign in error: $e');
      return false;
    }
  }

  Future<bool> signInWithApple() async {
    try {
      // 在 iOS 上使用原生 Sign in with Apple（直接彈出視窗）
      if (Platform.isIOS) {
        // 使用原生 Sign in with Apple
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

        // 使用 HTTP 請求直接調用 Supabase API 進行認證
        final supabaseUrl = AppConfig.supabaseUrl;
        final response = await http.post(
          Uri.parse('$supabaseUrl/auth/v1/token?grant_type=id_token'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': AppConfig.supabaseAnonKey,
          },
          body: jsonEncode({
            'provider': 'apple',
            'id_token': appleCredential.identityToken,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          // 使用獲取的 refresh token 更新 Supabase 客戶端
          await _client.auth.setSession(data['refresh_token']);
          // Apple 僅在首次授權時回傳 email（含 relay）與姓名，之後登入不會再帶，故在此寫入避免欄位空白
          final userId = _client.auth.currentUser?.id;
          if (userId != null) {
            await _syncAppleCredentialToUser(
              userId: userId,
              email: appleCredential.email,
              givenName: appleCredential.givenName,
              familyName: appleCredential.familyName,
            );
          }
          return true;
        } else {
          print('Apple sign in API error: ${response.statusCode} - ${response.body}');
          return false;
        }
      } else {
        // Android 或其他平台使用 OAuth 流程（開啟瀏覽器）
        await _client.auth.signInWithOAuth(
          OAuthProvider.apple,
          redirectTo: AppConfig.getDeepLinkUrl('login-callback'),
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
        return true;
      }
    } catch (e) {
      print('Apple sign in error: $e');
      return false;
    }
  }

  /// 將 Apple 登入時取得的 email（含 relay）／姓名同步到 users 表與 auth。僅在首次授權時有值。
  Future<void> _syncAppleCredentialToUser({
    required String userId,
    String? email,
    String? givenName,
    String? familyName,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (email != null && email.trim().isNotEmpty) {
        updates['email'] = email.trim();
      }
      final nameParts = [givenName, familyName]
          .where((s) => s != null && s.toString().trim().isNotEmpty)
          .map((s) => s.toString().trim())
          .toList();
      if (nameParts.isNotEmpty) {
        updates['name'] = nameParts.join(' ');
      }
      if (updates.length <= 1) return;

      await _client.from('users').update(updates).eq('id', userId);

      final authData = <String, String>{};
      if (nameParts.isNotEmpty) {
        final fullName = nameParts.join(' ');
        authData['full_name'] = fullName;
        authData['name'] = fullName;
      }
      try {
        if (email != null && email.trim().isNotEmpty) {
          await _client.auth.updateUser(UserAttributes(email: email.trim()));
        }
        if (authData.isNotEmpty) {
          await _client.auth.updateUser(UserAttributes(data: authData));
        }
      } catch (_) {}
    } catch (e) {
      print('_syncAppleCredentialToUser error: $e');
    }
  }

  Future<void> signOut() async {
    try {
      // 清除所有 session 和本地存儲
      await _client.auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
      // 即使出錯也繼續，確保清除本地狀態
    }
  }

  // 發送重設密碼郵件
  Future<void> resetPasswordForEmail(String email) async {
    final cleanedEmail = email.trim().toLowerCase();
    
    // 基本 Email 格式驗證
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(cleanedEmail)) {
      throw Exception('Invalid email format');
    }
    
    await _client.auth.resetPasswordForEmail(
      cleanedEmail,
      redirectTo: AppConfig.getDeepLinkUrl('reset-password'),
    );
  }

  // 發送註冊驗證碼（優先使用後端 API，失敗時回退到 Supabase OTP）
  Future<void> sendSignupOTP(String email) async {
    final cleanedEmail = email.trim().toLowerCase();
    
    // 基本 Email 格式驗證
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(cleanedEmail)) {
      throw Exception('Invalid email format');
    }
    
    // 優先嘗試使用後端 API
    try {
      final backendUrl = _backendUrl; // 根據平台自動選擇正確的 URL
      print('嘗試連接到後端 API: $backendUrl/api/send-verification-code');
      final response = await http.post(
        Uri.parse('$backendUrl/api/send-verification-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': cleanedEmail}),
      ).timeout(const Duration(seconds: 5)); // 縮短超時時間
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Backend API 響應: $data');
        
        // 檢查是否成功
        if (data['success'] == true) {
          // 後端 API 成功發送驗證碼到電子郵件
          print('驗證碼已通過後端 API 發送到電子郵件');
          // 注意：驗證碼只會發送到電子郵件，不會在應用程式中顯示
          return; // 成功，直接返回
        } else {
          // 不洩露後端詳細錯誤資訊
          print('後端 API 返回失敗: statusCode=${response.statusCode}, body=${response.body}');
          throw Exception('操作失敗');
        }
      } else {
        // 處理非 200 狀態碼，不洩露後端詳細錯誤資訊
        try {
          jsonDecode(response.body); // 嘗試解析，但不使用結果
        } catch (_) {
          // JSON 解析失敗，繼續
        }
        print('後端 API 錯誤: statusCode=${response.statusCode}, body=${response.body}');
        throw Exception('操作失敗');
      }
    } catch (e) {
      final errorStr = e.toString();
      
      // 檢查是否是連接錯誤（後端未運行）
      final isConnectionError = errorStr.contains('Connection refused') ||
          errorStr.contains('SocketException') ||
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('Network is unreachable');
      
      if (isConnectionError) {
        print('Backend API 未運行，嘗試使用 Supabase OTP: $e');
      } else {
        print('Backend API failed, falling back to Supabase OTP: $e');
      }
      // 後端 API 失敗，回退到 Supabase OTP
    }
    
    // 回退到 Supabase OTP（如果後端 API 不可用）
    try {
      // 嘗試使用 signInWithOtp 發送 OTP
      // 注意：即使 shouldCreateUser: false，Supabase 仍需要 "Enable sign ups" 啟用
      await _client.auth.signInWithOtp(
        email: cleanedEmail,
        shouldCreateUser: false, // 僅發送 OTP，不創建用戶
      );
      print('Supabase OTP 發送成功');
      return; // Supabase OTP 成功
    } catch (e) {
      // 如果 Supabase OTP 也失敗，檢查是否是配置問題
      final errorStr = e.toString();
      print('Supabase OTP 失敗: $e');
      
      if (errorStr.contains('otp_disabled') || 
          errorStr.contains('Signups not allowed') ||
          errorStr.contains('422')) {
        // 提供詳細的錯誤訊息和解決方案
        throw Exception(
          '無法發送驗證碼。\n\n'
          '後端 API 狀態：未運行\n'
          'Supabase OTP 狀態：失敗\n\n'
          '請選擇以下方案之一：\n\n'
          '【方案 1】啟動後端服務（推薦，最簡單）\n'
          '1. 打開終端機\n'
          '2. cd backend\n'
          '3. uvicorn main:app --reload\n'
          '4. 確認服務運行後，驗證碼會顯示在終端和應用程式中\n\n'
          '【方案 2】檢查 Supabase 設定\n'
          '1. 登入 Supabase Dashboard\n'
          '2. Authentication > Providers > Email\n'
          '3. 確認以下設定都已啟用：\n'
          '   - Enable Email provider ✓\n'
          '   - Enable sign ups ✓\n'
          '4. 保存設定並等待幾秒鐘讓設定生效\n'
          '5. 重新嘗試發送驗證碼'
        );
      }
      rethrow;
    }
  }

  // 驗證註冊 OTP（優先使用後端 API，失敗時回退到 Supabase OTP）
  // keepLoggedIn: 如果為 true，驗證失敗時不會登出已登入的用戶（用於修改信箱場景）
  Future<bool> verifySignupOTP(String email, String token, {bool keepLoggedIn = false}) async {
    final cleanedEmail = email.trim().toLowerCase();
    
    // 優先嘗試使用後端 API
    try {
      final backendUrl = _backendUrl; // 根據平台自動選擇正確的 URL
      print('嘗試連接到後端 API: $backendUrl/api/verify-code');
      final response = await http.post(
        Uri.parse('$backendUrl/api/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanedEmail,
          'code': token,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('Backend API verification successful');
          return true; // 後端 API 驗證成功
        } else {
          // 如果 success 為 false，檢查是否有錯誤訊息
          // 不洩露後端詳細錯誤資訊
          print('Backend API verification failed: statusCode=${response.statusCode}, body=${response.body}');
          throw Exception('驗證失敗');
        }
      } else {
        // 不洩露後端詳細錯誤資訊
        jsonDecode(response.body); // 嘗試解析，但不使用結果
        print('Backend API verification failed: statusCode=${response.statusCode}, body=${response.body}');
        throw Exception('驗證失敗');
      }
    } catch (e) {
      print('Backend API verification failed, falling back to Supabase OTP: $e');
      // 後端 API 失敗，回退到 Supabase OTP
    }
    
    // 回退到 Supabase OTP（如果後端 API 不可用）
    try {
      // 檢查當前是否有登入的用戶
      final currentUser = _client.auth.currentUser;
      final wasLoggedIn = currentUser != null;
      
      // 使用 email 類型驗證，這樣不會自動登入
      final response = await _client.auth.verifyOTP(
        email: cleanedEmail,
        token: token,
        type: OtpType.email,
      );
      
      // 如果驗證成功，但之前沒有登入（註冊場景），則登出
      // 如果之前已經登入（修改信箱場景），則保持登入狀態
      if (response.user != null && !wasLoggedIn) {
        print('OTP verified successfully, signing out to prevent auto-login (registration scenario)...');
        await _client.auth.signOut();
        // 等待一下確保登出完成
        await Future.delayed(const Duration(milliseconds: 100));
      } else if (response.user != null && wasLoggedIn) {
        print('OTP verified successfully, keeping user logged in (email update scenario)...');
        // 保持登入狀態，不登出
      }
      
      return true; // 驗證成功
    } catch (e) {
      print('Verify OTP error: $e');
      // 如果驗證失敗，只有在之前沒有登入或 keepLoggedIn 為 false 時才登出
      // 如果之前已經登入且 keepLoggedIn 為 true，保持登入狀態
      final currentUser = _client.auth.currentUser;
      if ((!keepLoggedIn || currentUser == null) && currentUser != null) {
        try {
          await _client.auth.signOut();
        } catch (_) {
          // 忽略登出錯誤
        }
      }
      rethrow;
    }
  }

  // 重設密碼
  Future<void> resetPassword(String newPassword) async {
    // Supabase 會自動處理重設密碼 token（如果有的話）
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // 發送忘記密碼驗證碼（優先使用後端 API，失敗時回退到 Supabase OTP）
  Future<void> sendForgotPasswordOTP(String email) async {
    final cleanedEmail = email.trim().toLowerCase();
    
    // 基本 Email 格式驗證
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(cleanedEmail)) {
      throw Exception('Invalid email format');
    }
    
    // 優先嘗試使用後端 API（發送數字驗證碼）
    try {
      final backendUrl = _backendUrl;
      print('嘗試連接到後端 API: $backendUrl/api/send-verification-code');
      final response = await http.post(
        Uri.parse('$backendUrl/api/send-verification-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': cleanedEmail}),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Backend API 響應: $data');
        
        if (data['success'] == true) {
          // 後端 API 成功發送驗證碼到電子郵件
          print('驗證碼已通過後端 API 發送到電子郵件');
          // 注意：驗證碼只會發送到電子郵件，不會在應用程式中顯示
          return; // 成功，直接返回
        } else {
          // 不洩露後端詳細錯誤資訊
          print('後端 API 返回失敗: statusCode=${response.statusCode}, body=${response.body}');
          throw Exception('操作失敗');
        }
      } else {
        // 處理非 200 狀態碼，不洩露後端詳細錯誤資訊
        try {
          jsonDecode(response.body); // 嘗試解析，但不使用結果
        } catch (_) {
          // JSON 解析失敗，繼續
        }
        print('後端 API 錯誤: statusCode=${response.statusCode}, body=${response.body}');
        throw Exception('操作失敗');
      }
    } catch (e) {
      final errorStr = e.toString();
      
      // 檢查是否是連接錯誤（後端未運行）
      final isConnectionError = errorStr.contains('Connection refused') ||
          errorStr.contains('SocketException') ||
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('Network is unreachable');
      
      if (isConnectionError) {
        print('Backend API 未運行，嘗試使用 Supabase OTP: $e');
      } else {
        print('Backend API failed, falling back to Supabase OTP: $e');
      }
      // 後端 API 失敗，回退到 Supabase OTP
    }
    
    // 回退到 Supabase OTP（如果後端 API 不可用）
    // 注意：Supabase 的 signInWithOtp 默認發送 Magic Link，不是數字驗證碼
    // 需要在 Supabase Dashboard 中配置才能發送數字驗證碼
    try {
      await _client.auth.signInWithOtp(
        email: cleanedEmail,
        shouldCreateUser: false, // 不創建新用戶，僅發送 OTP
      );
      print('Supabase OTP 發送成功（注意：可能是 Magic Link 而不是數字驗證碼）');
      return;
    } catch (e) {
      print('Supabase OTP 失敗: $e');
      final errorStr = e.toString();
      if (errorStr.contains('otp_disabled') || 
          errorStr.contains('Email rate limit') ||
          errorStr.contains('rate_limit')) {
        throw Exception(
          'Supabase OTP 狀態：失敗\n\n'
          '可能的原因：\n'
          '1. Supabase OTP 功能未啟用\n'
          '2. 請求過於頻繁\n'
          '3. 請確保後端 API 正在運行以使用數字驗證碼功能\n\n'
          '錯誤詳情：$e'
        );
      }
      rethrow;
    }
  }

  // 驗證忘記密碼 OTP（優先使用後端 API，失敗時回退到 Supabase OTP）
  Future<bool> verifyForgotPasswordOTP(String email, String token) async {
    final cleanedEmail = email.trim().toLowerCase();
    
    // 優先嘗試使用後端 API
    try {
      final backendUrl = _backendUrl;
      print('嘗試連接到後端 API: $backendUrl/api/verify-code');
      final response = await http.post(
        Uri.parse('$backendUrl/api/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanedEmail,
          'code': token,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // 後端 API 驗證成功
          // 現在我們需要通過 Supabase 登入用戶才能更新密碼
          // 方案：發送一個 Supabase OTP，然後立即驗證它來登入用戶
          try {
            // 發送 Supabase OTP
            await _client.auth.signInWithOtp(
              email: cleanedEmail,
              shouldCreateUser: false,
            );
            
            // 等待一下讓 OTP 發送完成
            await Future.delayed(const Duration(seconds: 2));
            
            // 注意：這裡我們無法立即驗證，因為 Supabase OTP 和後端驗證碼不同
            // 所以我們返回 true，表示後端驗證成功
            // 更新密碼時會使用後端 API，不需要 Supabase 登入
            print('後端驗證成功，可以通過後端 API 更新密碼');
            return true;
          } catch (e) {
            print('發送 Supabase OTP 失敗（這不影響後端驗證）: $e');
            // 即使 Supabase OTP 失敗，後端驗證仍然成功
            // 更新密碼時會使用後端 API
            return true;
          }
        }
      } else {
        // 不洩露後端詳細錯誤資訊
        jsonDecode(response.body); // 嘗試解析，但不使用結果
        print('後端 API 錯誤: statusCode=${response.statusCode}, body=${response.body}');
        throw Exception('驗證失敗');
      }
    } catch (e) {
      print('Backend API verification failed, falling back to Supabase OTP: $e');
      // 後端 API 失敗，回退到 Supabase OTP
    }
    
    // 回退到 Supabase OTP（如果後端 API 不可用）
    try {
      // 驗證 OTP（這會自動登入用戶）
      final response = await _client.auth.verifyOTP(
        email: cleanedEmail,
        token: token,
        type: OtpType.email,
      );
      
      // 如果驗證成功，返回 true（用戶已自動登入）
      return response.user != null;
    } catch (e) {
      print('Verify forgot password OTP error: $e');
      rethrow;
    }
  }

  // 更新密碼（用於忘記密碼流程，使用後端 API）
  Future<void> updatePassword(String email, String verificationCode, String newPassword) async {
    final cleanedEmail = email.trim().toLowerCase();
    
    // 優先嘗試使用後端 API
    try {
      final backendUrl = _backendUrl;
      print('嘗試連接到後端 API: $backendUrl/api/reset-password');
      final response = await http.post(
        Uri.parse('$backendUrl/api/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanedEmail,
          'code': verificationCode,
          'new_password': newPassword,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('密碼已通過後端 API 更新');
          return; // 成功
        } else {
          // 不洩露後端詳細錯誤資訊
          print('後端 API 返回失敗: statusCode=${response.statusCode}, body=${response.body}');
          throw Exception('操作失敗');
        }
      } else {
        // 不洩露後端詳細錯誤資訊
        jsonDecode(response.body); // 嘗試解析，但不使用結果
        print('後端 API 錯誤: statusCode=${response.statusCode}, body=${response.body}');
        throw Exception('更新密碼失敗');
      }
    } catch (e) {
      print('Backend API reset password failed: $e');
      // 如果後端 API 失敗，嘗試使用 Supabase（需要用戶已登入）
      // 但這在忘記密碼流程中可能不可用
      if (_client.auth.currentUser != null) {
        await _client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
      } else {
        rethrow;
      }
    }
  }

  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  // User
  Future<UserModel?> getUser(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      
      final userModel = UserModel.fromJson(response);
      
      // 如果 users 表中的 email 為空，從 auth 獲取
      if (userModel.email.isEmpty) {
        final authUser = _client.auth.currentUser;
        if (authUser != null && authUser.email != null) {
          // 更新 users 表的 email
          try {
            await _client.from('users').update({
              'email': authUser.email,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', userId);
          } catch (e) {
            print('Warning: Failed to update email in users table: $e');
          }
          
          return UserModel(
            id: userModel.id,
            email: authUser.email!,
            name: userModel.name,
            role: userModel.role,
            studentId: userModel.studentId,
          );
        }
      }
      
      return userModel;
    } catch (e) {
      print('Error getting user $userId: $e');
      // 如果查詢失敗（可能是 RLS 政策問題），直接返回 null
      // 讓上層代碼處理，避免無限重試
      return null;
    }
  }

  // 創建用戶記錄（如果不存在）
  Future<void> createUserIfNotExists(UserModel user) async {
    try {
      // 先檢查用戶是否存在（使用 try-catch 避免 RLS 政策問題影響檢查）
      UserModel? existing;
      try {
        existing = await getUser(user.id);
      } catch (e) {
        // 如果查詢失敗（可能是 RLS 政策問題），假設記錄不存在，繼續嘗試插入
        print('Warning: Could not check if user exists: $e');
        existing = null;
      }
      
      if (existing != null) {
        return;
      }

      // 如果不存在，創建新記錄
      try {
        final insertResult = await _client.from('users').insert({
          'id': user.id,
          'email': user.email,
          'name': user.name,
          'role': user.role,
          'student_id': user.studentId,
        }).select();
        print('Successfully created user record via createUserIfNotExists: ${insertResult.length} row(s)');
      } catch (insertError) {
        // 如果插入失敗，檢查是否是因為記錄已存在
        final errorStr = insertError.toString();
        if (errorStr.contains('duplicate key') || errorStr.contains('23505')) {
          // 記錄已存在，這是正常的，忽略錯誤
          print('User record already exists, skipping insert');
        } else {
          // 其他錯誤，記錄詳細信息
          print('Error inserting user record in createUserIfNotExists: $insertError');
          print('User ID: ${user.id}');
          print('Email: ${user.email}');
          // 不重新拋出錯誤，讓流程繼續
        }
      }
    } catch (e) {
      // 如果插入失敗（可能是因為記錄已存在或其他原因），記錄錯誤但不影響流程
      print('createUserIfNotExists error: $e');
    }
  }

  // 更新用戶電子郵件
  Future<void> updateUserEmail(String newEmail) async {
    // 清理和驗證 Email
    final cleanedEmail = newEmail.trim().toLowerCase();
    
    // 基本 Email 格式驗證
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(cleanedEmail)) {
      throw Exception('Invalid email format');
    }
    
    // 獲取當前用戶 ID
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    
    // 檢查新信箱是否已被其他用戶使用（排除當前用戶）
    final emailTaken = await isEmailTaken(cleanedEmail, excludeUserId: userId);
    if (emailTaken) {
      throw Exception('Email already registered');
    }
    
    print('Updating email from ${_client.auth.currentUser?.email} to $cleanedEmail');
    
    try {
      // 使用後端 API 更新 email（需要 JWT Token 驗證和老師角色）
      try {
        // 獲取當前用戶的 JWT Token
        final session = _client.auth.currentSession;
        if (session == null || session.accessToken.isEmpty) {
          throw Exception('請先登入');
        }
        
        final backendUrl = _backendUrl;
        print('嘗試連接到後端 API: $backendUrl/api/admin/update-student-email');
        final response = await http.post(
          Uri.parse('$backendUrl/api/admin/update-student-email'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
          body: jsonEncode({
            'student_id': userId,
            'new_email': cleanedEmail,
          }),
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            print('電子郵件已通過後端 API 更新: ${data['old_email']} -> ${data['new_email']}');
            // 後端 API 已經同時更新了 users 表和 auth.users
            return; // 成功，直接返回
          } else {
            // 不洩露後端詳細錯誤資訊
          print('後端 API 返回失敗: statusCode=${response.statusCode}, body=${response.body}');
          throw Exception('操作失敗');
          }
        } else {
          // 不洩露後端詳細錯誤資訊
          jsonDecode(response.body); // 嘗試解析，但不使用結果
          print('後端 API 錯誤: statusCode=${response.statusCode}, body=${response.body}');
          throw Exception('更新電子郵件失敗');
        }
      } catch (backendError) {
        print('後端 API 更新 email 失敗: $backendError');
        // 如果後端 API 失敗，回退到直接更新 users 表（但 auth.users 不會更新）
        print('警告：無法通過後端 API 更新 email，嘗試直接更新 users 表');
        
        // 更新 users 表
        await _client.from('users').update({
          'email': cleanedEmail,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
        
        print('Users table updated successfully to: $cleanedEmail');
        
        // 嘗試更新 Supabase Auth 的 email（可能失敗，因為需要確認）
        try {
          final response = await _client.auth.updateUser(
            UserAttributes(email: cleanedEmail),
          );
          
          print('Auth email update response: ${response.user?.email}');
          
          // 檢查是否真的更新了
          if (response.user?.email?.toLowerCase() == cleanedEmail) {
            print('Auth email updated successfully');
          } else {
            print('Warning: Auth email may require confirmation. Current auth email: ${response.user?.email}');
            throw Exception('Auth email 需要確認，請檢查您的電子郵件');
          }
        } catch (authError) {
          print('Warning: Failed to update auth email: $authError');
          throw Exception('無法更新認證系統的電子郵件。請聯繫管理員或稍後再試。');
        }
      }
      
    } catch (e) {
      print('Error updating email: $e');
      rethrow;
    }
  }

  // 驗證目前密碼
  Future<bool> verifyCurrentPassword(String password) async {
    Session? originalSession;
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser?.email == null) {
        return false;
      }
      
      // 保存當前會話
      originalSession = _client.auth.currentSession;
      
      // 嘗試使用目前密碼登入來驗證
      await _client.auth.signInWithPassword(
        email: currentUser!.email!,
        password: password,
      );
      
      // 如果登入成功，說明密碼正確
      // 恢復原會話，避免觸發認證狀態變化
      if (originalSession != null && originalSession.refreshToken != null) {
        try {
          await _client.auth.setSession(originalSession.refreshToken!);
        } catch (e) {
          print('Warning: Failed to restore session: $e');
          // 如果恢復失敗，嘗試用新的會話（雖然會觸發狀態變化，但至少不會丟失認證）
        }
      }
      
      return true;
    } catch (e) {
      // 如果登入失敗，說明密碼錯誤
      // 嘗試恢復原會話
      if (originalSession != null && originalSession.refreshToken != null) {
        try {
          await _client.auth.setSession(originalSession.refreshToken!);
        } catch (e) {
          print('Warning: Failed to restore session after verification failure: $e');
        }
      }
      return false;
    }
  }

  // 更新用戶密碼
  Future<void> updateUserPassword(String currentPassword, String newPassword) async {
    // 先驗證目前密碼
    final isValid = await verifyCurrentPassword(currentPassword);
    if (!isValid) {
      throw Exception('目前密碼錯誤');
    }
    
    // 驗證通過後更新密碼
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // 更新用戶姓名
  Future<void> updateUserName(String newName) async {
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      await _client.from('users').update({
        'name': newName,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      
      // 更新 auth metadata
      await _client.auth.updateUser(
        UserAttributes(data: {'name': newName}),
      );
    }
  }

  // 更新用戶學號
  Future<void> updateUserStudentId(String newStudentId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      await _client.from('users').update({
        'student_id': newStudentId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      
      // 更新 auth metadata
      await _client.auth.updateUser(
        UserAttributes(data: {'student_id': newStudentId}),
      );
    }
  }

  // =====================================================
  // Class Management (班級管理)
  // =====================================================

  // 生成唯一的 6 位數字班級代碼
  Future<String> _generateUniqueClassCode() async {
    final random = Random();
    String code;
    bool exists = true;
    
    while (exists) {
      // 生成 6 位數字代碼（100000-999999）
      code = (random.nextInt(900000) + 100000).toString();
      
      // 檢查是否已存在
      final response = await _client
          .from('classes')
          .select('id')
          .eq('code', code)
          .maybeSingle();
      
      exists = response != null;
      
      if (!exists) {
        return code;
      }
    }
    
    // 這行不應該被執行到，但為了編譯器需要返回值
    throw Exception('無法生成唯一的班級代碼');
  }

  // 獲取可管理的所有班級（共同管理模式）
  Future<List<ClassModel>> getTeacherClasses(String teacherId) async {
    try {
      final response = await _client
          .from('classes')
          .select()
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => ClassModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting teacher classes: $e');
      return [];
    }
  }

  // 通過代碼獲取班級
  Future<ClassModel?> getClassByCode(String code) async {
    try {
      final response = await _client
          .from('classes')
          .select()
          .eq('code', code)
          .maybeSingle();
      
      if (response != null) {
        return ClassModel.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error getting class by code: $e');
      return null;
    }
  }

  // 通過 ID 獲取班級
  Future<ClassModel?> getClassById(String classId) async {
    try {
      final response = await _client
          .from('classes')
          .select()
          .eq('id', classId)
          .maybeSingle();
      
      if (response != null) {
        return ClassModel.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error getting class by id: $e');
      return null;
    }
  }

  // 創建班級
  Future<ClassModel?> createClass(String name, String teacherId) async {
    try {
      final code = await _generateUniqueClassCode();
      final now = DateTime.now().toIso8601String();
      
      final response = await _client
          .from('classes')
          .insert({
            'name': name,
            'code': code,
            'teacher_id': teacherId,
            'created_at': now,
            'updated_at': now,
          })
          .select()
          .single();
      
      return ClassModel.fromJson(response);
    } catch (e) {
      print('Error creating class: $e');
      return null;
    }
  }

  // 更新班級名稱
  Future<bool> updateClass(String classId, String name) async {
    try {
      await _client
          .from('classes')
          .update({
            'name': name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', classId);
      return true;
    } catch (e) {
      print('Error updating class: $e');
      return false;
    }
  }

  // 更新班級的 AI 小幫手開關（老師端）
  Future<bool> updateClassAiHelperEnabled(String classId, bool enabled) async {
    try {
      await _client
          .from('classes')
          .update({
            'ai_helper_enabled': enabled,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', classId);
      return true;
    } catch (e) {
      print('Error updating class ai helper setting: $e');
      return false;
    }
  }

  Future<bool> updateClassCompletionQuestionTarget(
    String classId,
    int target,
  ) async {
    try {
      await _client
          .from('classes')
          .update({
            'completion_question_target': target,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', classId);
      return true;
    } catch (e) {
      print('Error updating class completion question target: $e');
      return false;
    }
  }

  Future<int> getClassCompletionQuestionTarget(String classId) async {
    try {
      final response = await _client
          .from('classes')
          .select('completion_question_target')
          .eq('id', classId)
          .maybeSingle();
      if (response == null) return 5;
      return (response['completion_question_target'] as num?)?.toInt() ?? 5;
    } catch (e) {
      print('Error getting class completion question target: $e');
      return 5;
    }
  }

  // 讀取班級 AI 小幫手開關（預設 true）
  Future<bool> getClassAiHelperEnabled(String classId) async {
    try {
      final response = await _client
          .from('classes')
          .select('ai_helper_enabled')
          .eq('id', classId)
          .maybeSingle();
      if (response == null) return true;
      return response['ai_helper_enabled'] as bool? ?? true;
    } catch (e) {
      print('Error getting class ai helper setting: $e');
      return true;
    }
  }

  // 刪除班級（需先檢查是否有學生）
  Future<bool> deleteClass(String classId) async {
    try {
      // 先檢查是否有學生
      final studentsResponse = await _client
          .from('users')
          .select('id')
          .eq('class_id', classId)
          .limit(1);
      
      if ((studentsResponse as List).isNotEmpty) {
        throw Exception('無法刪除班級：班級中仍有學生');
      }
      
      // 刪除班級下的所有課程
      await _client
          .from('grammar_topics')
          .delete()
          .eq('class_id', classId);
      
      // 刪除班級
      await _client
          .from('classes')
          .delete()
          .eq('id', classId);
      
      return true;
    } catch (e) {
      print('Error deleting class: $e');
      rethrow;
    }
  }

  // 學生加入班級
  Future<bool> joinClass(String studentId, String classCode) async {
    try {
      // 先通過代碼獲取班級
      final classInfo = await getClassByCode(classCode);
      if (classInfo == null) {
        throw Exception('找不到此班級代碼');
      }
      
      // 更新學生的 class_id
      await _client
          .from('users')
          .update({'class_id': classInfo.id})
          .eq('id', studentId);
      
      return true;
    } catch (e) {
      print('Error joining class: $e');
      rethrow;
    }
  }

  // 學生退出班級
  Future<bool> leaveClass(String studentId) async {
    try {
      await _client
          .from('users')
          .update({'class_id': null})
          .eq('id', studentId);
      
      return true;
    } catch (e) {
      print('Error leaving class: $e');
      return false;
    }
  }

  // 讀取學生所屬班級的 AI 小幫手開關（無班級時預設關閉）
  Future<bool> getStudentAiHelperEnabled(String studentId) async {
    try {
      final userResponse = await _client
          .from('users')
          .select('class_id')
          .eq('id', studentId)
          .maybeSingle();
      final classId = userResponse?['class_id'] as String?;
      if (classId == null || classId.isEmpty) {
        return false;
      }
      return await getClassAiHelperEnabled(classId);
    } catch (e) {
      print('Error getting student ai helper setting: $e');
      return true;
    }
  }

  // 獲取學生所屬班級
  Future<ClassModel?> getStudentClass(String studentId) async {
    try {
      // 先獲取學生的 class_id
      final userResponse = await _client
          .from('users')
          .select('class_id')
          .eq('id', studentId)
          .maybeSingle();
      
      if (userResponse == null || userResponse['class_id'] == null) {
        return null;
      }
      
      // 獲取班級資訊
      return await getClassById(userResponse['class_id'] as String);
    } catch (e) {
      print('Error getting student class: $e');
      return null;
    }
  }

  // 獲取班級的所有學生
  Future<List<Map<String, dynamic>>> getClassStudents(String classId) async {
    try {
      final response = await _client
          .from('users')
          .select('id, name, email, student_id, created_at')
          .eq('class_id', classId)
          .eq('role', 'student')
          .order('name', ascending: true);
      
      return (response as List).map((student) => {
        'id': student['id'],
        'name': student['name'],
        'email': student['email'],
        'student_id': student['student_id'],
        'created_at': student['created_at'],
      }).toList();
    } catch (e) {
      print('Error getting class students: $e');
      return [];
    }
  }

  // 獲取班級學生數量
  Future<int> getClassStudentCount(String classId) async {
    try {
      final response = await _client
          .from('users')
          .select('id')
          .eq('class_id', classId)
          .eq('role', 'student');
      
      return (response as List).length;
    } catch (e) {
      print('Error getting class student count: $e');
      return 0;
    }
  }

  // =====================================================
  // Grammar Topics (課程)
  // =====================================================

  // 獲取所有課程（可選班級篩選）
  Future<List<GrammarTopicModel>> getGrammarTopics({String? classId}) async {
    var query = _client
        .from('grammar_topics')
        .select();
    
    if (classId != null) {
      query = query.eq('class_id', classId);
    }
    
    final response = await query.order('created_at', ascending: false);
    
    return (response as List)
        .map((json) => GrammarTopicModel.fromJson(json))
        .toList();
  }

  Future<GrammarTopicModel?> getGrammarTopic(String id) async {
    try {
      final response = await _client
          .from('grammar_topics')
          .select()
          .eq('id', id)
          .single();
      
      return GrammarTopicModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<String> createGrammarTopic(String title, String description, String teacherId, {String? classId}) async {
    final data = {
      'title': title,
      'description': description,
      'teacher_id': teacherId,
    };
    
    if (classId != null) {
      data['class_id'] = classId;
    }
    
    final response = await _client
        .from('grammar_topics')
        .insert(data)
        .select()
        .single();
    
    return response['id'] as String;
  }

  Future<void> updateGrammarTopic(String id, String title, String description) async {
    await _client
        .from('grammar_topics')
        .update({
          'title': title,
          'description': description,
        })
        .eq('id', id);
  }

  Future<bool> updateGrammarTopicCompletionQuestionTarget(
    String grammarTopicId,
    int target,
  ) async {
    try {
      await _client
          .from('grammar_topics')
          .update({'completion_question_target': target})
          .eq('id', grammarTopicId);
      return true;
    } catch (e) {
      print('Error updating grammar topic completion target: $e');
      return false;
    }
  }

  Future<int> getGrammarTopicCompletionQuestionTarget(String grammarTopicId) async {
    try {
      final response = await _client
          .from('grammar_topics')
          .select('completion_question_target')
          .eq('id', grammarTopicId)
          .maybeSingle();
      if (response == null) return 5;
      return (response['completion_question_target'] as num?)?.toInt() ?? 5;
    } catch (e) {
      print('Error getting grammar topic completion target: $e');
      return 5;
    }
  }

  Future<void> deleteGrammarTopic(String id) async {
    try {
      print('=== 開始刪除課程 ===');
      print('課程 ID: $id');
      
      // 檢查當前用戶
      final currentUser = _client.auth.currentUser;
      print('當前用戶 ID: ${currentUser?.id}');
      print('當前用戶 Email: ${currentUser?.email}');
      
      if (currentUser == null) {
        throw Exception('刪除失敗：用戶未登入');
      }
      
      // 檢查用戶角色
      try {
        final userData = await _client
            .from('users')
            .select('id, role, email')
            .eq('id', currentUser.id)
            .single();
        print('用戶資料: $userData');
        print('用戶角色: ${userData['role']}');
        
        if (userData['role'] != 'teacher') {
          throw Exception('刪除失敗：只有老師可以刪除課程');
        }
      } catch (e) {
        print('檢查用戶角色時出錯: $e');
        // 繼續嘗試刪除，讓 RLS 政策來判斷
      }
      
      // 先檢查課程是否存在
      try {
        final topicCheck = await _client
            .from('grammar_topics')
            .select('id, title, teacher_id')
            .eq('id', id)
            .maybeSingle();
        
        if (topicCheck == null) {
          throw Exception('刪除失敗：找不到該課程');
        }
        
        print('找到課程: ${topicCheck['title']}');
        print('課程老師 ID: ${topicCheck['teacher_id']}');
      } catch (e) {
        print('檢查課程時出錯: $e');
        if (e.toString().contains('找不到')) {
          rethrow;
        }
      }
      
      // 執行刪除
      print('執行刪除操作...');
      final response = await _client
          .from('grammar_topics')
          .delete()
          .eq('id', id)
          .select();
      
      print('刪除回應: $response');
      print('回應類型: ${response.runtimeType}');
      
      final responseList = response as List;
      print('回應列表長度: ${responseList.length}');
      
      if (responseList.isEmpty) {
        // 再次檢查課程是否還存在
        final verifyCheck = await _client
            .from('grammar_topics')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        
        if (verifyCheck != null) {
          throw Exception('刪除失敗：課程仍然存在，可能是權限問題');
        } else {
          print('課程已成功刪除（驗證通過）');
          return; // 即使回應為空，但驗證顯示已刪除，視為成功
        }
      }
      
      print('=== 課程刪除成功 ===');
    } catch (e, stackTrace) {
      print('=== 刪除課程時發生錯誤 ===');
      print('錯誤訊息: $e');
      print('錯誤類型: ${e.runtimeType}');
      print('堆疊追蹤: $stackTrace');
      rethrow;
    }
  }

  // Grammar Key Points
  Future<List<GrammarKeyPointModel>> getGrammarKeyPoints(String grammarTopicId) async {
    final response = await _client
        .from('grammar_key_points')
        .select()
        .eq('grammar_topic_id', grammarTopicId)
        .order('order', ascending: true);
    
    return (response as List)
        .map((json) => GrammarKeyPointModel.fromJson(json))
        .toList();
  }

  Future<String> createGrammarKeyPoint(String grammarTopicId, String title, String content, int order) async {
    final response = await _client
        .from('grammar_key_points')
        .insert({
          'grammar_topic_id': grammarTopicId,
          'title': title,
          'content': content,
          'order': order,
        })
        .select()
        .single();
    
    return response['id'] as String;
  }

  Future<void> updateGrammarKeyPoint(String id, String title, String content, int order) async {
    await _client
        .from('grammar_key_points')
        .update({
          'title': title,
          'content': content,
          'order': order,
        })
        .eq('id', id);
  }

  Future<void> deleteGrammarKeyPoint(String id) async {
    await _client
        .from('grammar_key_points')
        .delete()
        .eq('id', id);
  }

  // Reminders
  Future<List<ReminderModel>> getReminders(String grammarTopicId) async {
    final response = await _client
        .from('reminders')
        .select()
        .eq('grammar_topic_id', grammarTopicId)
        .order('order', ascending: true);
    
    return (response as List)
        .map((json) => ReminderModel.fromJson(json))
        .toList();
  }

  Future<String> createReminder(String grammarTopicId, String title, String content, int order) async {
    final response = await _client
        .from('reminders')
        .insert({
          'grammar_topic_id': grammarTopicId,
          'title': title,
          'content': content,
          'order': order,
        })
        .select()
        .single();
    
    return response['id'] as String;
  }

  Future<void> updateReminder(String id, String title, String content, int order) async {
    await _client
        .from('reminders')
        .update({
          'title': title,
          'content': content,
          'order': order,
        })
        .eq('id', id);
  }

  Future<void> deleteReminder(String id) async {
    await _client
        .from('reminders')
        .delete()
        .eq('id', id);
  }

  // Questions
  Future<List<QuestionModel>> getQuestions(String studentId, {String? grammarTopicId}) async {
    print('getQuestions: Querying for student_id=$studentId${grammarTopicId != null ? ', grammar_topic_id=$grammarTopicId' : ''}');
    
    var query = _client
        .from('questions')
        .select()
        .eq('student_id', studentId);
    
    if (grammarTopicId != null) {
      query = query.eq('grammar_topic_id', grammarTopicId);
    }
    
    // 按 updated_at 降序排序，如果 updated_at 為 null 則使用 created_at
    // 注意：Supabase 的 order 會將 null 值放在最後，所以我們需要在應用層再次排序
    try {
      final response = await query.order('updated_at', ascending: false);
      
      print('getQuestions: Raw response type: ${response.runtimeType}');
      print('getQuestions: Raw response length: ${(response as List).length}');
      
      final questions = (response as List)
          .map((json) {
            try {
              return QuestionModel.fromJson(json);
            } catch (e) {
              print('Error parsing question JSON: $e');
              print('Question JSON: $json');
              rethrow;
            }
          })
          .toList();
      
      // 在應用層再次排序，確保正確處理 null 值
      questions.sort((a, b) {
        final aTime = a.updatedAt ?? a.createdAt;
        final bTime = b.updatedAt ?? b.createdAt;
        return bTime.compareTo(aTime); // 降序：最新的在前
      });
      
      print('getQuestions for student $studentId: Found ${questions.length} questions');
      if (questions.isNotEmpty) {
        print('  Latest question: id=${questions.first.id.substring(0, 8)}, stage=${questions.first.stage}, updated_at=${questions.first.updatedAt}, created_at=${questions.first.createdAt}');
      }
      
      return questions;
    } catch (e) {
      print('getQuestions ERROR for student $studentId: $e');
      print('Error type: ${e.runtimeType}');
      if (e.toString().contains('row-level security') || 
          e.toString().contains('RLS') ||
          e.toString().contains('42501')) {
        print('RLS policy error detected. Teacher may not have permission to read student questions.');
      }
      rethrow;
    }
  }

  Future<String> createQuestion(QuestionModel question) async {
    // 準備插入的資料，移除空的 id（讓資料庫自動生成）
    final data = question.toJson();
    if (data['id'] == null || data['id'] == '') {
      data.remove('id');
    }
    
    final response = await _client
        .from('questions')
        .insert(data)
        .select()
        .single();
    
    return response['id'] as String;
  }

  Future<void> updateQuestion(String id, Map<String, dynamic> updates) async {
    // 確保 updated_at 欄位被更新
    final updateData = Map<String, dynamic>.from(updates);
    if (!updateData.containsKey('updated_at')) {
      updateData['updated_at'] = DateTime.now().toIso8601String();
    }
    
    print('Updating question $id with data: $updateData');
    try {
      final response = await _client
          .from('questions')
          .update(updateData)
          .eq('id', id)
          .select('id, stage, updated_at')
          .single();
      
      print('Question updated successfully: id=${response['id']}, stage=${response['stage']}, updated_at=${response['updated_at']}');
    } catch (e) {
      // 如果使用 .single() 失敗（可能是因為 RLS 政策或行不存在），嘗試不使用 .single()
      print('Update with .single() failed, trying without .single(): $e');
      try {
        final response = await _client
            .from('questions')
            .update(updateData)
            .eq('id', id)
            .select('id');
        
        if ((response as List).isEmpty) {
          throw Exception('更新失敗：找不到該題目或沒有權限更新');
        }
        print('Question updated successfully (without .single())');
      } catch (e2) {
        print('Update failed: $e2');
        rethrow;
      }
    }
  }

  // 完成指定階段
  Future<void> completeStage(String questionId, int stage) async {
    if (stage < 1 || stage > 4) {
      throw Exception('Invalid stage: $stage');
    }

    // 先獲取當前的 completed_stages
    final questionResponse = await _client
        .from('questions')
        .select('completed_stages')
        .eq('id', questionId)
        .single();

    final currentCompleted = questionResponse['completed_stages'] as Map<String, dynamic>? ?? {};
    
    // 添加當前階段的完成時間
    final updatedCompleted = Map<String, dynamic>.from(currentCompleted);
    updatedCompleted[stage.toString()] = DateTime.now().toIso8601String();

    // 更新資料庫
    await _client
        .from('questions')
        .update({
          'completed_stages': updatedCompleted,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', questionId);
  }

  // 檢查階段是否已完成
  Future<bool> isStageCompleted(String questionId, int stage) async {
    final questionResponse = await _client
        .from('questions')
        .select('completed_stages')
        .eq('id', questionId)
        .single();

    final completedStages = questionResponse['completed_stages'] as Map<String, dynamic>? ?? {};
    return completedStages.containsKey(stage.toString());
  }

  // 獲取題目的所有已完成階段
  Future<Map<int, DateTime>> getCompletedStages(String questionId) async {
    final questionResponse = await _client
        .from('questions')
        .select('completed_stages')
        .eq('id', questionId)
        .single();

    final completedStages = questionResponse['completed_stages'] as Map<String, dynamic>? ?? {};
    final Map<int, DateTime> result = {};
    
    completedStages.forEach((key, value) {
      final stage = int.tryParse(key);
      if (stage != null && value is String) {
        result[stage] = DateTime.parse(value);
      }
    });
    
    return result;
  }

  Future<void> deleteQuestion(String id) async {
    await _client
        .from('questions')
        .delete()
        .eq('id', id);
  }

  // Badges
  Future<List<BadgeModel>> getBadges(String studentId) async {
    final response = await _client
        .from('badges')
        .select()
        .eq('student_id', studentId)
        .order('earned_at', ascending: false);
    
    return (response as List)
        .map((json) => BadgeModel.fromJson(json))
        .toList();
  }

  Future<String> createBadge(BadgeModel badge) async {
    final response = await _client
        .from('badges')
        .insert(badge.toJson())
        .select()
        .single();
    
    return response['id'] as String;
  }

  // 檢查學生在該課程是否已有徽章
  Future<bool> hasBadgeForTopic(String studentId, String grammarTopicId) async {
    try {
      final response = await _client
          .from('badges')
          .select('id')
          .eq('student_id', studentId)
          .eq('grammar_topic_id', grammarTopicId)
          .limit(1);
      
      return (response as List).isNotEmpty;
    } catch (e) {
      print('Error checking badge: $e');
      return false;
    }
  }

  // Student Progress
  Future<Map<String, dynamic>> getStudentProgress(String studentId, String grammarTopicId) async {
    final questions = await getQuestions(studentId, grammarTopicId: grammarTopicId);
    final completedQuestions = questions.where((q) => q.stage == 4).length;
    
    return {
      'total_questions': questions.length,
      'completed_questions': completedQuestions,
      'stage_distribution': {
        'stage1': questions.where((q) => q.stage == 1).length,
        'stage2': questions.where((q) => q.stage == 2).length,
        'stage3': questions.where((q) => q.stage == 3).length,
        'stage4': questions.where((q) => q.stage == 4).length,
      },
    };
  }

  // Teacher Dashboard - Get all students' progress
  Future<List<Map<String, dynamic>>> getAllStudentsProgress({String? classId}) async {
    try {
      print('Getting all students progress${classId != null ? ' for class $classId' : ''}...');
      
      // 嘗試使用 SECURITY DEFINER 函數（如果可用）
      try {
        final functionResponse = await _client.rpc('get_all_students');
        if (functionResponse != null) {
          var studentsList = functionResponse as List;
          if (studentsList.isNotEmpty) {
            print('Using get_all_students function, found ${studentsList.length} students');
            final hasClassIdField = studentsList.any(
              (s) => s is Map<String, dynamic> && s.containsKey('class_id'),
            );
            if (classId != null && !hasClassIdField) {
              // 舊版 RPC 可能未回傳 class_id，若強行篩選會變成 0 筆
              throw Exception('get_all_students missing class_id field, fallback to direct query');
            }
            // 排除不納入統計的帳號（例如開發者/測試帳號）
            var studentsResponse = studentsList.where((s) {
              final exclude = s is Map<String, dynamic> ? (s['exclude_from_stats'] == true) : false;
              return !exclude;
            }).toList();
            
            // 如果有指定班級，篩選該班級的學生
            if (classId != null) {
              studentsResponse = studentsResponse.where((s) {
                final studentClassId = s is Map<String, dynamic> ? s['class_id']?.toString() : null;
                return studentClassId == classId;
              }).toList();
              print('Filtered to ${studentsResponse.length} students in class $classId');
            }
          
          // 查詢所有學生的題目資料（包含 completed_stages），按 updated_at 降序排序
          final questionsResponse = await _client
              .from('questions')
              .select('student_id, stage, completed_stages, created_at, updated_at')
              .order('updated_at', ascending: false);
          
          // 建立學生ID到題目資料的映射
          final Map<String, List<Map<String, dynamic>>> questionsByStudent = {};
          for (var question in questionsResponse as List) {
            final studentId = question['student_id'] as String;
            if (!questionsByStudent.containsKey(studentId)) {
              questionsByStudent[studentId] = [];
            }
            questionsByStudent[studentId]!.add(question);
          }
          
          final studentIds = studentsResponse
              .map((s) => s['id'] as String)
              .toList();
          final latestSessionSignals = await _getLatestSessionSignals(studentIds);

          // 建立結果列表
          final List<Map<String, dynamic>> result = [];
          
          for (var student in studentsResponse) {
            final studentId = student['id'] as String;
            final studentQuestions = questionsByStudent[studentId] ?? [];
            
            int currentStage = 1;
            String? lastActivity;
            
            if (studentQuestions.isNotEmpty) {
              // 按 updated_at 排序，獲取最新的題目
              final sortedQuestions = List<Map<String, dynamic>>.from(studentQuestions);
              sortedQuestions.sort((a, b) {
                final aTime = a['updated_at'] ?? a['created_at'];
                final bTime = b['updated_at'] ?? b['created_at'];
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return DateTime.parse(bTime).compareTo(DateTime.parse(aTime));
              });
              
              // 使用最新題目的階段
              final latestQuestion = sortedQuestions.first;
              currentStage = latestQuestion['stage'] as int? ?? 1;
              lastActivity = latestQuestion['updated_at'] ?? latestQuestion['created_at'];
              
              print('Student ${student['name']}: Current stage = $currentStage (latest question updated_at: ${latestQuestion['updated_at']}, created_at: ${latestQuestion['created_at']})');
            } else {
              lastActivity = student['created_at'] as String?;
            }
            
            result.add({
              'student_id': studentId,
              'student_name': student['name'] as String? ?? '',
              'student_email': student['email'] as String? ?? '',
              'student_id_number': student['student_id'] as String? ?? '',
              'last_login_at': latestSessionSignals[studentId]?.toIso8601String(),
              'current_stage': currentStage,
              'last_activity': lastActivity,
              'stuck_duration': null,
            });
          }
          
            print('Returning ${result.length} students from function');
            return result;
          }
        }
      } catch (functionError) {
        print('Function get_all_students not available or failed: $functionError');
        // 繼續使用直接查詢方法
      }
      
      // 先查詢所有學生（直接查詢方法）
      print('Attempting direct query to users table...');
      var studentsQuery = _client
          .from('users')
          .select('id, name, student_id, email, created_at, exclude_from_stats, class_id')
          .eq('role', 'student')
          .or('exclude_from_stats.is.null,exclude_from_stats.eq.false');
      
      // 如果有指定班級，篩選該班級的學生
      if (classId != null) {
        studentsQuery = studentsQuery.eq('class_id', classId);
      }
      
      final studentsResponse = await studentsQuery;
      
      final studentsList = studentsResponse as List;
      print('Students query result: ${studentsList.length} students found');
      
      // 如果查詢成功但返回空列表，可能是 RLS 政策問題
      if (studentsList.isEmpty) {
        print('WARNING: Query returned 0 students. This might be an RLS policy issue.');
        print('Current user role from auth: ${_client.auth.currentUser?.userMetadata?['role']}');
      }
      
      if ((studentsResponse as List).isEmpty) {
        print('No students found in database');
        return [];
      }
    
      // 查詢所有學生的題目資料（包含 completed_stages），按 updated_at 降序排序
      final questionsResponse = await _client
          .from('questions')
          .select('student_id, stage, completed_stages, created_at, updated_at')
          .order('updated_at', ascending: false);
    
      // 建立學生ID到題目資料的映射
      final Map<String, List<Map<String, dynamic>>> questionsByStudent = {};
      for (var question in questionsResponse as List) {
        final studentId = question['student_id'] as String;
        if (!questionsByStudent.containsKey(studentId)) {
          questionsByStudent[studentId] = [];
        }
        questionsByStudent[studentId]!.add(question);
      }
    
      final studentIds = (studentsResponse as List)
          .map((s) => s['id'] as String)
          .toList();
      final latestSessionSignals = await _getLatestSessionSignals(studentIds);

      // 建立結果列表
      final List<Map<String, dynamic>> result = [];
    
      for (var student in studentsResponse as List) {
        final studentId = student['id'] as String;
        final studentQuestions = questionsByStudent[studentId] ?? [];
        
        int currentStage = 1;
        String? lastActivity;
        
        if (studentQuestions.isNotEmpty) {
          // 按 updated_at 排序，獲取最新的題目
          final sortedQuestions = List<Map<String, dynamic>>.from(studentQuestions);
          sortedQuestions.sort((a, b) {
            final aTime = a['updated_at'] ?? a['created_at'];
            final bTime = b['updated_at'] ?? b['created_at'];
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return DateTime.parse(bTime).compareTo(DateTime.parse(aTime));
          });
          
          // 使用最新題目的階段
          final latestQuestion = sortedQuestions.first;
          currentStage = latestQuestion['stage'] as int? ?? 1;
          lastActivity = latestQuestion['updated_at'] ?? latestQuestion['created_at'];
          
          print('Student ${student['name']}: Current stage = $currentStage (latest question updated_at: ${latestQuestion['updated_at']}, created_at: ${latestQuestion['created_at']})');
        } else {
          // 如果沒有題目，使用註冊時間作為最後活動時間
          lastActivity = student['created_at'] as String?;
        }
        
        result.add({
          'student_id': studentId,
          'student_name': student['name'] as String? ?? '',
          'student_email': student['email'] as String? ?? '',
          'student_id_number': student['student_id'] as String? ?? '',
          'last_login_at': latestSessionSignals[studentId]?.toIso8601String(),
          'current_stage': currentStage,
          'last_activity': lastActivity,
          'stuck_duration': null,
        });
      }
    
      print('Returning ${result.length} students');
      return result;
    } catch (e) {
      print('Error getting students progress: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');
      
      // 如果是 RLS 政策錯誤，提供更詳細的訊息
      if (e.toString().contains('row-level security') || 
          e.toString().contains('RLS') ||
          e.toString().contains('42501')) {
        print('RLS policy error detected. Please check if "Teachers can read all students" policy is correctly set.');
      }
      
      return [];
    }
  }

  // Statistics
  Future<Map<String, dynamic>> getStudentStatistics(String studentId, {DateTime? startDate, DateTime? endDate}) async {
    var query = _client
        .from('user_sessions')
        .select()
        .eq('student_id', studentId);
    
    if (startDate != null) {
      query = query.gte('start_time', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('end_time', endDate.toIso8601String());
    }
    
    final sessions = await query;
    final questions = await getQuestions(studentId);
    
    int totalDuration = 0;
    int completedSessionsCount = 0; // 只計算有 end_time 且有效的 sessions
    
    for (var session in sessions as List) {
      if (session['end_time'] != null) {
        final start = DateTime.parse(session['start_time']);
        final end = DateTime.parse(session['end_time']);
        final duration = end.difference(start).inMinutes;
        
        // 只計算有效的 session（時長為正數）
        if (duration > 0) {
          totalDuration += duration;
          completedSessionsCount++;
        } else {
          // 記錄異常的 session（用於調試）
          print('Warning: Invalid session duration for student $studentId: start=$start, end=$end, duration=$duration minutes');
        }
      }
    }
    
    // 只計算有完成 end_time 的 sessions 的平均值
    final averageDuration = completedSessionsCount > 0 
        ? totalDuration / completedSessionsCount 
        : 0.0;
    
    return {
      'weekly_login_frequency': _calculateWeeklyFrequency(sessions as List),
      'average_session_duration': averageDuration,
      'total_questions': questions.length,
      'total_usage_time': totalDuration, // 確保是非負數
    };
  }

  int _calculateWeeklyFrequency(List sessions) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return sessions.where((s) {
      final startTime = DateTime.parse(s['start_time']);
      return startTime.isAfter(weekAgo);
    }).length;
  }

  // Batch query - Get all questions for multiple students at once
  Future<Map<String, List<QuestionModel>>> getAllQuestionsForStudents(List<String> studentIds) async {
    if (studentIds.isEmpty) {
      return {};
    }
    
    try {
      final response = await _client
          .from('questions')
          .select()
          .inFilter('student_id', studentIds)
          .order('updated_at', ascending: false);
      
      final Map<String, List<QuestionModel>> questionsByStudent = {};
      
      for (var json in response as List) {
        try {
          final question = QuestionModel.fromJson(json);
          final studentId = question.studentId;
          if (!questionsByStudent.containsKey(studentId)) {
            questionsByStudent[studentId] = [];
          }
          questionsByStudent[studentId]!.add(question);
        } catch (e) {
          print('Error parsing question: $e');
        }
      }
      
      // Sort each student's questions by updated_at descending
      for (var studentId in questionsByStudent.keys) {
        questionsByStudent[studentId]!.sort((a, b) {
          final aTime = a.updatedAt ?? a.createdAt;
          final bTime = b.updatedAt ?? b.createdAt;
          return bTime.compareTo(aTime);
        });
      }
      
      return questionsByStudent;
    } catch (e) {
      print('Error getting all questions for students: $e');
      return {};
    }
  }

  // Teacher Export - Get question rows for a specific topic (optional class filter)
  Future<List<Map<String, dynamic>>> getQuestionExportRowsByTopic({
    required String grammarTopicId,
    String? classId,
  }) async {
    try {
      final questionsResponse = await _client
          .from('questions')
          .select(
            'id, student_id, question, correct_answer, explanation, stage, teacher_comment, created_at, updated_at',
          )
          .eq('grammar_topic_id', grammarTopicId)
          .order('created_at', ascending: true);

      final questions = (questionsResponse as List).cast<Map<String, dynamic>>();
      if (questions.isEmpty) {
        return [];
      }

      final studentIds = questions
          .map((q) => q['student_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      var studentsQuery = _client
          .from('users')
          .select('id, name, student_id, class_id')
          .eq('role', 'student')
          .inFilter('id', studentIds);

      if (classId != null) {
        studentsQuery = studentsQuery.eq('class_id', classId);
      }

      final studentsResponse = await studentsQuery;
      final students = (studentsResponse as List).cast<Map<String, dynamic>>();
      if (students.isEmpty) {
        return [];
      }

      final studentsMap = <String, Map<String, dynamic>>{
        for (final s in students) s['id'] as String: s,
      };

      final rows = <Map<String, dynamic>>[];
      for (final q in questions) {
        final studentId = q['student_id'] as String?;
        if (studentId == null || !studentsMap.containsKey(studentId)) {
          continue;
        }
        final student = studentsMap[studentId]!;
        rows.add({
          'student_name': student['name'] as String? ?? '',
          'student_id_number': student['student_id'] as String? ?? '',
          'question_id': q['id'] as String? ?? '',
          'question': q['question'] as String? ?? '',
          'correct_answer': q['correct_answer'] as String? ?? '',
          'explanation': q['explanation'] as String? ?? '',
          'teacher_comment': q['teacher_comment'] as String? ?? '',
          'stage': q['stage']?.toString() ?? '',
          'created_at': q['created_at'] as String? ?? '',
          'updated_at': q['updated_at'] as String? ?? '',
        });
      }

      return rows;
    } catch (e) {
      print('Error getting question export rows by topic: $e');
      return [];
    }
  }

  // Batch query - Get statistics for all students at once
  Future<Map<String, Map<String, dynamic>>> getAllStudentsStatistics(List<String> studentIds) async {
    if (studentIds.isEmpty) {
      return {};
    }
    
    try {
      // Query all sessions for all students at once
      final sessionsResponse = await _client
          .from('user_sessions')
          .select()
          .inFilter('student_id', studentIds);
      
      // Query all questions for all students at once
      final questionsResponse = await _client
          .from('questions')
          .select('student_id')
          .inFilter('student_id', studentIds);
      
      // Group sessions by student
      final Map<String, List<dynamic>> sessionsByStudent = {};
      for (var session in sessionsResponse as List) {
        final studentId = session['student_id'] as String;
        if (!sessionsByStudent.containsKey(studentId)) {
          sessionsByStudent[studentId] = [];
        }
        sessionsByStudent[studentId]!.add(session);
      }
      
      // Count questions by student
      final Map<String, int> questionCountByStudent = {};
      for (var question in questionsResponse as List) {
        final studentId = question['student_id'] as String;
        questionCountByStudent[studentId] = (questionCountByStudent[studentId] ?? 0) + 1;
      }
      
      // Calculate statistics for each student
      final Map<String, Map<String, dynamic>> result = {};
      
      for (var studentId in studentIds) {
        final sessions = sessionsByStudent[studentId] ?? [];
        final questionCount = questionCountByStudent[studentId] ?? 0;
        
        int totalDuration = 0;
        int completedSessionsCount = 0;
        
        for (var session in sessions) {
          if (session['end_time'] != null) {
            final start = DateTime.parse(session['start_time']);
            final end = DateTime.parse(session['end_time']);
            final duration = end.difference(start).inMinutes;
            
            if (duration > 0) {
              totalDuration += duration;
              completedSessionsCount++;
            }
          }
        }
        
        final averageDuration = completedSessionsCount > 0
            ? totalDuration / completedSessionsCount
            : 0.0;
        
        result[studentId] = {
          'weekly_login_frequency': _calculateWeeklyFrequency(sessions),
          'average_session_duration': averageDuration,
          'total_questions': questionCount,
          'total_usage_time': totalDuration,
        };
      }
      
      return result;
    } catch (e) {
      print('Error getting all students statistics: $e');
      return {};
    }
  }

  // Session Management - 創建新的 session
  Future<String?> createSession(String studentId) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      final response = await _client
          .from('user_sessions')
          .insert({
            'student_id': studentId,
            'start_time': nowIso,
            // 讓老師端立刻有可用的心跳值；後續會由 Timer 每 10 秒更新
            'last_heartbeat': nowIso,
          })
          .select()
          .single();
      
      return response['id'] as String?;
    } catch (e) {
      print('Error creating session: $e');
      return null;
    }
  }

  // Session Management - 更新 session 心跳（供老師端「上線中」判斷使用）
  //
  // 需要 user_sessions 表有 last_heartbeat 欄位（timestamp/timestamptz）。
  // 若後端尚未新增欄位或權限不足，這個更新會失敗；呼叫端應視為非致命錯誤。
  Future<bool> updateSessionHeartbeat({
    required String sessionId,
    required DateTime heartbeatTime,
  }) async {
    try {
      await _client
          .from('user_sessions')
          .update({'last_heartbeat': heartbeatTime.toIso8601String()})
          .eq('id', sessionId);
      return true;
    } catch (e) {
      // 心跳更新失敗不應影響主要流程，但要把錯誤留給呼叫端做診斷
      print('Error updating session heartbeat: $e');
      return false;
    }
  }

  // Session Management - 結束 session
  Future<void> endSession(String sessionId, {DateTime? endTime}) async {
    try {
      await _client
          .from('user_sessions')
          .update({
            'end_time': (endTime ?? DateTime.now()).toIso8601String(),
          })
          .eq('id', sessionId);
    } catch (e) {
      print('Error ending session: $e');
    }
  }

  // Session Management - 獲取當前活動的 session（未結束的）
  Future<String?> getActiveSessionId(String studentId) async {
    try {
      final response = await _client
          .from('user_sessions')
          .select('id')
          .eq('student_id', studentId)
          .isFilter('end_time', null)
          .order('start_time', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (response != null) {
        return response['id'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting active session: $e');
      return null;
    }
  }

  /// 取得目前未結束 session 的關鍵資訊（用於避免重複建立 session 與「爆時數」）。
  /// 回傳：{ id, start_time, last_heartbeat }
  Future<Map<String, dynamic>?> getActiveSessionInfo(String studentId) async {
    try {
      final response = await _client
          .from('user_sessions')
          .select('id, start_time, last_heartbeat')
          .eq('student_id', studentId)
          .isFilter('end_time', null)
          .order('start_time', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error getting active session info: $e');
      return null;
    }
  }

  // Session Management - 結束所有未結束的 session（用於登出或應用程式關閉時）
  Future<void> endAllActiveSessions(String studentId, {DateTime? endTime}) async {
    try {
      await _client
          .from('user_sessions')
          .update({
            'end_time': (endTime ?? DateTime.now()).toIso8601String(),
          })
          .eq('student_id', studentId)
          .isFilter('end_time', null);
    } catch (e) {
      print('Error ending all active sessions: $e');
    }
  }

  // Session Management - 檢查學生是否在線（是否有活動的 session）
  Future<bool> isStudentOnline(String studentId) async {
    try {
      final response = await _client
          .from('user_sessions')
          .select('id, start_time')
          .eq('student_id', studentId)
          .isFilter('end_time', null)
          .order('start_time', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (response != null) {
        // 檢查 session 是否在最近 5 分鐘內有活動（避免顯示長時間未活動的 session）
        final startTime = DateTime.parse(response['start_time'] as String);
        final now = DateTime.now();
        final difference = now.difference(startTime);
        
        // 如果 session 在最近 30 分鐘內開始，認為學生在線
        // 這個時間可以根據需要調整
        return difference.inMinutes < 30;
      }
      return false;
    } catch (e) {
      print('Error checking student online status: $e');
      return false;
    }
  }

  // Session Management - 批量檢查多個學生的登入狀態
  Future<Map<String, bool>> getStudentsOnlineStatus(List<String> studentIds) async {
    final Map<String, bool> statusMap = {};
    
    try {
      // 獲取所有未結束的 session
      final response = await _client
          .from('user_sessions')
          .select('student_id, start_time, last_heartbeat')
          .inFilter('student_id', studentIds)
          .isFilter('end_time', null);
      
      final now = DateTime.now();
      final latestSignals = <String, DateTime>{};
      
      // 處理響應（確保是 List）
      final sessions = (response as List).cast<Map<String, dynamic>>();
      
      for (var session in sessions) {
        final studentId = session['student_id'] as String;
        final String? heartbeatStr = session['last_heartbeat'] as String?;
        final DateTime signalTime = heartbeatStr != null
            ? DateTime.parse(heartbeatStr)
            : DateTime.parse(session['start_time'] as String);
        
        // 如果這個學生已經有更近期的 session，保留更近期的
        if (!latestSignals.containsKey(studentId) ||
            signalTime.isAfter(latestSignals[studentId]!)) {
          latestSignals[studentId] = signalTime;
        }
      }
      
      // 檢查每個學生的狀態
      for (var studentId in studentIds) {
        if (latestSignals.containsKey(studentId)) {
          final signalTime = latestSignals[studentId]!;
          final difference = now.difference(signalTime);
          // 心跳每 10 秒一次；放寬容忍避免「實際在線卻被誤判離線」
          statusMap[studentId] = difference.inSeconds < 90;
        } else {
          statusMap[studentId] = false;
        }
      }
    } catch (e) {
      print('Error getting students online status: $e');
      // 如果出錯，所有學生都標記為離線
      for (var studentId in studentIds) {
        statusMap[studentId] = false;
      }
    }
    
    return statusMap;
  }

  Future<Map<String, bool>> getStudentsAiUsageStatus(List<String> studentIds) async {
    final result = <String, bool>{};
    for (final id in studentIds) {
      result[id] = false;
    }
    if (studentIds.isEmpty) {
      return result;
    }
    try {
      final response = await _client
          .from('chat_messages')
          .select('student_id')
          .inFilter('student_id', studentIds)
          .limit(5000);
      for (final row in (response as List).cast<Map<String, dynamic>>()) {
        final studentId = row['student_id'] as String?;
        if (studentId != null) {
          result[studentId] = true;
        }
      }
    } catch (e) {
      print('Error getting students AI usage status: $e');
    }
    return result;
  }

  Future<Map<String, DateTime>> _getLatestSessionSignals(List<String> studentIds) async {
    if (studentIds.isEmpty) {
      return {};
    }
    try {
      final response = await _client
          .from('user_sessions')
          .select('student_id, start_time, last_heartbeat, end_time')
          .inFilter('student_id', studentIds);

      final latestMap = <String, DateTime>{};
      for (final row in (response as List).cast<Map<String, dynamic>>()) {
        final studentId = row['student_id'] as String?;
        if (studentId == null || studentId.isEmpty) continue;
        final heartbeat = row['last_heartbeat'] as String?;
        final start = row['start_time'] as String?;
        final end = row['end_time'] as String?;

        DateTime? candidate;
        if (heartbeat != null && heartbeat.isNotEmpty) {
          candidate = DateTime.tryParse(heartbeat);
        }
        candidate ??= DateTime.tryParse(end ?? '');
        candidate ??= DateTime.tryParse(start ?? '');
        if (candidate == null) continue;

        final current = latestMap[studentId];
        if (current == null || candidate.isAfter(current)) {
          latestMap[studentId] = candidate;
        }
      }
      return latestMap;
    } catch (e) {
      print('Error getting latest session signals: $e');
      return {};
    }
  }

  // Student Management - Reset student password (admin function)
  Future<void> resetStudentPassword(String studentEmail, String newPassword) async {
    final cleanedEmail = studentEmail.trim().toLowerCase();
    
    // 驗證密碼長度
    if (newPassword.length < 6) {
      throw Exception('密碼長度至少需要6個字符');
    }
    
    // 使用後端 API 重置密碼（需要 JWT Token 驗證和老師角色）
    try {
      // 獲取當前用戶的 JWT Token
      final session = _client.auth.currentSession;
      if (session == null || session.accessToken.isEmpty) {
        throw Exception('請先登入');
      }
      
      final backendUrl = _backendUrl;
      print('嘗試連接到後端 API: $backendUrl/api/admin/reset-student-password');
      final response = await http.post(
        Uri.parse('$backendUrl/api/admin/reset-student-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'student_email': cleanedEmail,
          'new_password': newPassword,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('學生密碼已通過後端 API 重置');
          return; // 成功
        } else {
          // 不洩露後端詳細錯誤資訊
          print('後端 API 返回失敗: statusCode=${response.statusCode}, body=${response.body}');
          throw Exception('操作失敗');
        }
      } else {
        // 不洩露後端詳細錯誤資訊
        jsonDecode(response.body); // 嘗試解析，但不使用結果
        print('後端 API 錯誤: statusCode=${response.statusCode}, body=${response.body}');
        throw Exception('重置密碼失敗');
      }
    } catch (e) {
      print('Backend API reset student password failed: $e');
      rethrow;
    }
  }

  // Student Management - Get all students (simple list)
  Future<List<Map<String, dynamic>>> getAllStudents({String? classId}) async {
    try {
      var query = _client
          .from('users')
          .select('id, name, email, student_id, created_at, class_id')
          .eq('role', 'student');

      if (classId != null && classId.isNotEmpty) {
        query = query.eq('class_id', classId);
      }

      final response = await query.order('created_at', ascending: false);
      
      return (response as List).map((student) => {
        'id': student['id'],
        'name': student['name'],
        'email': student['email'],
        'student_id': student['student_id'],
        'created_at': student['created_at'],
        'class_id': student['class_id'],
      }).toList();
    } catch (e) {
      print('Error getting all students: $e');
      rethrow;
    }
  }

  // Student Management - Update student
  Future<void> updateStudent(
    String studentId, {
    String? name,
    String? email,
    String? studentIdNumber,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (name != null) {
        updates['name'] = name;
      }
      if (email != null) {
        updates['email'] = email;
      }
      if (studentIdNumber != null) {
        updates['student_id'] = studentIdNumber;
      }

      if (updates.isEmpty) {
        return;
      }

      // 如果更新了 email，需要先通過後端 API 更新 auth.users
      if (email != null) {
        final cleanedEmail = email.trim().toLowerCase();
        
        // 使用後端 API 更新 email（需要 JWT Token 驗證）
        try {
          // 獲取當前用戶的 JWT Token
          final session = _client.auth.currentSession;
          if (session == null || session.accessToken.isEmpty) {
            throw Exception('請先登入');
          }
          
          final backendUrl = _backendUrl;
          print('嘗試連接到後端 API: $backendUrl/api/admin/update-student-email');
          final response = await http.post(
            Uri.parse('$backendUrl/api/admin/update-student-email'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.accessToken}',
            },
            body: jsonEncode({
              'student_id': studentId,
              'new_email': cleanedEmail,
            }),
          ).timeout(const Duration(seconds: 10));
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['success'] == true) {
              print('學生電子郵件已通過後端 API 更新: ${data['old_email']} -> ${data['new_email']}');
              // 後端 API 已經同時更新了 users 表和 auth.users，所以不需要再更新 users 表
              // 但如果有其他欄位需要更新，仍然需要更新 users 表
              if (name != null || studentIdNumber != null) {
                final otherUpdates = <String, dynamic>{};
                if (name != null) {
                  otherUpdates['name'] = name;
                }
                if (studentIdNumber != null) {
                  otherUpdates['student_id'] = studentIdNumber;
                }
                if (otherUpdates.isNotEmpty) {
                  await _client
                      .from('users')
                      .update(otherUpdates)
                      .eq('id', studentId);
                  print('其他欄位已更新');
                }
              }
              return; // 成功，直接返回
            } else {
              // 不洩露後端詳細錯誤資訊
          print('後端 API 返回失敗: statusCode=${response.statusCode}, body=${response.body}');
          throw Exception('操作失敗');
            }
          } else {
            // 不洩露後端詳細錯誤資訊
            jsonDecode(response.body); // 嘗試解析，但不使用結果
            print('後端 API 錯誤: statusCode=${response.statusCode}, body=${response.body}');
            throw Exception('更新電子郵件失敗');
          }
        } catch (e) {
          print('後端 API 更新 email 失敗: $e');
          // 如果後端 API 失敗，仍然嘗試更新 users 表（但 auth.users 不會更新）
          print('警告：無法更新 auth.users 的 email，只更新 users 表');
          // 繼續執行下面的更新 users 表的邏輯
        }
      }
      
      // 更新 users 表（如果沒有更新 email，或後端 API 失敗時）
      await _client
          .from('users')
          .update(updates)
          .eq('id', studentId);
      
      print('Update student completed successfully');
    } catch (e) {
      print('Error updating student: $e');
      print('Error type: ${e.runtimeType}');
      if (e.toString().contains('row-level security') || 
          e.toString().contains('RLS') ||
          e.toString().contains('policy')) {
        throw Exception('更新失敗：權限不足。請確認：\n1. 您是否以老師身份登入？\n2. 老師帳號的 metadata 中是否有 role？\n3. RLS 政策是否正確設定？\n\n詳細錯誤：$e');
      }
      rethrow;
    }
  }

  // Student Management - Delete student
  Future<void> deleteStudent(String studentId) async {
    try {
      // 先刪除相關資料（題目、徽章等）
      await _client
          .from('questions')
          .delete()
          .eq('student_id', studentId);
      
      await _client
          .from('badges')
          .delete()
          .eq('student_id', studentId);

      await _client
          .from('user_sessions')
          .delete()
          .eq('student_id', studentId);

      await _client
          .from('chat_messages')
          .delete()
          .eq('student_id', studentId);

      // 最後刪除 users 表中的記錄
      await _client
          .from('users')
          .delete()
          .eq('id', studentId);

      // 注意：刪除 auth.users 中的記錄需要管理員權限
      // 這裡我們只刪除 users 表，auth.users 的記錄可能需要通過 Supabase Admin API 刪除
      print('Note: Auth user deletion may require admin privileges');
    } catch (e) {
      print('Error deleting student: $e');
      rethrow;
    }
  }

  // Account Management - Delete own account
  Future<void> deleteAccount(String userId) async {
    try {
      // 先刪除相關資料（題目、徽章等）
      await _client
          .from('questions')
          .delete()
          .eq('student_id', userId);
      
      await _client
          .from('badges')
          .delete()
          .eq('student_id', userId);

      await _client
          .from('user_sessions')
          .delete()
          .eq('student_id', userId);

      await _client
          .from('chat_messages')
          .delete()
          .eq('student_id', userId);

      // 最後刪除 users 表中的記錄
      await _client
          .from('users')
          .delete()
          .eq('id', userId);

      // 登出用戶
      await _client.auth.signOut();

      // 注意：刪除 auth.users 中的記錄需要管理員權限
      // 這裡我們只刪除 users 表，auth.users 的記錄可能需要通過 Supabase Admin API 刪除
      print('Note: Auth user deletion may require admin privileges');
    } catch (e) {
      print('Error deleting account: $e');
      rethrow;
    }
  }

  // Chat Messages
  Future<void> saveChatMessage({
    required String questionId,
    required String grammarTopicId,
    required String studentId,
    required int stage,
    required String messageType,
    required String content,
  }) async {
    try {
      // 明確轉換為 Map<String, Object> 以符合 Supabase 的要求
      final data = <String, Object>{
        'question_id': questionId,
        'grammar_topic_id': grammarTopicId,
        'student_id': studentId,
        'stage': stage,
        'message_type': messageType,
        'content': content,
      };
      
      await _client.from('chat_messages').insert(data);
    } catch (e) {
      print('Error saving chat message: $e');
      // 不拋出異常，避免影響用戶體驗
    }
  }

  Future<List<Map<String, dynamic>>> loadChatMessages({
    required String questionId,
    required String grammarTopicId,
    int? stage,
  }) async {
    try {
      var query = _client
          .from('chat_messages')
          .select()
          .eq('question_id', questionId)
          .eq('grammar_topic_id', grammarTopicId);

      if (stage != null) {
        query = query.eq('stage', stage);
      }

      final response = await query.order('created_at', ascending: true);
      
      return (response as List).map((json) {
        return {
          'type': json['message_type'] as String,
          'content': json['content'] as String,
          'stage': json['stage'] as int,
          'created_at': json['created_at'] as String,
        };
      }).toList();
    } catch (e) {
      print('Error loading chat messages: $e');
      return [];
    }
  }

  // 刪除特定階段的對話消息
  Future<void> deleteChatMessages({
    required String questionId,
    required String grammarTopicId,
    required int stage,
  }) async {
    try {
      await _client
          .from('chat_messages')
          .delete()
          .eq('question_id', questionId)
          .eq('grammar_topic_id', grammarTopicId)
          .eq('stage', stage);
    } catch (e) {
      print('Error deleting chat messages: $e');
      rethrow;
    }
  }

  // Teacher-Student Chat
  Future<void> sendTeacherStudentMessage({
    required String studentId,
    required String senderId,
    required String senderRole,
    required String content,
    bool isHandRaise = false,
  }) async {
    await _client.from('teacher_student_messages').insert({
      'student_id': studentId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'content': content,
      'is_hand_raise': isHandRaise,
    });
  }

  Future<List<Map<String, dynamic>>> getTeacherStudentMessages({
    required String studentId,
    int limit = 200,
  }) async {
    final query = _client
        .from('teacher_student_messages')
        .select()
        .eq('student_id', studentId);

    final response = await query
        .order('created_at', ascending: true)
        .limit(limit);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getTeacherStudentConversationSummaries() async {
    final students = await getAllStudents();
    final studentNameMap = <String, String>{};
    for (final s in students) {
      final id = s['id'] as String?;
      if (id == null) continue;
      studentNameMap[id] = (s['name'] as String?) ?? '未命名學生';
    }

    final response = await _client
        .from('teacher_student_messages')
        .select('student_id, content, created_at, is_hand_raise, sender_role')
        .order('created_at', ascending: false)
        .limit(5000);

    final latestByStudent = <String, Map<String, dynamic>>{};
    for (final row in (response as List).cast<Map<String, dynamic>>()) {
      final studentId = row['student_id'] as String?;
      if (studentId == null || latestByStudent.containsKey(studentId)) continue;
      latestByStudent[studentId] = {
        'student_id': studentId,
        'student_name': studentNameMap[studentId] ?? '未命名學生',
        'latest_content': row['content'] as String? ?? '',
        'latest_created_at': row['created_at'] as String?,
        'is_hand_raise': row['is_hand_raise'] == true,
        'latest_sender_role': row['sender_role'] as String? ?? '',
      };
    }

    for (final s in students) {
      final studentId = s['id'] as String?;
      if (studentId == null || latestByStudent.containsKey(studentId)) continue;
      latestByStudent[studentId] = {
        'student_id': studentId,
        'student_name': (s['name'] as String?) ?? '未命名學生',
        'latest_content': '',
        'latest_created_at': null,
        'is_hand_raise': false,
        'latest_sender_role': '',
      };
    }

    final list = latestByStudent.values.toList();
    list.sort((a, b) {
      final aTime = DateTime.tryParse((a['latest_created_at'] ?? '').toString());
      final bTime = DateTime.tryParse((b['latest_created_at'] ?? '').toString());
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return list;
  }

  Future<Map<String, dynamic>?> getLatestIncomingTeacherStudentMessage({
    required String currentUserId,
    required bool isTeacher,
  }) async {
    try {
      var query = _client
          .from('teacher_student_messages')
          .select('id, student_id, sender_id, sender_role, content, created_at');

      if (isTeacher) {
        query = query.eq('sender_role', 'student');
      } else {
        query = query.eq('sender_role', 'teacher').eq('student_id', currentUserId);
      }

      final row = await query
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      final senderId = row['sender_id']?.toString();
      if (senderId == currentUserId) return null;
      return row;
    } catch (e) {
      print('Error getting latest incoming teacher-student message: $e');
      return null;
    }
  }

  // Student Attention Management - 標記學生為「已完成」（解除關注狀態）
  Future<void> markStudentAttentionResolved(
    String studentId, {
    required String grammarTopicId,
    String? reason,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from('student_attention_resolved')
          .upsert({
            'student_id': studentId,
            'grammar_topic_id': grammarTopicId,
            'marked_by': currentUser.id,
            'reason': reason,
            'marked_at': DateTime.now().toIso8601String(),
          }, onConflict: 'student_id,grammar_topic_id');
    } catch (e) {
      print('Error marking student attention as resolved: $e');
      rethrow;
    }
  }

  // Student Attention Management - 取消標記（恢復關注狀態）
  Future<void> unmarkStudentAttentionResolved(
    String studentId, {
    required String grammarTopicId,
  }) async {
    try {
      await _client
          .from('student_attention_resolved')
          .delete()
          .eq('student_id', studentId)
          .eq('grammar_topic_id', grammarTopicId);
    } catch (e) {
      print('Error unmarking student attention resolved: $e');
      rethrow;
    }
  }

  // Student Attention Management - 檢查學生是否已被標記為「已完成」
  Future<bool> isStudentAttentionResolved(
    String studentId, {
    required String grammarTopicId,
  }) async {
    try {
      final response = await _client
          .from('student_attention_resolved')
          .select('id')
          .eq('student_id', studentId)
          .eq('grammar_topic_id', grammarTopicId)
          .limit(1);
      
      return (response as List).isNotEmpty;
    } catch (e) {
      print('Error checking if student attention is resolved: $e');
      return false;
    }
  }

  // Student Attention Management - 獲取所有已標記為「已完成」的學生 ID
  Future<Set<String>> getResolvedStudentIds() async {
    try {
      final response = await _client
          .from('student_attention_resolved')
          .select('student_id');
      
      return (response as List)
          .map((record) => record['student_id'] as String)
          .toSet();
    } catch (e) {
      print('Error getting resolved student IDs: $e');
      return {};
    }
  }

  // Student Attention Management - 獲取所有已標記為「已完成」的學生-課程鍵值
  Future<Set<String>> getResolvedStudentTopicKeys() async {
    try {
      final response = await _client
          .from('student_attention_resolved')
          .select('student_id, grammar_topic_id');

      return (response as List)
          .map((record) =>
              '${record['student_id'] as String}:${record['grammar_topic_id'] as String}')
          .toSet();
    } catch (e) {
      print('Error getting resolved student-topic keys: $e');
      return {};
    }
  }
}

