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
  // 例如：'https://your-domain.com' 或 'http://your-ec2-ip'
  // 注意：如果使用 EC2 IP，需要加上 http:// 或 https:// 前綴
  static const String backendApiUrl = 'http://13.219.229.38:8000';
  
  // 本地開發環境 URL（如需本地開發，請將上面的 backendApiUrl 改為此值）
  // static const String backendApiUrl = 'http://localhost:8000';
}

