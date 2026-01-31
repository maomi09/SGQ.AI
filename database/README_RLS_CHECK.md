# 如何檢查 Supabase RLS 政策

## 方法 1: 使用 Supabase Dashboard

### 步驟 1: 登入 Supabase Dashboard
1. 前往 [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. 選擇您的專案

### 步驟 2: 查看 RLS 政策
1. 在左側選單中，點擊 **Authentication** > **Policies**
2. 或者點擊 **Table Editor** > 選擇 `users` 表 > 點擊 **Policies** 標籤
3. 查看所有 RLS 政策

### 步驟 3: 檢查 UPDATE 政策
在 Policies 列表中，查找：
- **Policy Name**: 包含 "teacher" 或 "update" 的政策
- **Command**: 應該是 `UPDATE`
- **USING**: 檢查條件（誰可以更新）
- **WITH CHECK**: 更新後的檢查條件

## 方法 2: 使用 SQL Editor

### 步驟 1: 打開 SQL Editor
1. 在 Supabase Dashboard 中，點擊左側選單的 **SQL Editor**
2. 點擊 **New query**

### 步驟 2: 執行檢查查詢
複製並執行 `database/check_teacher_permissions.sql` 中的查詢：

```sql
-- 檢查 users 表的所有 RLS 政策
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,  -- SELECT, INSERT, UPDATE, DELETE
  qual,  -- USING 條件
  with_check  -- WITH CHECK 條件
FROM pg_policies
WHERE tablename = 'users'
ORDER BY cmd, policyname;
```

### 步驟 3: 檢查是否有老師更新學生的政策
```sql
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'users' 
  AND cmd = 'UPDATE'
  AND (policyname LIKE '%teacher%' OR policyname LIKE '%Teacher%');
```

## 方法 3: 檢查應用程式日誌

在 Flutter 應用程式中，查看 console 輸出：
- 如果看到 `Error updating student: ...` 或 `PostgrestException`
- 錯誤訊息通常會包含 RLS 政策的相關資訊

## 如果沒有老師更新學生的政策

如果查詢結果中沒有看到 "Teachers can update students" 政策，請執行：

```sql
-- 執行 database/add_teacher_update_students_policy.sql
```

或者在 Supabase Dashboard 中手動創建：

1. 前往 **Table Editor** > `users` 表 > **Policies**
2. 點擊 **New Policy**
3. 選擇 **For full customization**
4. 設定：
   - **Policy name**: `Teachers can update students`
   - **Allowed operation**: `UPDATE`
   - **USING expression**:
     ```sql
     EXISTS (
       SELECT 1 FROM users
       WHERE users.id = auth.uid() 
       AND users.role = 'teacher'
     )
     OR auth.uid() = id
     ```
   - **WITH CHECK expression**:
     ```sql
     (
       EXISTS (
         SELECT 1 FROM users
         WHERE users.id = auth.uid() 
         AND users.role = 'teacher'
       )
       AND role = 'student'
     )
     OR auth.uid() = id
     ```

## 常見問題

### Q: 為什麼會出現無限遞迴錯誤？
A: 如果 RLS 政策中查詢 `users` 表來檢查 role，可能會導致無限遞迴。解決方案是使用 `auth.jwt()` 直接從 JWT token 中獲取 role。

### Q: 如何修復無限遞迴？
A: 使用 `auth.jwt() -> 'user_metadata' ->> 'role'` 而不是查詢 `users` 表。

### Q: 如何確認政策是否生效？
A: 在應用程式中嘗試更新學生資料，如果成功則政策生效。如果失敗，查看錯誤訊息。
