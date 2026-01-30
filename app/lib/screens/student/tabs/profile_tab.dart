import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/grammar_topic_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/user_animal_helper.dart';
import '../edit_profile_screen.dart';
import '../../teacher/student_management_screen.dart';
import '../../privacy_policy_screen.dart';
import '../../report_bug_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String? _userAnimal;
  String _appVersion = '載入中...';
  String _buildNumber = '';
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadUserAnimal();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
          _buildNumber = packageInfo.buildNumber;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = '未知';
        });
      }
    }
  }

  Future<void> _loadUserAnimal() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user != null) {
      final animal = await UserAnimalHelper.getUserAnimal(user.id);
      if (mounted) {
        setState(() {
          _userAnimal = animal;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return const Center(
        child: Text('未登入'),
      );
    }

    // 如果動物還沒載入，使用基於ID的默認動物
    final displayAnimal = _userAnimal ?? UserAnimalHelper.getDefaultAnimal(user.id);

    return SafeArea(
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
            // 頂部區域
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  // 頭像和問候語
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.green.shade400,
                          child: Text(
                            displayAnimal,
                            style: const TextStyle(
                              fontSize: 32,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hi, ${user.name}!',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 右側圖標（僅學生顯示通知）
                  if (user.role == 'student')
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () => _showTeacherCommentsDialog(context, user.id),
                    ),
                ],
              ),
            ),
            // 主要內容區域
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 個人資料卡片
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // 動物圖示（右邊大圖）
                          Positioned(
                            right: 16,
                            top: 16,
                            child: Text(
                              displayAnimal,
                              style: const TextStyle(
                                fontSize: 80,
                              ),
                            ),
                          ),
                          // 內容（左邊）
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '個人資料',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                user.name,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              if (user.studentId != null && user.studentId!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  user.studentId!,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                user.role == 'student' ? '學生' : '老師',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 操作按鈕
                    Wrap(
                      alignment: WrapAlignment.spaceAround,
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildActionButton(
                          context,
                          icon: Icons.edit,
                          label: '編輯資料',
                          color: Colors.blue,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(initialIndex: 0),
                            ),
                          ).then((_) {
                            // 返回時刷新資料和動物
                            authProvider.checkAuth();
                            _loadUserAnimal();
                          }),
                        ),
                        _buildActionButton(
                          context,
                          icon: Icons.email,
                          label: '修改信箱',
                          color: Colors.green,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(initialIndex: 1),
                            ),
                          ).then((_) {
                            // 返回時刷新資料
                            authProvider.checkAuth();
                          }),
                        ),
                        _buildActionButton(
                          context,
                          icon: Icons.lock,
                          label: '修改密碼',
                          color: Colors.orange,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(initialIndex: 2),
                            ),
                          ),
                        ),
                        if (user.role == 'teacher')
                          _buildActionButton(
                            context,
                            icon: Icons.people,
                            label: '管理學生',
                            color: Colors.purple,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StudentManagementScreen(),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // 帳號資訊區塊
                    const Text(
                      '帳號資訊',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      context,
                      icon: Icons.person_outline,
                      title: '姓名',
                      value: user.name,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      context,
                      icon: Icons.email_outlined,
                      title: '電子郵件',
                      value: user.email,
                    ),
                    if (user.studentId != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        context,
                        icon: Icons.badge_outlined,
                        title: '學號',
                        value: user.studentId!,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      context,
                      icon: Icons.people_outline,
                      title: '身分',
                      value: user.role == 'student' ? '學生' : '老師',
                    ),
                    const SizedBox(height: 32),
                    // 應用資訊區塊
                    const Text(
                      '應用資訊',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      context,
                      icon: Icons.info_outline,
                      title: '版本號',
                      value: '$_appVersion (Build $_buildNumber)',
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.privacy_tip_outlined,
                                color: Colors.green.shade600,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '隱私權政策',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '查看完整隱私權政策',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReportBugScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.bug_report_outlined,
                                color: Colors.orange.shade600,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '回報錯誤',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '回報問題或提供建議',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // 登出按鈕
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20),
                      child: ElevatedButton(
                        onPressed: () async {
                          await authProvider.signOut();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '登出',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onTap,
              color: Colors.grey[600],
            ),
        ],
      ),
    );
  }

  // 顯示老師評語通知對話框
  Future<void> _showTeacherCommentsDialog(BuildContext context, String studentId) async {
    try {
      // 獲取所有題目
      final questions = await _supabaseService.getQuestions(studentId);
      
      // 過濾出有老師評語的題目
      final questionsWithComments = questions
          .where((q) => q.teacherComment != null && q.teacherComment!.isNotEmpty)
          .toList();
      
      // 按評語更新時間排序（最新的在前）
      questionsWithComments.sort((a, b) {
        final aTime = a.teacherCommentUpdatedAt ?? a.createdAt;
        final bTime = b.teacherCommentUpdatedAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      
      // 獲取課程資訊
      final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
      await grammarTopicProvider.loadTopics();
      final topics = grammarTopicProvider.topics;
      final topicMap = <String, String>{};
      for (var topic in topics) {
        topicMap[topic.id] = topic.title;
      }
      
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_active, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '老師出題訊息',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (questionsWithComments.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '目前沒有老師的評語',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: questionsWithComments.length,
                      itemBuilder: (context, index) {
                        final question = questionsWithComments[index];
                        final topicName = topicMap[question.grammarTopicId] ?? '未知課程';
                        final updateTime = question.teacherCommentUpdatedAt ?? question.createdAt;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.book_outlined,
                                    size: 20,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      topicName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    DateFormat('yyyy-MM-dd').format(updateTime),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  question.teacherComment!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('關閉'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入通知失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}
