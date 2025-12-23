# 如何從 Supabase 後台新增老師帳號

## 方法一：通過 Supabase Dashboard（推薦）

### 步驟 1：在 Authentication 中創建用戶

1. 登入 [Supabase Dashboard](https://supabase.com/dashboard)
2. 選擇您的專案
3. 前往 **Authentication** > **Users**
4. 點擊右上角的 **Add user** 按鈕
5. 填寫以下資訊：
   - **Email**: 老師的電子郵件（例如：teacher@example.com）
   - **Password**: 設定一個安全的密碼
   - **Auto Confirm User**: ✅ 勾選（自動確認用戶，無需驗證郵件）
   - **Send invitation email**: ❌ 取消勾選（不需要發送邀請郵件）
6. 點擊 **Create user**
7. **重要**：創建成功後，**複製用戶的 ID**（UUID 格式，例如：`123e4567-e89b-12d3-a456-426614174000`）

### 步驟 2：在 SQL Editor 中插入用戶記錄

1. 在 Supabase Dashboard 中，前往 **SQL Editor**
2. 點擊 **New query**
3. 執行以下 SQL，將 `YOUR_USER_ID` 替換為步驟 1 中複製的用戶 ID：

```sql
-- 插入老師帳號到 users 表
INSERT INTO users (id, email, name, role, student_id, created_at, updated_at)
VALUES (
  'YOUR_USER_ID',  -- 貼上從 Authentication 中複製的用戶 ID
  'teacher@example.com',  -- 老師的電子郵件（與 Authentication 中的一致）
  '老師姓名',  -- 老師的姓名
  'teacher',  -- 角色設為 teacher
  NULL,  -- 老師沒有學號
  NOW(),
  NOW()
);
```

### 步驟 3：驗證創建成功

執行以下 SQL 檢查是否創建成功：

```sql
SELECT id, email, name, role, created_at 
FROM users 
WHERE role = 'teacher'
ORDER BY created_at DESC;
```

## 方法二：使用 SQL 函數（一次性創建）

如果您需要一次性創建多個老師帳號，可以使用以下 SQL：

```sql
-- 創建多個老師帳號
-- 注意：需要先在 Authentication 中創建對應的用戶，然後獲取他們的 ID

INSERT INTO users (id, email, name, role, student_id, created_at, updated_at)
VALUES 
  ('USER_ID_1', 'teacher1@example.com', '張老師', 'teacher', NULL, NOW(), NOW()),
  ('USER_ID_2', 'teacher2@example.com', '李老師', 'teacher', NULL, NOW(), NOW()),
  ('USER_ID_3', 'teacher3@example.com', '王老師', 'teacher', NULL, NOW(), NOW());
```

## 完整範例

假設您已經在 Authentication 中創建了一個用戶：
- Email: `teacher@example.com`
- ID: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`

則執行以下 SQL：

```sql
INSERT INTO users (id, email, name, role, student_id, created_at, updated_at)
VALUES (
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  'teacher@example.com',
  '張老師',
  'teacher',
  NULL,
  NOW(),
  NOW()
);
```

## 注意事項

1. **用戶 ID 必須匹配**：
   - `users` 表中的 `id` 必須與 `auth.users` 表中的 `id` 完全一致
   - 這是兩個表之間的關聯鍵

2. **電子郵件建議一致**：
   - 雖然不是必須，但建議 `users` 表中的 `email` 與 `auth.users` 中的 `email` 一致

3. **角色設定**：
   - 確保 `role` 欄位設為 `'teacher'`（小寫）

4. **學號**：
   - 老師帳號的 `student_id` 應為 `NULL`

## 常見問題

### Q: 如何獲取用戶 ID？
A: 在 Supabase Dashboard > Authentication > Users 中：
1. 點擊用戶的電子郵件
2. 在用戶詳情頁面中，可以看到 **User UID**（這就是用戶 ID）
3. 複製這個 UUID

### Q: 創建後無法登入？
A: 確保：
1. 在 Authentication 中創建了對應的用戶
2. `users` 表中的 `id` 與 `auth.users` 中的 `id` 一致
3. 用戶已經被確認（Auto Confirm 或手動確認）

### Q: 如何修改老師資料？
A: 執行以下 SQL：

```sql
UPDATE users 
SET name = '新姓名', email = 'newemail@example.com'
WHERE id = 'USER_ID';
```

### Q: 如何刪除老師帳號？
A: 
1. 先在 `users` 表中刪除記錄：
   ```sql
   DELETE FROM users WHERE id = 'USER_ID';
   ```
2. 然後在 Authentication > Users 中刪除對應的認證用戶

### Q: 如何查看所有老師帳號？
A: 執行以下 SQL：

```sql
SELECT 
  u.id,
  u.email,
  u.name,
  u.role,
  u.created_at,
  au.email as auth_email,
  au.confirmed_at
FROM users u
LEFT JOIN auth.users au ON u.id = au.id
WHERE u.role = 'teacher'
ORDER BY u.created_at DESC;
```

## 快速操作步驟總結

1. **Authentication** > **Users** > **Add user** → 創建用戶 → 複製 ID
2. **SQL Editor** → 執行 INSERT SQL → 貼上 ID
3. 完成！

