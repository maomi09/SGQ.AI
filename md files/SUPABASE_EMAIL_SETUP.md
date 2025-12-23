# Supabase Email Auth 設置指南

## 如何找到 Email Auth 設置

### 方法 1：通過 Authentication Settings

1. 登入 [Supabase Dashboard](https://supabase.com/dashboard)
2. 選擇您的專案
3. 在左側導航欄中，點擊 **Authentication**
4. 點擊 **Providers** 標籤
5. 找到 **Email** 選項
6. 確認以下設置：
   - ✅ **Enable email provider** 應該已啟用
   - **Confirm email** - 如果是開發環境，可以暫時關閉
   - **Secure email change** - 可以保持啟用

### 方法 2：檢查項目設置

1. 在 Supabase Dashboard 中，點擊左側的 **Settings**（齒輪圖標）
2. 選擇 **API** 或 **General**
3. 檢查項目配置

### 方法 3：檢查 Authentication 配置

1. 前往 **Authentication** > **URL Configuration**
2. 確認 **Site URL** 設置正確
3. 確認 **Redirect URLs** 包含您的應用程式 URL

## 常見問題解決方案

### 問題 1：Email 被認為無效

**可能原因：**
- Supabase 的 Email 驗證規則過於嚴格
- Email 格式不符合 Supabase 的要求
- 項目設置中的 Email 驗證規則

**解決方案：**
1. 嘗試使用標準格式的 Email（例如：`test@gmail.com`）
2. 確認 Email 沒有多餘的空格或特殊字符
3. 檢查 Supabase 項目是否有限制特定 Email 域名的設置

### 問題 2：無法找到 Email Auth 設置

**如果找不到 Email Auth 設置：**

1. **檢查項目權限**：確認您有管理員權限
2. **檢查項目版本**：某些設置可能在不同版本的 Supabase 中位置不同
3. **使用 SQL 查詢**：可以通過 SQL Editor 檢查設置

## 使用 SQL 檢查設置

在 SQL Editor 中執行以下查詢：

```sql
-- 檢查 auth 配置（如果可訪問）
SELECT * FROM auth.config;
```

## 臨時解決方案

如果無法找到設置，可以嘗試：

1. **使用不同的 Email 地址**：嘗試使用其他格式的 Email
2. **檢查 Email 格式**：確保 Email 格式正確（例如：`user@domain.com`）
3. **聯繫 Supabase 支持**：如果問題持續，可能需要聯繫 Supabase 支持

## 測試 Email 格式

嘗試使用以下格式的 Email：
- `test@gmail.com`
- `user@example.com`
- `name.surname@domain.com`

避免使用：
- 包含多個連續點的 Email
- 包含特殊字符的 Email（除非是標準格式）
- 過長的 Email 地址

