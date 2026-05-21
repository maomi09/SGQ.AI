import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/badge_model.dart';
import '../providers/class_provider.dart';
import '../providers/grammar_topic_provider.dart';
import '../services/supabase_service.dart';
import '../utils/error_handler.dart';

/// 授予學生獎牌（老師端數據頁／儀表板共用）。
Future<void> showTeacherAwardBadgeDialog({
  required BuildContext context,
  required SupabaseService supabaseService,
  required List<Map<String, dynamic>> studentsProgress,
}) async {
  final grammarTopicProvider =
      Provider.of<GrammarTopicProvider>(context, listen: false);
  final classProvider = Provider.of<ClassProvider>(context, listen: false);
  final classId = classProvider.selectedClass?.id;

  if (classId != null) {
    await grammarTopicProvider.loadTopics(classId: classId);
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      String? selectedStudentId;
      String? selectedGrammarTopicId;
      String selectedMedalType = 'bronze';

      return StatefulBuilder(
        builder: (context, setState) {
          final topics = classId != null
              ? grammarTopicProvider.topics
                  .where((t) => t.classId == classId)
                  .toList()
              : grammarTopicProvider.topics;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber),
                SizedBox(width: 8),
                Text('授予獎牌'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (classProvider.selectedClass == null)
                    Text(
                      '請先在頂部選擇班級',
                      style: TextStyle(color: Colors.orange[800]),
                    )
                  else if (topics.isEmpty)
                    const Text('此班級目前沒有課程')
                  else ...[
                    const Text(
                      '選擇課程',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedGrammarTopicId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('請選擇課程'),
                      items: topics
                          .map(
                            (topic) => DropdownMenuItem<String>(
                              value: topic.id,
                              child: Text(topic.title),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedGrammarTopicId = value;
                          selectedStudentId = null;
                        });
                      },
                    ),
                    if (selectedGrammarTopicId != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        '選擇學生',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedStudentId,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('請選擇學生'),
                        items: studentsProgress
                            .map(
                              (student) => DropdownMenuItem<String>(
                                value: student['student_id'] as String,
                                child: Text(
                                  '${student['student_name'] ?? student['student_email'] ?? '學生'} (${student['student_id_number'] ?? ''})',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => selectedStudentId = value);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (selectedStudentId != null) ...[
                      const Text(
                        '選擇獎牌',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _MedalOption(
                              name: '銅牌',
                              color: Colors.brown,
                              selected: selectedMedalType == 'bronze',
                              onTap: () =>
                                  setState(() => selectedMedalType = 'bronze'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MedalOption(
                              name: '銀牌',
                              color: Colors.grey,
                              selected: selectedMedalType == 'silver',
                              onTap: () =>
                                  setState(() => selectedMedalType = 'silver'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MedalOption(
                              name: '金牌',
                              color: Colors.amber,
                              selected: selectedMedalType == 'gold',
                              onTap: () =>
                                  setState(() => selectedMedalType = 'gold'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              if (selectedStudentId != null && selectedGrammarTopicId != null)
                ElevatedButton(
                  onPressed: () async {
                    final hasBadge = await supabaseService.hasBadgeForTopic(
                      selectedStudentId!,
                      selectedGrammarTopicId!,
                    );
                    if (hasBadge) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('該學生在此課程已有獎牌，無法重複授予'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                      return;
                    }
                    try {
                      await _awardBadge(
                        supabaseService,
                        selectedStudentId!,
                        selectedGrammarTopicId!,
                        selectedMedalType,
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('獎牌授予成功'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ErrorHandler.getSafeErrorMessage(e)),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('授予'),
                ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _awardBadge(
  SupabaseService supabaseService,
  String studentId,
  String grammarTopicId,
  String medalType,
) async {
  const medalNames = {
    'bronze': '銅牌',
    'silver': '銀牌',
    'gold': '金牌',
  };
  const medalDescriptions = {
    'bronze': '銅牌代表良好的學習表現，是對您努力的肯定。',
    'silver': '銀牌代表優秀的學習成果，展現了您的持續進步。',
    'gold': '金牌代表卓越的學習成就，是對您傑出表現的最高肯定。',
  };

  final badge = BadgeModel(
    id: '',
    studentId: studentId,
    badgeType: medalType,
    badgeName: medalNames[medalType] ?? medalType,
    description: medalDescriptions[medalType] ?? '',
    earnedAt: DateTime.now(),
    grammarTopicId: grammarTopicId,
  );

  await supabaseService.createBadge(badge);
}

/// 班級獎牌榜。
Future<void> showClassBadgeLeaderboardDialog({
  required BuildContext context,
  required SupabaseService supabaseService,
}) async {
  final classProvider = Provider.of<ClassProvider>(context, listen: false);
  final classModel = classProvider.selectedClass;

  if (classModel == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('請先在頂部選擇班級'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  final rows = await supabaseService.getClassBadgeLeaderboard(classModel.id);
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(child: Text('${classModel.name} 獎牌榜')),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: rows.isEmpty
            ? const Center(child: Text('此班級尚無獎牌紀錄'))
            : ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final earnedAt = row['earned_at'] as String?;
                  String earnedLabel = '';
                  if (earnedAt != null && earnedAt.isNotEmpty) {
                    try {
                      earnedLabel = earnedAt.split('T').first;
                    } catch (_) {
                      earnedLabel = earnedAt;
                    }
                  }
                  return ListTile(
                    leading: Icon(
                      Icons.emoji_events,
                      color: _medalColor(row['badge_type'] as String? ?? ''),
                    ),
                    title: Text(row['student_name'] as String? ?? '未設定姓名'),
                    subtitle: Text(
                      [
                        if ((row['student_id_number'] as String?)
                                ?.isNotEmpty ==
                            true)
                          '學號：${row['student_id_number']}',
                        '課程：${row['grammar_topic_title']}',
                        '獎牌：${row['badge_name']}',
                        if (earnedLabel.isNotEmpty) '日期：$earnedLabel',
                      ].join('\n'),
                    ),
                    isThreeLine: true,
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('關閉'),
        ),
      ],
    ),
  );
}

Color _medalColor(String type) {
  switch (type) {
    case 'gold':
      return Colors.amber;
    case 'silver':
      return Colors.grey;
    case 'bronze':
      return Colors.brown;
    default:
      return Colors.amber;
  }
}

class _MedalOption extends StatelessWidget {
  const _MedalOption({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.emoji_events, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
