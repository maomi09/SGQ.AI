import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/grammar_topic_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/ai_chat_settings_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../models/grammar_key_point_model.dart';
import '../../../utils/user_animal_helper.dart';
import '../../chatgpt/chatgpt_chat_screen.dart';
import '../../../widgets/cute_loading_indicator.dart';

class GrammarKeyPointsTab extends StatefulWidget {
  const GrammarKeyPointsTab({super.key});

  @override
  State<GrammarKeyPointsTab> createState() => _GrammarKeyPointsTabState();
}

class _GrammarKeyPointsTabState extends State<GrammarKeyPointsTab> {
  final SupabaseService _supabaseService = SupabaseService();
  List<GrammarKeyPointModel> _keyPoints = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _lastLoadedTopicId;

  @override
  void initState() {
    super.initState();
    _loadKeyPoints();
  }

  Future<void> _loadKeyPoints() async {
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
    if (grammarTopicProvider.selectedTopic == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final points = await _supabaseService.getGrammarKeyPoints(
        grammarTopicProvider.selectedTopic!.id,
      );
      setState(() {
        _keyPoints = points;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showTopicSelectionDialog() async {
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
    final topics = grammarTopicProvider.topics;

    if (topics.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('目前沒有可選擇的課程'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    final selectedTopicId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('選擇課程'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: topics.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final topic = topics[index];
              final isSelected = grammarTopicProvider.selectedTopic?.id == topic.id;
              return ListTile(
                title: Text(topic.title),
                subtitle: topic.description.isNotEmpty
                    ? Text(
                        topic.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: Colors.green.shade600)
                    : null,
                onTap: () => Navigator.pop(dialogContext, topic.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (selectedTopicId != null) {
      grammarTopicProvider.selectTopic(selectedTopicId);
      await _loadKeyPoints();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context);
    if (grammarTopicProvider.selectedTopic != null) {
      final currentTopicId = grammarTopicProvider.selectedTopic!.id;
      if (currentTopicId != _lastLoadedTopicId) {
        _lastLoadedTopicId = currentTopicId;
        _loadKeyPoints();
      }
    }
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
                        FutureBuilder<String>(
                          future: user != null ? UserAnimalHelper.getUserAnimal(user.id) : Future.value('👤'),
                          builder: (context, snapshot) {
                            final animal = snapshot.data ?? (user != null ? UserAnimalHelper.getDefaultAnimal(user.id) : '👤');
                            return CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.green.shade400,
                              child: Text(
                                animal,
                                style: const TextStyle(
                                  fontSize: 32,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '文法重點',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              if (grammarTopicProvider.selectedTopic != null)
                                Text(
                                  grammarTopicProvider.selectedTopic!.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else
                                Text(
                                  '請選擇主題',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 右側圖標
                  Consumer<AiChatSettingsProvider>(
                    builder: (context, aiSettings, _) {
                      return Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: '刷新',
                            onPressed: () async {
                              final grammarTopicProvider = Provider.of<GrammarTopicProvider>(
                                context,
                                listen: false,
                              );
                              setState(() {
                                _isRefreshing = true;
                              });
                              try {
                                await grammarTopicProvider.loadTopics(
                                  classId: grammarTopicProvider.currentClassId,
                                );
                                if (grammarTopicProvider.selectedTopic != null) {
                                  await _loadKeyPoints();
                                }
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isRefreshing = false;
                                  });
                                }
                              }
                            },
                          ),
                          if (aiSettings.isEnabled)
                            IconButton(
                              icon: const Icon(Icons.chat),
                              onPressed: () {
                                showChatDialog(context);
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            // 主題選擇器
            if (grammarTopicProvider.selectedTopic == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: InkWell(
                  onTap: _showTopicSelectionDialog,
                  borderRadius: BorderRadius.circular(16),
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
                        const Expanded(
                          child: Text(
                            '請選擇文法主題',
                            style: TextStyle(fontSize: 16, color: Color(0xFF1F2937)),
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down, color: Colors.grey[700]),
                      ],
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: InkWell(
                  onTap: _showTopicSelectionDialog,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
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
                      children: [
                        Expanded(
                          child: Text(
                            grammarTopicProvider.selectedTopic!.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1F2937)),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            // 內容區域
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CuteLoadingIndicator(
                        label: _isRefreshing ? '重新整理中' : '載入中...',
                      ),
                    )
                  : grammarTopicProvider.selectedTopic == null
                      ? Center(
                          child: Text(
                            '請先選擇文法主題',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(
                            left: 20,
                            right: 20,
                            bottom: MediaQuery.of(context).padding.bottom + 100,
                          ),
                          itemCount:
                              (grammarTopicProvider.selectedTopic!.description.isNotEmpty ? 1 : 0) +
                                  (_keyPoints.isEmpty ? 1 : _keyPoints.length),
                          itemBuilder: (context, index) {
                            final hasDescription =
                                grammarTopicProvider.selectedTopic!.description.isNotEmpty;
                            final descriptionOffset = hasDescription ? 1 : 0;

                            if (hasDescription && index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    grammarTopicProvider.selectedTopic!.description,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                      height: 1.4,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }

                            if (_keyPoints.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: Center(
                                  child: Text(
                                    '此主題尚無文法重點',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              );
                            }

                            final point = _keyPoints[index - descriptionOffset];
                            return Container(
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.flag,
                                          color: Colors.blue.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          point.title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    point.content,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey[700],
                                      height: 1.5,
                                    ),
                                  ),
                                ],
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
}
