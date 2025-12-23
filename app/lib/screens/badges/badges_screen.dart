import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/badge_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/grammar_topic_provider.dart';
import '../../models/grammar_topic_model.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // 在下一幀載入徽章，避免在 build 過程中觸發 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBadges();
    });
  }

  void _loadBadges() {
    if (_isInitialized) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      _isInitialized = true;
      badgeProvider.loadBadges(authProvider.currentUser!.id);
      grammarTopicProvider.loadTopics();
    }
  }

  // 獲取獎牌圖示和顏色
  Widget _getMedalIcon(String badgeType, double size) {
    switch (badgeType) {
      case 'bronze':
        return Icon(
          Icons.emoji_events,
          size: size,
          color: Colors.brown.shade400,
        );
      case 'silver':
        return Icon(
          Icons.emoji_events,
          size: size,
          color: Colors.grey.shade400,
        );
      case 'gold':
        return Icon(
          Icons.emoji_events,
          size: size,
          color: Colors.amber.shade600,
        );
      default:
        return Icon(
          Icons.stars,
          size: size,
          color: Colors.amber,
        );
    }
  }

  // 獲取獎牌顏色
  Color _getMedalColor(String badgeType) {
    switch (badgeType) {
      case 'bronze':
        return Colors.brown.shade400;
      case 'silver':
        return Colors.grey.shade400;
      case 'gold':
        return Colors.amber.shade600;
      default:
        return Colors.amber;
    }
  }

  // 統計各類型獎牌數量
  Map<String, int> _getMedalCounts(List badges) {
    int bronzeCount = 0;
    int silverCount = 0;
    int goldCount = 0;
    
    for (var badge in badges) {
      switch (badge.badgeType) {
        case 'bronze':
          bronzeCount++;
          break;
        case 'silver':
          silverCount++;
          break;
        case 'gold':
          goldCount++;
          break;
      }
    }
    
    return {
      'bronze': bronzeCount,
      'silver': silverCount,
      'gold': goldCount,
    };
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('未登入'),
        ),
      );
    }

    return Scaffold(
      body: Container(
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
        child: SafeArea(
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
                    const Expanded(
                      child: Text(
                        '我的徽章',
                        style: TextStyle(
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
              // 內容區域
              Expanded(
                child: Consumer<BadgeProvider>(
                  builder: (context, badgeProvider, child) {
                    if (badgeProvider.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final medalCounts = _getMedalCounts(badgeProvider.badges);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 獎牌統計卡片
                          Container(
                      width: double.infinity,
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
                            '獎牌統計',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMedalStatCard(
                                  '銅牌',
                                  medalCounts['bronze'] ?? 0,
                                  Colors.brown.shade400,
                                  '銅牌代表良好的學習表現，是對您努力的肯定。',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMedalStatCard(
                                  '銀牌',
                                  medalCounts['silver'] ?? 0,
                                  Colors.grey.shade400,
                                  '銀牌代表優秀的學習成果，展現了您的持續進步。',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMedalStatCard(
                                  '金牌',
                                  medalCounts['gold'] ?? 0,
                                  Colors.amber.shade600,
                                  '金牌代表卓越的學習成就，是對您傑出表現的最高肯定。',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                          const SizedBox(height: 24),
                          // 徽章列表
                          if (badgeProvider.badges.isEmpty)
                            Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(40),
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
                        child: const Center(
                          child: Text(
                            '尚未獲得任何徽章',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                          else ...[
                            const Text(
                              '所有徽章',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...badgeProvider.badges.map((badge) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
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
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 獎牌圖示
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: _getMedalColor(badge.badgeType).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: _getMedalIcon(badge.badgeType, 48),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // 徽章資訊
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            badge.medalName,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1F2937),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Builder(
                                      builder: (context) {
                                        final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
                                        final topic = grammarTopicProvider.topics.firstWhere(
                                          (t) => t.id == badge.grammarTopicId,
                                          orElse: () => GrammarTopicModel(
                                            id: badge.grammarTopicId,
                                            title: '未知課程',
                                            description: '',
                                            teacherId: '',
                                            createdAt: DateTime.now(),
                                          ),
                                        );
                                        return Row(
                                          children: [
                                            Icon(
                                              Icons.book_outlined,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                topic.title,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      badge.medalDescription,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                        height: 1.4,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '獲得時間: ${badge.earnedAt.toString().split(' ')[0]}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                            }).toList(),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedalStatCard(String name, int count, Color color, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events,
            color: color,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count 枚',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

