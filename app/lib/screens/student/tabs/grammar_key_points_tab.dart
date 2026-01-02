import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/grammar_topic_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../models/grammar_key_point_model.dart';
import '../../../utils/user_animal_helper.dart';
import '../../chatgpt/chatgpt_chat_screen.dart';
import '../../badges/badges_screen.dart';

class GrammarKeyPointsTab extends StatefulWidget {
  const GrammarKeyPointsTab({super.key});

  @override
  State<GrammarKeyPointsTab> createState() => _GrammarKeyPointsTabState();
}

class _GrammarKeyPointsTabState extends State<GrammarKeyPointsTab> {
  final SupabaseService _supabaseService = SupabaseService();
  List<GrammarKeyPointModel> _keyPoints = [];
  bool _isLoading = true;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context);
    if (grammarTopicProvider.selectedTopic != null) {
      _loadKeyPoints();
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
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.stars),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BadgesScreen(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat),
                        onPressed: () {
                          showChatDialog(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 主題選擇器
            if (grammarTopicProvider.selectedTopic == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
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
                        child: DropdownButton<String>(
                          value: null,
                          hint: const Text('請選擇文法主題'),
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: grammarTopicProvider.topics.map((topic) {
                            return DropdownMenuItem(
                              value: topic.id,
                              child: Text(topic.title),
                            );
                          }).toList(),
                          onChanged: (topicId) {
                            if (topicId != null) {
                              Provider.of<GrammarTopicProvider>(context, listen: false)
                                  .selectTopic(topicId);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFF1F2937)),
                      onPressed: () async {
                        final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
                        await grammarTopicProvider.loadTopics();
                      },
                      tooltip: '刷新',
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '文法主題: ${grammarTopicProvider.selectedTopic!.title}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  if (grammarTopicProvider.selectedTopic!.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      grammarTopicProvider.selectedTopic!.description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1F2937)),
                              onSelected: (topicId) {
                                Provider.of<GrammarTopicProvider>(context, listen: false)
                                    .selectTopic(topicId);
                              },
                              itemBuilder: (context) => grammarTopicProvider.topics.map((topic) {
                                return PopupMenuItem(
                                  value: topic.id,
                                  child: Text(topic.title),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFF1F2937)),
                      onPressed: () async {
                        final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
                        await grammarTopicProvider.loadTopics();
                        _loadKeyPoints();
                      },
                      tooltip: '刷新',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            // 內容區域
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
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
                      : _keyPoints.isEmpty
                          ? Center(
                              child: Text(
                                '此主題尚無文法重點',
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
                              itemCount: _keyPoints.length,
                              itemBuilder: (context, index) {
                                final point = _keyPoints[index];
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
