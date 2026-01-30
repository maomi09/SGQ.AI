import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final students = await _supabaseService.getAllStudents();
      if (mounted) {
        setState(() {
          _students = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '載入學生列表失敗: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteStudent(String studentId, String studentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除學生「$studentName」的帳號嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 顯示載入指示器
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await _supabaseService.deleteStudent(studentId);
      if (mounted) {
        Navigator.pop(context); // 關閉載入指示器
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('學生帳號已刪除')),
        );
        _loadStudents(); // 重新載入列表
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 關閉載入指示器
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刪除失敗: $e')),
        );
      }
    }
  }

  void _showResetPasswordDialog(Map<String, dynamic> student) {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('重置密碼 - ${student['name'] ?? '學生'}'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '為學生「${student['name'] ?? '未設定姓名'}」設置新密碼',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: '新密碼',
                    border: OutlineInputBorder(),
                    hintText: '至少6個字符',
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '請輸入新密碼';
                    }
                    if (value.length < 6) {
                      return '密碼長度至少需要6個字符';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: '確認密碼',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '請確認密碼';
                    }
                    if (value != passwordController.text) {
                      return '密碼不一致';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final newPassword = passwordController.text;

              Navigator.pop(context); // 關閉對話框

              // 顯示載入指示器
              if (!mounted) return;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                await _supabaseService.resetStudentPassword(
                  student['email'] as String,
                  newPassword,
                );
                if (mounted) {
                  Navigator.pop(context); // 關閉載入指示器
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('學生密碼已重置')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // 關閉載入指示器
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('重置失敗: $e')),
                  );
                }
              }
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> student) {
    final nameController = TextEditingController(text: student['name'] ?? '');
    final emailController = TextEditingController(text: student['email'] ?? '');
    final studentIdController = TextEditingController(text: student['student_id'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('編輯學生資料'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '姓名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: '電子郵件',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: studentIdController,
                decoration: const InputDecoration(
                  labelText: '學號',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newEmail = emailController.text.trim();
              final newStudentId = studentIdController.text.trim();

              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('姓名不能為空')),
                );
                return;
              }

              if (newEmail.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('電子郵件不能為空')),
                );
                return;
              }

              Navigator.pop(context); // 關閉對話框

              // 顯示載入指示器
              if (!mounted) return;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                await _supabaseService.updateStudent(
                  student['id'] as String,
                  name: newName,
                  email: newEmail,
                  studentIdNumber: newStudentId,
                );
                if (mounted) {
                  Navigator.pop(context); // 關閉載入指示器
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('學生資料已更新')),
                  );
                  _loadStudents(); // 重新載入列表
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // 關閉載入指示器
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('更新失敗: $e')),
                  );
                }
              }
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理學生帳號'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStudents,
                        child: const Text('重試'),
                      ),
                    ],
                  ),
                )
              : _students.isEmpty
                  ? Center(
                      child: Text(
                        '尚無學生帳號',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: MediaQuery.of(context).padding.bottom + 100,
                      ),
                      itemCount: _students.length,
                      itemBuilder: (context, index) {
                        final student = _students[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Text(
                              student['name'] ?? '未設定姓名',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (student['email'] != null)
                                  Text('電子郵件: ${student['email']}'),
                                if (student['student_id'] != null)
                                  Text('學號: ${student['student_id']}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  color: Colors.blue,
                                  onPressed: () => _showEditDialog(student),
                                  tooltip: '編輯資料',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.lock_reset),
                                  color: Colors.orange,
                                  onPressed: () => _showResetPasswordDialog(student),
                                  tooltip: '重置密碼',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  color: Colors.red,
                                  onPressed: () => _deleteStudent(
                                    student['id'] as String,
                                    student['name'] ?? '未設定姓名',
                                  ),
                                  tooltip: '刪除帳號',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

