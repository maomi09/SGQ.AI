import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  bool _codeSent = false;
  bool _otpVerified = false; // 追蹤 OTP 是否驗證成功
  
  // 信箱檢查相關
  Timer? _emailCheckTimer;
  bool? _isEmailTaken;
  bool _isCheckingEmail = false;
  final _supabaseService = SupabaseService();

  @override
  void dispose() {
    _emailCheckTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _studentIdController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }
  
  Future<void> _checkEmailAvailability(String email) async {
    // 取消之前的計時器
    _emailCheckTimer?.cancel();
    
    // 重置狀態
    setState(() {
      _isEmailTaken = null;
      _isCheckingEmail = false;
    });
    
    // 如果信箱為空或格式不正確，不檢查
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      setState(() {
        _isEmailTaken = null;
        _isCheckingEmail = false;
      });
      return;
    }
    
    // 基本格式驗證
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(trimmedEmail)) {
      setState(() {
        _isEmailTaken = null;
        _isCheckingEmail = false;
      });
      return;
    }
    
    // 使用 debounce，等待 500ms 後再檢查
    _emailCheckTimer?.cancel();
    _emailCheckTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      
      print('Starting email check for: ${trimmedEmail.toLowerCase()}');
      setState(() {
        _isCheckingEmail = true;
        _isEmailTaken = null; // 重置狀態
      });
      
      try {
        final emailTaken = await _supabaseService.isEmailTaken(trimmedEmail.toLowerCase());
        print('Email check result for ${trimmedEmail.toLowerCase()}: $emailTaken');
        if (mounted) {
          setState(() {
            _isEmailTaken = emailTaken;
            _isCheckingEmail = false;
          });
          print('UI updated: _isEmailTaken = $_isEmailTaken');
        }
      } catch (e, stackTrace) {
        print('Error checking email: $e');
        print('Stack trace: $stackTrace');
        if (mounted) {
          setState(() {
            _isEmailTaken = true; // 發生錯誤時，假設已被使用（安全起見）
            _isCheckingEmail = false;
          });
        }
      }
    });
  }

  Future<void> _sendVerificationCode() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請先輸入電子郵件'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 檢查信箱是否已被使用
    if (_isEmailTaken == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('此電子郵件已被註冊，請更換'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.sendSignupOTP(_emailController.text.trim());

    if (success && mounted) {
      setState(() {
        _codeSent = true;
        _otpVerified = false; // 重置驗證狀態
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('驗證碼已發送到您的電子郵件，請查收'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? '發送驗證碼失敗'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      authProvider.clearError();
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    bool success;
    if (_isLogin) {
      success = await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      // 註冊模式：檢查驗證碼是否已驗證
      if (!_codeSent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('請先發送驗證碼'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (!_otpVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('請先驗證驗證碼'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // 驗證碼已驗證，進行註冊
      success = await authProvider.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
        'student',
        studentId: _studentIdController.text.trim(),
      );
    }

    if (success && mounted) {
      // Navigation will be handled by main.dart based on auth state
      // 給一點時間讓狀態更新並觸發 UI 重建
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (mounted) {
        // 再次檢查認證狀態，確保 UI 更新
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (!authProvider.isAuthenticated) {
          await authProvider.checkAuth();
        }
      }
    } else if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // 使用 AuthProvider 中的錯誤訊息，如果沒有則使用默認訊息
      String errorMessage = authProvider.errorMessage ?? 
          (_isLogin ? '登入失敗：請檢查帳號密碼是否正確' : '註冊失敗：請檢查輸入的資訊');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '確定',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
      
      // 清除錯誤訊息
      authProvider.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  // LOGO
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade100.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.school,
                      size: 64,
                      color: Colors.green.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isLogin ? 'SGQ.AI' : 'Create account',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Name',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '請輸入姓名';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _studentIdController,
                      decoration: InputDecoration(
                        hintText: 'Student ID',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '請輸入學號';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _emailController,
                    enabled: !_codeSent || _isLogin,
                    decoration: InputDecoration(
                      hintText: 'Email address',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _isEmailTaken == true ? Colors.red : Colors.grey[300]!,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _isEmailTaken == true ? Colors.red : Colors.grey[300]!,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _isEmailTaken == true ? Colors.red : Colors.blue,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      suffixIcon: !_isLogin && _emailController.text.isNotEmpty
                          ? (_isCheckingEmail
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : _isEmailTaken == true
                                  ? const Icon(Icons.error_outline, color: Colors.red)
                                  : _isEmailTaken == false
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : null)
                          : null,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    onChanged: !_isLogin ? (value) => _checkEmailAvailability(value) : null,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '請輸入電子郵件';
                      }
                      final trimmedValue = value.trim();
                      // 更嚴格的電子郵件格式驗證
                      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                      if (!emailRegex.hasMatch(trimmedValue)) {
                        return '請輸入有效的電子郵件格式';
                      }
                      // 在註冊模式下，檢查信箱是否已被使用
                      if (!_isLogin && _isEmailTaken == true) {
                        return '此電子郵件已被註冊';
                      }
                      return null;
                    },
                  ),
                  // 顯示錯誤提示
                  if (!_isLogin && _isEmailTaken == true && _emailController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '此電子郵件已被註冊',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // 註冊模式下的驗證碼相關 UI
                  if (!_isLogin) ...[
                    const SizedBox(height: 16),
                    if (_codeSent) ...[
                      // 已發送驗證碼，顯示驗證碼輸入框
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _verificationCodeController,
                              enabled: !_otpVerified,
                              decoration: InputDecoration(
                                labelText: '驗證碼',
                                hintText: _otpVerified ? '驗證碼已驗證' : '請輸入6位數驗證碼',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _otpVerified ? Colors.green : Colors.grey[300]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _otpVerified ? Colors.green : Colors.blue,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                prefixIcon: Icon(
                                  _otpVerified ? Icons.check_circle : Icons.verified_user,
                                  color: _otpVerified ? Colors.green : Colors.blue,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                              onChanged: (value) {
                                // 當驗證碼改變時，重置驗證狀態
                                if (_otpVerified && value.length < 6) {
                                  setState(() {
                                    _otpVerified = false;
                                  });
                                }
                              },
                              validator: (value) {
                                if (!_otpVerified) {
                                  if (value == null || value.isEmpty) {
                                    return '請輸入驗證碼';
                                  }
                                  if (value.length != 6) {
                                    return '驗證碼必須為6位數';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!_otpVerified)
                            ElevatedButton(
                              onPressed: () async {
                                final code = _verificationCodeController.text.trim();
                                if (code.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('請輸入驗證碼'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                if (code.length != 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('驗證碼必須為6位數'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                final verified = await authProvider.verifySignupOTP(
                                  _emailController.text.trim(),
                                  code,
                                );

                                if (verified) {
                                  setState(() {
                                    _otpVerified = true;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('驗證碼驗證成功'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(authProvider.errorMessage ?? '驗證碼錯誤或已過期'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  authProvider.clearError();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('驗證'),
                            )
                          else
                            TextButton(
                              onPressed: _isEmailTaken == true ? null : _sendVerificationCode,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              child: Text(
                                '重新發送',
                                style: TextStyle(
                                  color: _isEmailTaken == true ? Colors.grey : Colors.blue,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ] else ...[
                      // 未發送驗證碼，顯示發送按鈕
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _isEmailTaken == true ? null : _sendVerificationCode,
                          icon: Icon(
                            Icons.email_outlined,
                            color: _isEmailTaken == true ? Colors.grey : Colors.blue,
                          ),
                          label: Text(
                            '發送驗證碼',
                            style: TextStyle(
                              color: _isEmailTaken == true ? Colors.grey : Colors.blue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '請輸入密碼';
                      }
                      if (value.length < 6) {
                        return '密碼長度至少6個字元';
                      }
                      return null;
                    },
                  ),
                  if (_isLogin) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/forgot-password');
                        },
                        child: const Text(
                          'Forgot password',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      // 如果是註冊模式且 OTP 未驗證，禁用按鈕
                      final isButtonDisabled = authProvider.isLoading || 
                          (!_isLogin && !_otpVerified && _codeSent);
                      
                      return ElevatedButton(
                        onPressed: isButtonDisabled ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isButtonDisabled && !_isLogin 
                              ? Colors.grey 
                              : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: authProvider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _isLogin ? 'Sign in' : 'Sign up',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      );
                    },
                  ),
                  // 顯示提示訊息（如果是註冊模式且需要驗證碼）
                  if (!_isLogin && _codeSent && !_otpVerified)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '請先驗證驗證碼才能註冊',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      return OutlinedButton(
                        onPressed: authProvider.isLoading ? null : () async {
                          final success = await authProvider.signInWithGoogle();
                          if (!success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Google 登入失敗，請重試'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1F2937),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 使用 Google 官方圖標
                            Image.network(
                              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                              width: 20,
                              height: 20,
                              errorBuilder: (context, error, stackTrace) {
                                // 備用方案：使用官方 PNG
                                return Image.network(
                                  'https://developers.google.com/identity/images/g-logo.png',
                                  width: 20,
                                  height: 20,
                                  errorBuilder: (context, error, stackTrace) {
                                    // 最終備用方案：顯示文字 G
                                    return Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF4285F4),
                                            Color(0xFF34A853),
                                            Color(0xFFFBBC05),
                                            Color(0xFFEA4335),
                                          ],
                                          stops: [0.0, 0.33, 0.66, 1.0],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'G',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sign in with Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? "Don't have an account? " : 'Already have an account? ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            // 重置驗證碼狀態
                            _codeSent = false;
                            _otpVerified = false;
                            _verificationCodeController.clear();
                            // 重置信箱檢查狀態
                            _isEmailTaken = null;
                            _isCheckingEmail = false;
                            _emailCheckTimer?.cancel();
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _isLogin ? 'Sign up' : 'Sign in',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
