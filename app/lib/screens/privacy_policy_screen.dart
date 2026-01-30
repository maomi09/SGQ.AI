import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('隱私權政策'),
        backgroundColor: Colors.green.shade400,
        foregroundColor: Colors.white,
      ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '隱私權政策',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '最後更新日期：${DateTime.now().year}年${DateTime.now().month}月${DateTime.now().day}日',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                '一、隱私權政策的適用範圍',
                '本隱私權政策適用於本應用程式（以下簡稱「本應用」）所提供的所有服務。當您使用本應用時，即表示您同意本隱私權政策的內容。',
              ),
              _buildSection(
                '二、個人資料的收集與使用',
                '本應用會收集以下類型的個人資料：\n\n'
                '1. 帳號資訊：包括姓名、電子郵件地址、學號等註冊時提供的資訊。\n'
                '2. 學習資料：包括您創建的題目、學習進度、階段完成情況等學習相關資料。\n'
                '3. 使用記錄：包括登入時間、使用時長、功能使用情況等使用記錄。\n'
                '4. 設備資訊：包括設備類型、作業系統版本、應用程式版本等技術資訊。\n\n'
                '我們收集這些資料的目的在於：\n'
                '• 提供個人化的學習服務\n'
                '• 追蹤學習進度並提供學習建議\n'
                '• 改善應用程式功能與使用者體驗\n'
                '• 提供技術支援與客戶服務',
              ),
              _buildSection(
                '三、資料的儲存與安全',
                '您的個人資料將儲存在安全的雲端資料庫中，我們採用以下措施保護您的資料安全：\n\n'
                '1. 資料加密：所有傳輸的資料均使用加密技術保護。\n'
                '2. 存取控制：僅授權人員可存取您的個人資料。\n'
                '3. 定期備份：定期備份資料以防止資料遺失。\n'
                '4. 安全更新：持續更新安全措施以應對新的威脅。',
              ),
              _buildSection(
                '四、資料的分享與揭露',
                '我們不會向第三方出售、交易或出租您的個人資料。在以下情況下，我們可能會分享您的資料：\n\n'
                '1. 服務提供者：與協助我們提供服務的第三方服務提供者（如雲端儲存服務）分享必要的資料。\n'
                '2. 法律要求：當法律要求或法院命令時，我們可能會揭露您的資料。\n'
                '3. 保護權利：為保護本應用、使用者或公眾的權利、財產或安全時。',
              ),
              _buildSection(
                '五、第三方服務',
                '本應用使用以下第三方服務，這些服務可能有其各自的隱私權政策：\n\n'
                '1. Supabase：用於資料儲存與使用者認證服務。\n'
                '2. OpenAI：用於提供 AI 學習輔助功能。\n\n'
                '我們建議您閱讀這些第三方服務的隱私權政策，以了解他們如何處理您的資料。',
              ),
              _buildSection(
                '六、您的權利',
                '您對您的個人資料享有以下權利：\n\n'
                '1. 查閱權：您可以隨時查看我們持有的您的個人資料。\n'
                '2. 更正權：您可以要求更正不正確或不完整的資料。\n'
                '3. 刪除權：您可以要求刪除您的個人資料，但某些法律要求保留的資料除外。\n'
                '4. 撤回同意：您可以隨時撤回對資料處理的同意。\n\n'
                '如需行使上述權利，請透過應用程式內的聯絡功能或電子郵件與我們聯繫。',
              ),
              _buildSection(
                '七、Cookie 與追蹤技術',
                '本應用可能會使用 Cookie 和類似的追蹤技術來改善使用者體驗、分析使用情況並提供個人化內容。您可以透過設備設定管理 Cookie 偏好。',
              ),
              _buildSection(
                '八、兒童隱私',
                '本應用主要面向教育用途，可能會有未滿 18 歲的使用者。我們會特別注意保護兒童的隱私，並遵守相關的兒童隱私保護法規。',
              ),
              _buildSection(
                '九、隱私權政策的變更',
                '我們可能會不定期更新本隱私權政策。重大變更時，我們會透過應用程式通知或電子郵件等方式通知您。繼續使用本應用即表示您接受更新後的政策。',
              ),
              _buildSection(
                '十、聯絡我們',
                '如果您對本隱私權政策有任何疑問、意見或需要行使您的權利，請透過以下方式與我們聯繫：\n\n'
                '• 應用程式內聯絡功能\n'
                '• 電子郵件：abcscoding@gmail.com\n\n'
                '我們會盡快回覆您的詢問。',
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}
