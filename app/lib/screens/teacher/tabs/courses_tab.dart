import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/grammar_topic_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/grammar_topic_model.dart';
import 'edit_grammar_topic_screen.dart';
import 'edit_key_points_screen.dart';
import 'edit_reminders_screen.dart';

class CoursesTab extends StatefulWidget {
  const CoursesTab({super.key});

  @override
  State<CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<CoursesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GrammarTopicProvider>(context, listen: false).loadTopics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

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
                            user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'T',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '課程管理',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              Text(
                                '管理文法主題與內容',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 右側圖標
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () {
                          // TODO: 通知功能
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.insights_outlined),
                        onPressed: () {
                          // TODO: 統計功能
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 新增課程按鈕
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade400,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, color: Colors.grey[800]),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _showAddTopicDialog(context, grammarTopicProvider, authProvider);
                      },
                      child: const Text(
                        '新增課程',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 課程列表
            Expanded(
              child: grammarTopicProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : grammarTopicProvider.topics.isEmpty
                      ? Center(
                          child: Text(
                            '尚無課程',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: grammarTopicProvider.topics.length,
                          itemBuilder: (context, index) {
                            final topic = grammarTopicProvider.topics[index];
                            return InkWell(
                              onTap: () {
                                _showCourseEditDialog(context, topic, grammarTopicProvider);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(20),
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
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.book,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            topic.title,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1F2937),
                                            ),
                                          ),
                                          if (topic.description.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              topic.description,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
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
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCourseEditDialog(BuildContext context, GrammarTopicModel topic, GrammarTopicProvider grammarTopicProvider) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.edit, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  const Text(
                    '課程管理',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            if (topic.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                topic.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildEditOption(
                        context,
                        icon: Icons.edit,
                        title: '編輯課程內容',
                        subtitle: '修改課程名稱與描述',
                        color: Colors.blue,
                onTap: () async {
                  Navigator.pop(context);
                  await showDialog(
                    context: context,
                    builder: (context) => EditGrammarTopicScreen(topic: topic),
                  );
                  grammarTopicProvider.loadTopics();
                },
                      ),
                      const SizedBox(height: 12),
                      _buildEditOption(
                        context,
                        icon: Icons.flag,
                        title: '編輯文法重點',
                        subtitle: '管理課程的文法重點內容',
                        color: Colors.orange,
                onTap: () async {
                  Navigator.pop(context);
                  await showDialog(
                    context: context,
                    builder: (context) => EditKeyPointsScreen(grammarTopicId: topic.id),
                  );
                },
                      ),
                      const SizedBox(height: 12),
                      _buildEditOption(
                        context,
                        icon: Icons.list,
                        title: '編輯出題重點提醒',
                        subtitle: '管理出題時的提醒事項',
                        color: Colors.purple,
                onTap: () async {
                  Navigator.pop(context);
                  await showDialog(
                    context: context,
                    builder: (context) => EditRemindersScreen(grammarTopicId: topic.id),
                  );
                },
                      ),
                      const SizedBox(height: 12),
                      _buildEditOption(
                        context,
                        icon: Icons.delete,
                        title: '刪除課程',
                        subtitle: '永久刪除此課程',
                        color: Colors.red,
                        onTap: () async {
                          print('=== 刪除按鈕被點擊 ===');
                          print('課程 ID: ${topic.id}');
                          print('課程標題: ${topic.title}');
                          
                          // 保存 topic 信息
                          final topicId = topic.id;
                          
                          // 先保存有效的 context（在關閉對話框之前）
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final navigatorState = Navigator.of(context, rootNavigator: true);
                          
                          // 先關閉當前對話框
                          Navigator.pop(context);
                          
                          // 等待對話框關閉動畫完成
                          await Future.delayed(const Duration(milliseconds: 300));
                          
                          print('顯示確認刪除對話框...');
                          final confirm = await showDialog<bool>(
                            context: navigatorState.context,
                            builder: (dialogBuilderContext) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Text('確認刪除'),
                              content: const Text('確定要刪除此課程嗎？此操作無法復原。'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    print('用戶點擊取消');
                                    Navigator.pop(dialogBuilderContext, false);
                                  },
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    print('用戶點擊確認刪除');
                                    Navigator.pop(dialogBuilderContext, true);
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('刪除'),
                                ),
                              ],
                            ),
                          );
                          
                          print('確認對話框返回: $confirm');
                          
                          if (confirm == true) {
                            print('用戶確認刪除，開始執行刪除操作');
                            
                            // 顯示載入指示器
                            showDialog(
                              context: navigatorState.context,
                              barrierDismissible: false,
                              builder: (loadingBuilderContext) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                            
                            try {
                              print('Deleting topic: $topicId');
                              await grammarTopicProvider.deleteTopic(topicId);
                              
                              // 關閉載入指示器
                              if (navigatorState.mounted) {
                                Navigator.pop(navigatorState.context);
                              }
                              
                              // 顯示成功訊息
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: const Text('課程已成功刪除'),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            } catch (e, stackTrace) {
                              print('=== UI 層刪除錯誤 ===');
                              print('錯誤: $e');
                              print('堆疊: $stackTrace');
                              
                              // 關閉載入指示器
                              if (navigatorState.mounted) {
                                Navigator.pop(navigatorState.context);
                              }
                              
                              // 顯示錯誤訊息
                              String errorMessage = '刪除失敗';
                              final errorStr = e.toString();
                              
                              // 解析錯誤訊息
                              if (errorStr.contains('權限') || 
                                  errorStr.contains('permission') || 
                                  errorStr.contains('policy') ||
                                  errorStr.contains('RLS')) {
                                errorMessage = '刪除失敗：沒有權限刪除此課程\n請確認已執行 SQL 政策文件';
                              } else if (errorStr.contains('找不到') || 
                                        errorStr.contains('not found') ||
                                        errorStr.contains('不存在')) {
                                errorMessage = '刪除失敗：找不到該課程';
                              } else if (errorStr.contains('未登入') || 
                                        errorStr.contains('not logged')) {
                                errorMessage = '刪除失敗：請先登入';
                              } else if (errorStr.contains('老師') && 
                                        errorStr.contains('只有')) {
                                errorMessage = errorStr;
                              } else {
                                // 顯示完整錯誤訊息（截取前200字符避免過長）
                                final fullError = errorStr.length > 200 
                                    ? '${errorStr.substring(0, 200)}...' 
                                    : errorStr;
                                errorMessage = '刪除失敗：$fullError';
                              }
                              
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    errorMessage,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  duration: const Duration(seconds: 5),
                                  action: SnackBarAction(
                                    label: '查看日誌',
                                    textColor: Colors.white,
                                    onPressed: () {
                                      print('完整錯誤訊息: $e');
                                      print('完整堆疊: $stackTrace');
                                    },
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '關閉',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color == Colors.red ? Colors.red.shade700 : Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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
    );
  }

  void _showAddTopicDialog(BuildContext context, GrammarTopicProvider provider, AuthProvider authProvider) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('新增課程'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: '課程名稱',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: '課程描述',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty && authProvider.currentUser != null) {
                await provider.createTopic(
                  titleController.text,
                  descriptionController.text,
                  authProvider.currentUser!.id,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('建立'),
          ),
        ],
      ),
    );
  }
}
