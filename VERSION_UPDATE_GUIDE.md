# Android 版本號更新指南

## 版本號格式

在 `app/pubspec.yaml` 中，版本號格式為：
```yaml
version: versionName+versionCode
```

例如：`version: 1.0.0+2`
- `1.0.0` = **versionName**（用戶看到的版本號）
- `2` = **versionCode**（內部版本號，必須遞增）

---

## 重要規則

### ✅ 每次上傳新版本時

1. **versionCode 必須遞增**
   - 第一次：`1.0.0+1`
   - 第二次：`1.0.0+2` 或 `1.0.1+2`
   - 第三次：`1.0.0+3` 或 `1.0.2+3`
   - 依此類推...

2. **versionName 可以保持不變或更新**
   - 小更新：`1.0.0+2`（保持 versionName）
   - 功能更新：`1.0.1+2`（更新小版本號）
   - 重大更新：`1.1.0+2` 或 `2.0.0+2`

3. **versionCode 不能回退**
   - ❌ 不能從 `+3` 改回 `+2`
   - ✅ 只能遞增：`+1` → `+2` → `+3` → ...

---

## 當前版本

**已更新為**：`1.0.0+2`

這表示：
- 版本名稱：1.0.0
- 版本代碼：2

---

## 更新版本號步驟

### 方法 1：手動編輯 pubspec.yaml

1. 打開 `app/pubspec.yaml`
2. 找到 `version:` 行
3. 更新版本號：
   ```yaml
   version: 1.0.0+2  # 將 +2 改為 +3、+4 等
   ```
4. 保存檔案
5. 重新構建：
   ```powershell
   cd app
   flutter clean
   flutter build appbundle --release
   ```

### 方法 2：使用 Flutter 命令

```powershell
cd app
flutter build appbundle --release --build-number=3
```

這會自動更新 versionCode 為 3。

---

## 版本號建議

### 小更新（Bug 修復）
```
1.0.0+1 → 1.0.0+2
```

### 功能更新
```
1.0.0+2 → 1.0.1+3
```

### 重大更新
```
1.0.1+3 → 1.1.0+4
或
1.1.0+4 → 2.0.0+5
```

---

## 常見錯誤

### ❌ 錯誤：版本代碼 1 已經使用過了

**原因**：嘗試上傳相同的 versionCode

**解決**：將 versionCode 遞增（例如：從 `+1` 改為 `+2`）

### ❌ 錯誤：版本代碼不能小於之前的版本

**原因**：嘗試使用較小的 versionCode（例如：之前用過 `+3`，現在用 `+2`）

**解決**：使用更大的 versionCode（例如：`+4`、`+5`）

---

## 檢查當前版本

在 `app/pubspec.yaml` 中查看：
```yaml
version: 1.0.0+2
```

或在構建時查看日誌：
```
Building app for release...
Version: 1.0.0 (2)
```

---

## 下次更新時

當您需要上傳新版本時：

1. 更新 `app/pubspec.yaml`：
   ```yaml
   version: 1.0.0+3  # 或 1.0.1+3
   ```

2. 重新構建：
   ```powershell
   cd app
   flutter clean
   flutter build appbundle --release
   ```

3. 上傳新的 AAB 到 Google Play Console

---

## 提示

- **versionCode 是唯一標識**：Google Play 使用 versionCode 來識別版本
- **versionName 是顯示給用戶的**：用戶在應用程式商店看到的版本號
- **建議保持一致**：每次更新都同時更新 versionCode 和 versionName

---

**當前版本**：`1.0.0+2` ✅

下次更新時，請使用 `1.0.0+3` 或更高版本。
