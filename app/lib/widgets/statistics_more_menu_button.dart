import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

/// 數據頁頂部「更多」選單。
///
/// iOS 26+：按鈕為一般圖示；點開後為 Liquid Glass 原生彈出選單。
/// 其餘平台：Material [PopupMenuButton]。
class StatisticsMoreMenuButton extends StatelessWidget {
  const StatisticsMoreMenuButton({
    super.key,
    required this.onAward,
    required this.onLeaderboard,
    required this.onProgress,
  });

  final VoidCallback onAward;
  final VoidCallback onLeaderboard;
  final VoidCallback onProgress;

  void _handleSelection(String? value) {
    switch (value) {
      case 'award':
        onAward();
        break;
      case 'leaderboard':
        onLeaderboard();
        break;
      case 'progress':
        onProgress();
        break;
    }
  }

  List<AdaptivePopupMenuEntry> get _ios26MenuItems => [
        const AdaptivePopupMenuItem<String>(
          label: '授予獎牌',
          value: 'award',
          icon: 'trophy.fill',
        ),
        const AdaptivePopupMenuItem<String>(
          label: '班級獎牌榜',
          value: 'leaderboard',
          icon: 'list.number',
        ),
        const AdaptivePopupMenuItem<String>(
          label: '課程完成進度',
          value: 'progress',
          icon: 'chart.pie.fill',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS26OrHigher()) {
      // 按鈕維持 Material 三點圖示（plain）；彈出選單為 iOS 26 Liquid Glass
      return AdaptivePopupMenuButton.widget<String>(
        buttonStyle: PopupButtonStyle.plain,
        items: _ios26MenuItems,
        onSelected: (_, entry) => _handleSelection(entry.value),
        child: const Tooltip(
          message: '更多功能',
          child: Icon(Icons.more_vert),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: '更多功能',
      icon: const Icon(Icons.more_vert),
      onSelected: _handleSelection,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'award',
          child: Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber.shade700),
              const SizedBox(width: 12),
              const Text('授予獎牌'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'leaderboard',
          child: Row(
            children: [
              Icon(Icons.leaderboard, color: Colors.green.shade700),
              const SizedBox(width: 12),
              const Text('班級獎牌榜'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'progress',
          child: Row(
            children: [
              Icon(Icons.assessment, color: Colors.green.shade700),
              const SizedBox(width: 12),
              const Text('課程完成進度'),
            ],
          ),
        ),
      ],
    );
  }
}
