# Apple 審查要求完成檢查清單

本文件用於確認所有 Apple App Store 審查要求是否已完成。

## ✅ 已完成的要求（代碼層面）

### 1. Guideline 4.8 - Sign in with Apple ✅

**要求**：提供符合要求的登入服務（Sign in with Apple）

**完成狀態**：
- [x] 已添加 `sign_in_with_apple` 套件到 `pubspec.yaml`
- [x] 已在登入畫面添加 "Sign in with Apple" 按鈕
- [x] 已在 `supabase_service.dart` 實現 `signInWithApple()` 方法
- [x] 已在 `auth_provider.dart` 實現 `signInWithApple()` 方法
- [x] 已在 Supabase Dashboard 配置 Apple Provider（需要您確認）

**檔案位置**：
- `app/pubspec.yaml` (line 63)
- `app/lib/screens/auth/login_screen.dart` (lines 793-835)
- `app/lib/services/supabase_service.dart` (lines 185-195)
- `app/lib/providers/auth_provider.dart` (lines 261-277)

**注意事項**：
- 需要在 Supabase Dashboard 中完成 Apple Provider 配置
- 需要在 Apple Developer Portal 完成 Service ID 和 Key 的設定

---

### 2. Guideline 5.1.1(v) - 帳號刪除功能 ✅

**要求**：提供用戶自行刪除帳號的功能

**完成狀態**：
- [x] 已在 `supabase_service.dart` 實現 `deleteAccount()` 方法
- [x] 已在 `auth_provider.dart` 實現 `deleteAccount()` 方法
- [x] 已創建 `account_deletion_screen.dart` 確認畫面
- [x] 已在個人資料頁面添加「刪除帳號」選項（位於「帳號資訊」區塊）

**檔案位置**：
- `app/lib/services/supabase_service.dart` (lines 1997-2027)
- `app/lib/providers/auth_provider.dart` (lines 704-725)
- `app/lib/screens/account_deletion_screen.dart` (完整檔案)
- `app/lib/screens/student/tabs/profile_tab.dart` (lines 337-376)

**功能特點**：
- 包含確認步驟（需要輸入「刪除帳號」文字）
- 包含最終確認對話框
- 完整刪除用戶相關資料（題目、徽章、對話記錄等）
- 刪除後自動登出

---

### 3. Guidelines 5.1.1(i) 和 5.1.2(i) - 隱私與數據共享 ✅

**要求**：明確說明與 ChatGPT 共享的數據，並獲得用戶許可

**完成狀態**：
- [x] 已更新隱私政策頁面，明確說明 ChatGPT 數據共享
- [x] 已在 ChatGPT 聊天畫面首次打開時顯示數據共享許可對話框
- [x] 對話框包含完整的數據共享說明
- [x] 使用 SharedPreferences 記錄用戶許可狀態

**檔案位置**：
- `app/lib/screens/privacy_policy_screen.dart` (lines 138-166)
- `app/lib/screens/chatgpt/chatgpt_chat_screen.dart` (lines 77-230)

**功能特點**：
- 明確說明共享的資料類型
- 明確說明資料接收方（OpenAI）
- 明確說明資料用途
- 提供連結到完整隱私權政策
- 用戶可以選擇同意或不同意
- 如果不同意，無法使用 ChatGPT 功能

---

## ⚠️ 需要手動完成的要求（App Store Connect）

### 4. Guideline 2.3.6 - 年齡評級設定 ⚠️

**要求**：修正年齡評級設定，移除 "In-App Controls" 選項

**完成狀態**：需要在 App Store Connect 手動修改

**操作步驟**：
1. 登入 [App Store Connect](https://appstoreconnect.apple.com/)
2. 選擇您的應用程式
3. 前往 **App Information** 頁面
4. 找到 **Age Rating** 區塊
5. 將以下選項改為 **"None"**：
   - **Parental Controls**: 改為 "None"
   - **Age Assurance**: 改為 "None"
6. 點擊 **Save**

**注意事項**：
- 這不是代碼問題，需要在後台設定
- 修改後需要重新提交審查

---

### 5. Guideline 2.3.10 - 更新截圖 ⚠️

**要求**：移除截圖中的 debug banners

**完成狀態**：需要在 App Store Connect 手動更新

**操作步驟**：
1. 登入 [App Store Connect](https://appstoreconnect.apple.com/)
2. 選擇您的應用程式
3. 前往 **App Store** > **iOS App** > **版本資訊**
4. 檢查所有截圖：
   - 移除包含 debug banners 的截圖
   - 上傳新的截圖（不包含 debug 資訊）
5. 確保所有截圖都反映應用程式的最新狀態
6. 點擊 **Save**

**注意事項**：
- 這不是代碼問題，需要在後台更新
- 建議使用實體設備截圖，避免模擬器的 debug 資訊
- 更新後需要重新提交審查

---

## 📋 完整檢查清單

### 代碼層面（已完成）✅

- [x] Sign in with Apple 功能已實現
- [x] 帳號刪除功能已實現
- [x] 隱私政策已更新（包含 ChatGPT 數據共享說明）
- [x] 數據共享許可對話框已實現
- [x] 所有相關檔案已更新

### 後端配置（需要確認）⚠️

- [ ] Supabase Apple Provider 已配置完成
  - [ ] Service ID 已填入
  - [ ] Team ID 已填入
  - [ ] Key ID 已填入
  - [ ] Secret Key (JWT) 已填入
  - [ ] Redirect URLs 已設定
- [ ] Apple Developer Portal 配置完成
  - [ ] App ID 已建立並啟用 Sign in with Apple
  - [ ] Service ID 已建立並配置
  - [ ] Key 已建立並下載 `.p8` 檔案
  - [ ] JWT token 已生成

### App Store Connect（需要手動完成）⚠️

- [ ] 年齡評級已修正（Parental Controls 和 Age Assurance 改為 "None"）
- [ ] 截圖已更新（移除 debug banners）

---

## 🚀 提交前的最後檢查

### 1. 測試所有功能

- [ ] 測試 Sign in with Apple 登入（iOS 實體設備）
- [ ] 測試帳號刪除功能
- [ ] 測試 ChatGPT 數據共享許可對話框
- [ ] 確認隱私政策頁面顯示正確

### 2. 確認配置

- [ ] Supabase Apple Provider 配置正確
- [ ] 所有 Redirect URLs 已設定
- [ ] Apple Developer Portal 配置完成

### 3. 更新 App Store Connect

- [ ] 年齡評級已修正
- [ ] 截圖已更新
- [ ] 應用程式描述和元數據已更新（如需要）

### 4. 準備回應 Apple 審查

如果 Apple 審查員詢問，您可以提供：

**Sign in with Apple 配置**：
- 說明已實現 Sign in with Apple 功能
- 提供登入畫面的截圖
- 說明功能位置：登入畫面，在 Google 登入按鈕下方

**帳號刪除功能**：
- 說明已實現帳號刪除功能
- 提供功能位置：個人資料頁面 > 帳號資訊區塊 > 刪除帳號
- 說明包含確認步驟以防止誤刪

**隱私與數據共享**：
- 說明已更新隱私政策，明確說明 ChatGPT 數據共享
- 說明在首次使用 ChatGPT 功能時會顯示許可對話框
- 提供隱私政策頁面的截圖

---

## 📝 回應 Apple 審查的範本

如果 Apple 審查員詢問，您可以使用以下回應：

### 關於 Sign in with Apple (Guideline 4.8)

"我們已經實現了 Sign in with Apple 功能。用戶可以在登入畫面看到 'Sign in with Apple' 按鈕，位於 Google 登入按鈕下方。此功能已完全配置並可以使用。"

### 關於帳號刪除 (Guideline 5.1.1(v))

"我們已經實現了帳號刪除功能。用戶可以在個人資料頁面的「帳號資訊」區塊中找到「刪除帳號」選項。刪除功能包含兩層確認步驟以防止誤刪，並會完整刪除用戶的所有相關資料。"

### 關於隱私與數據共享 (Guidelines 5.1.1(i) 和 5.1.2(i))

"我們已經更新了隱私權政策，明確說明與 ChatGPT 共享的數據類型、接收方和用途。此外，在用戶首次使用 ChatGPT AI 輔助功能時，我們會顯示詳細的數據共享許可對話框，明確告知用戶並獲得其同意。用戶可以在隱私權政策頁面查看完整說明。"

### 關於年齡評級 (Guideline 2.3.6)

"我們已經在 App Store Connect 中將 Parental Controls 和 Age Assurance 設定為 'None'，因為我們的應用程式不包含這些功能。"

### 關於截圖 (Guideline 2.3.10)

"我們已經更新了所有截圖，移除了 debug banners，現在所有截圖都反映應用程式的最新狀態。"

---

## ✅ 總結

**代碼層面**：所有要求已完成 ✅

**後端配置**：需要確認 Supabase 和 Apple Developer Portal 配置 ⚠️

**App Store Connect**：需要手動完成年齡評級和截圖更新 ⚠️

完成所有項目後，即可重新提交審查。
