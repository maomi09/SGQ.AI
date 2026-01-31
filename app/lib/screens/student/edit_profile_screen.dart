import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/supabase_service.dart';

class EditProfileScreen extends StatefulWidget {
  final int initialIndex;
  
  const EditProfileScreen({super.key, this.initialIndex = 0});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  
  // 信箱檢查相關
  Timer? _emailCheckTimer;
  bool? _isEmailTaken;
  bool _isCheckingEmail = false;
  final _supabaseService = SupabaseService();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  late int _currentIndex;
  bool _isLoading = false;
  bool _emailCodeSent = false;
  bool _emailCodeVerified = false;
  bool _isSendingEmailCode = false;
  bool _isVerifyingCode = false;
  String? _selectedAnimal;

  // 可愛動物 emoji 列表（與 profile_tab.dart 保持一致）
  static const List<String> _animalEmojis = [
    '🐱', '🐶', '🐰', '🐻', '🐼', '🐨', '🐯', '🦁',
    '🐸', '🐷', '🐮', '🐹', '🐭', '🦊', '🐺', '🐨',
    '🦄', '🐝', '🦋', '🐢', '🐠', '🐬', '🐳', '🦉',
    '🐤', '🐧', '🦆', '🦅', '🦇', '🐿️', '🦔', '🦝',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _studentIdController.text = user.studentId ?? '';
      _emailController.text = user.email;
      
      // 載入用戶選擇的動物
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedAnimal = prefs.getString('user_animal_${user.id}');
        if (savedAnimal != null && _animalEmojis.contains(savedAnimal)) {
          setState(() {
            _selectedAnimal = savedAnimal;
          });
        }
      } catch (e) {
        print('Error loading user animal: $e');
      }
    }
  }

  @override
  void dispose() {
    _emailCheckTimer?.cancel();
    _nameController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    _verificationCodeController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  Future<void> _checkEmailAvailability(String email) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    
    // 如果新郵件與當前郵件相同，不需要檢查
    if (currentUser != null && email.trim().toLowerCase() == currentUser.email.toLowerCase()) {
      setState(() {
        _isEmailTaken = null;
        _isCheckingEmail = false;
      });
      return;
    }
    
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
    _emailCheckTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      
      print('Starting email check for: ${trimmedEmail.toLowerCase()}');
      setState(() {
        _isCheckingEmail = true;
        _isEmailTaken = null; // 重置狀態
      });
      
      try {
        final emailTaken = await _supabaseService.isEmailTaken(
          trimmedEmail.toLowerCase(),
          excludeUserId: currentUser?.id,
        );
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

  Future<void> _saveProfile() async {
    // 保存動物選擇
    if (_selectedAnimal != null) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      if (user != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_animal_${user.id}', _selectedAnimal!);
        } catch (e) {
          print('Error saving user animal: $e');
        }
      }
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    bool nameSuccess = true;
    bool studentIdSuccess = true;

    // 更新姓名
    if (_nameController.text.trim() != user.name) {
      nameSuccess = await authProvider.updateName(_nameController.text.trim());
    }

    // 更新學號
    final newStudentId = _studentIdController.text.trim();
    if (newStudentId != (user.studentId ?? '')) {
      studentIdSuccess = await authProvider.updateStudentId(newStudentId.isEmpty ? '' : newStudentId);
    }

    setState(() => _isLoading = false);

    if (mounted) {
      final allSuccess = nameSuccess && studentIdSuccess;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(allSuccess ? '資料已更新' : '部分更新失敗'),
          backgroundColor: allSuccess ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      
      if (allSuccess) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _sendEmailVerificationCode() async {
    final newEmail = _emailController.text.trim();
    
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請先輸入有效的電子郵件'),
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
    final currentUser = authProvider.currentUser;
    
    // 如果新郵件與當前郵件相同，不需要驗證
    if (currentUser != null && newEmail.toLowerCase() == currentUser.email.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('新電子郵件與目前相同，無需驗證'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    // 檢查信箱是否已被使用
    if (_isEmailTaken == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('此電子郵件已被其他帳號使用，請更換'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    setState(() => _isSendingEmailCode = true);

    final success = await authProvider.sendSignupOTP(newEmail);

    setState(() {
      _isSendingEmailCode = false;
      if (success) {
        _emailCodeSent = true;
        _emailCodeVerified = false;
      }
    });

    if (mounted) {
      final errorMsg = authProvider.errorMessage;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
              ? '驗證碼已發送到您的電子郵件，請查收'
              : (errorMsg ?? '發送驗證碼失敗'),
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      
      if (success) {
        authProvider.clearError();
      }
    }
  }

  Future<void> _verifyEmailCode() async {
    final newEmail = _emailController.text.trim();
    final code = _verificationCodeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請輸入驗證碼'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('驗證碼為 6 位數'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isVerifyingCode = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final verified = await authProvider.verifySignupOTP(newEmail, code);

    setState(() {
      _isVerifyingCode = false;
      _emailCodeVerified = verified;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(verified ? '驗證碼驗證成功，可以儲存' : '驗證碼錯誤或已過期'),
          backgroundColor: verified ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: verified ? 2 : 3),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
    }
  }

  Future<void> _saveEmail() async {
    final newEmail = _emailController.text.trim();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    // 如果新郵件與當前郵件相同，直接返回
    if (currentUser != null && newEmail.toLowerCase() == currentUser.email.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('新電子郵件與目前相同'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    // 檢查是否已驗證驗證碼
    if (!_emailCodeVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請先驗證新電子郵件的驗證碼'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await authProvider.updateEmail(newEmail);

    setState(() => _isLoading = false);

    if (mounted) {
      final errorMsg = authProvider.errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '電子郵件已更新' : (errorMsg ?? '更新失敗，請重試')),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      
      if (success) {
        authProvider.clearError();
        // 等待一下確保狀態更新完成
        await Future.delayed(const Duration(milliseconds: 500));
        // 不要調用 checkAuth，因為它可能會用 auth email 覆蓋 users 表的 email
        // 直接刷新用戶資料即可
        final user = authProvider.currentUser;
        if (user != null) {
          // 手動更新本地狀態，確保顯示新的 email
          print('Email updated successfully, new email: ${user.email}');
        }
        Navigator.pop(context);
      }
    }
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;

    final success = await authProvider.updatePassword(currentPassword, newPassword);

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '密碼已更新' : '更新失敗，目前密碼錯誤或請重試'),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      
      if (success) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.shade50,
                Colors.green.shade100,
                Colors.white,
              ],
            ),
          ),
          child: Column(
            children: [
              // 頂部標題欄
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        _getTitle(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // 平衡左側返回按鈕
                  ],
                ),
              ),
              // 表單內容
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        if (_currentIndex == 0) _buildProfileForm(),
                        if (_currentIndex == 1) _buildEmailForm(),
                        if (_currentIndex == 2) _buildPasswordForm(),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: (_isLoading || (_currentIndex == 1 && !_emailCodeVerified)) ? null : () {
                            if (_currentIndex == 0) {
                              _saveProfile();
                            } else if (_currentIndex == 1) {
                              _saveEmail();
                            } else if (_currentIndex == 2) {
                              _savePassword();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  '儲存',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return '編輯資料';
      case 1:
        return '修改信箱';
      case 2:
        return '修改密碼';
      default:
        return '編輯個人資料';
    }
  }

  Widget _buildProfileForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '個人資料',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '姓名',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '請輸入姓名';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _studentIdController,
                decoration: InputDecoration(
                  labelText: '學號',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '選擇動物樣式',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _animalEmojis.map((animal) {
                    final isSelected = _selectedAnimal == animal;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAnimal = animal;
                        });
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.green.shade100 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.green.shade600 : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            animal,
                            style: TextStyle(
                              fontSize: 28,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final isEmailChanged = currentUser != null && 
        _emailController.text.trim().toLowerCase() != currentUser.email.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '修改電子郵件',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 24),
              // 1. 新電子郵件欄位
              TextFormField(
                controller: _emailController,
                enabled: !_emailCodeVerified,
                decoration: InputDecoration(
                  labelText: '新電子郵件',
                  prefixIcon: const Icon(Icons.email_outlined),
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
                  filled: true,
                  fillColor: Colors.grey[50],
                  suffixIcon: _emailCodeVerified
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : _emailController.text.isNotEmpty
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
                onChanged: (value) {
                  // 檢查信箱是否已被使用
                  _checkEmailAvailability(value);
                  
                  // 當郵件改變時，重置驗證狀態
                  if (currentUser != null && 
                      value.trim().toLowerCase() != currentUser.email.toLowerCase()) {
                    setState(() {
                      _emailCodeSent = false;
                      _emailCodeVerified = false;
                      _verificationCodeController.clear();
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '請輸入新電子郵件';
                  }
                  if (!value.contains('@')) {
                    return '請輸入有效的電子郵件';
                  }
                  // 檢查信箱是否已被使用
                  if (_isEmailTaken == true) {
                    return '此電子郵件已被其他帳號使用';
                  }
                  return null;
                },
              ),
              // 顯示錯誤提示
              if (_isEmailTaken == true && _emailController.text.isNotEmpty && !_emailCodeVerified)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '此電子郵件已被其他帳號使用',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // 2. 驗證碼欄位（及時驗證）
              // 顯示條件：新郵件與當前郵件不同時顯示（發送驗證碼按鈕和驗證碼輸入框）
              if (isEmailChanged) ...[
                const SizedBox(height: 16),
                // 發送驗證碼按鈕（在發送驗證碼之前顯示）
                if (!_emailCodeSent) ...[
                  ElevatedButton(
                    onPressed: (_isSendingEmailCode || _isEmailTaken == true)
                        ? null
                        : _sendEmailVerificationCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[600],
                    ),
                    child: _isSendingEmailCode
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            '發送驗證碼',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
                // 驗證碼輸入框（發送驗證碼後顯示）
                if (_emailCodeSent) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _verificationCodeController,
                          decoration: InputDecoration(
                            labelText: '驗證碼',
                            prefixIcon: const Icon(Icons.verified_user_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _emailCodeVerified ? Colors.green : Colors.grey[300]!,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _emailCodeVerified ? Colors.green : Colors.blue,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            hintText: '請輸入驗證碼（輸入後自動驗證）',
                            suffixIcon: _isVerifyingCode
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
                                : _emailCodeVerified
                                    ? const Icon(Icons.check_circle, color: Colors.green)
                                    : null,
                          ),
                          keyboardType: TextInputType.number,
                          enabled: !_emailCodeVerified,
                          maxLength: 6,
                          onChanged: (value) {
                            // 當輸入 6 位數驗證碼時，自動驗證
                            if (value.length == 6 && !_emailCodeVerified && !_isVerifyingCode) {
                              _verifyEmailCode();
                            }
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '請輸入驗證碼';
                            }
                            if (value.length != 6) {
                              return '驗證碼為 6 位數';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  if (!_emailCodeVerified)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: (_isSendingEmailCode || _isEmailTaken == true)
                                ? null
                                : _sendEmailVerificationCode,
                            child: Text(
                              '重新發送驗證碼',
                              style: TextStyle(
                                fontSize: 12,
                                color: (_isSendingEmailCode || _isEmailTaken == true)
                                    ? Colors.grey
                                    : Colors.blue,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (_verificationCodeController.text.length == 6 && !_isVerifyingCode)
                            TextButton(
                              onPressed: _verifyEmailCode,
                              child: const Text(
                                '手動驗證',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ],
              if (_emailCodeVerified)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '驗證碼已驗證，可以儲存',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '修改密碼',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _currentPasswordController,
                decoration: InputDecoration(
                  labelText: '目前密碼',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入目前密碼';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: '新密碼',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入新密碼';
                  }
                  if (value.length < 6) {
                    return '密碼長度至少6個字元';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: '確認新密碼',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請確認新密碼';
                  }
                  if (value != _newPasswordController.text) {
                    return '新密碼與確認密碼不一致';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

