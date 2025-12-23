import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';
import '../../../models/grammar_key_point_model.dart';

class EditKeyPointsScreen extends StatefulWidget {
  final String grammarTopicId;

  const EditKeyPointsScreen({super.key, required this.grammarTopicId});

  @override
  State<EditKeyPointsScreen> createState() => _EditKeyPointsScreenState();
}

class _EditKeyPointsScreenState extends State<EditKeyPointsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<GrammarKeyPointModel> _keyPoints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKeyPoints();
  }

  Future<void> _loadKeyPoints() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final points = await _supabaseService.getGrammarKeyPoints(widget.grammarTopicId);
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

  Future<void> _addKeyPoint() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    final result = await showDialog<bool>(
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
                  Icon(Icons.add_circle, color: Colors.orange.shade600),
                  const SizedBox(width: 8),
                  const Text(
                    '新增文法重點',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: '標題',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: InputDecoration(
                  labelText: '內容',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('建立'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true && titleController.text.isNotEmpty) {
      await _supabaseService.createGrammarKeyPoint(
        widget.grammarTopicId,
        titleController.text,
        contentController.text,
        _keyPoints.length,
      );
      _loadKeyPoints();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '編輯文法重點',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle, color: Colors.green.shade600),
                  onPressed: _addKeyPoint,
                  tooltip: '新增文法重點',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _keyPoints.isEmpty
                      ? Center(
                          child: Text(
                            '尚無文法重點',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _keyPoints.length,
                          itemBuilder: (context, index) {
                            final point = _keyPoints[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          point.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        if (point.content.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            point.content,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red.shade600),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          title: const Text('確認刪除'),
                                          content: const Text('確定要刪除此文法重點嗎？'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('取消'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                              child: const Text('刪除'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await _supabaseService.deleteGrammarKeyPoint(point.id);
                                        _loadKeyPoints();
                                      }
                                    },
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
    );
  }
}

