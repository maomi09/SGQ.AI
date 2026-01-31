class AppConfig {
  // Supabase 設定
  // 注意：Supabase URL 和 anon key 可以安全地放在客戶端
  // 這是 Supabase 的設計：anon key 是公開的，安全性通過 Row Level Security (RLS) 來保護
  // 與 ChatGPT API Key 不同，Supabase anon key 不需要保密
  static const String supabaseUrl = 'https://iqmhqdkpultzyzurolwv.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxbWhxZGtwdWx0enl6dXJvbHd2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4MDc1NzMsImV4cCI6MjA4MTM4MzU3M30.OfBqLiwFQLjyuJwkgU1Vu1eedjrzkeVsSznQAnR9B9Q';

  // 後端 API 設定
  // 注意：ChatGPT API Key 不應該放在客戶端，它應該只存在於後端伺服器的環境變數中
  // 所有 ChatGPT 請求都通過後端 API 進行，後端會使用環境變數中的 OPENAI_API_KEY
  
  // 生產環境：AWS 後端 URL（請替換為您的實際 AWS 後端地址）
  // 選項 1: 使用 EC2 公共 IP（開發/測試用）
  // static const String backendApiUrl = 'http://your-ec2-ip:8000';
  
  // 選項 2: 使用域名（推薦，生產環境）
  // static const String backendApiUrl = 'https://api.your-domain.com';
  
  // 選項 3: 使用 Elastic Beanstalk URL
  // static const String backendApiUrl = 'http://your-app.region.elasticbeanstalk.com';
  
  // 本地開發環境 URL（Android 模擬器使用 10.0.2.2，iOS 模擬器使用 localhost）
  static const String backendApiUrl = 'http://10.0.2.2:8000';
  
  // 注意：部署到生產環境時，請將上面的 backendApiUrl 改為您的 AWS 後端地址

  // Bundle ID 設定（用於深度連結和 OAuth 回調）
  // 重要：如果更改此值，請同時更新以下檔案：
  // 1. iOS: app/ios/Runner/Info.plist (CFBundleURLSchemes)
  // 2. iOS: app/ios/Runner.xcodeproj/project.pbxproj (PRODUCT_BUNDLE_IDENTIFIER)
  // 3. Android: app/android/app/src/main/AndroidManifest.xml (android:scheme)
  // 4. Android: app/android/app/build.gradle.kts (applicationId)
  // 5. Android: app/android/app/src/main/kotlin/.../MainActivity.kt (package name)
  // 6. Supabase Dashboard: Authentication > URL Configuration > Redirect URLs
  // 7. Google Cloud Console: OAuth 客戶端設定
  static const String bundleId = 'com.sgqai.app';

  // 生成深度連結 URL 的輔助方法
  static String getDeepLinkUrl(String path) {
    return '$bundleId://$path';
  }
}

