# CMD / PowerShell 中文亂碼修正

Windows 預設使用 **Big5（950）**，若程式輸出 **UTF-8** 就會變成亂碼。

---

## 最快方式（本專案）

不要直接在 CMD 打長指令，改用：

| 用途 | 做法 |
|------|------|
| AWS 部署 | 雙擊 **`run-aws-deploy.bat`**（英文提示，不會亂碼） |
| 本機預覽 | 雙擊 **`本機預覽.bat`** |

兩個 `.bat` 已自動執行 `chcp 65001`（UTF-8）。

---

## 手動修正（每次開 CMD 先打一行）

```cmd
chcp 65001
```

再執行你的指令。若仍亂碼，請用 **PowerShell** 或 **VS Code 終端機**。

---

## 使用 PowerShell（建議）

在 **PowerShell**（不是 CMD）執行：

```powershell
cd C:\Users\maola\Downloads\0521\SGQ.AI\web\teacher-export
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
.\deploy-aws.ps1
```

或：

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy-aws.ps1
```

---

## VS Code / Cursor 終端機

1. 終端機右上角下拉 → 選 **PowerShell**（不要選 Command Prompt）
2. 或設定預設為 PowerShell：
   - `Ctrl + ,` 搜尋 `default profile windows`
   - 設為 **PowerShell**

---

## 永久讓 CMD 使用 UTF-8（Windows 11）

1. **設定** → **時間與語言** → **系統管理語言設定**
2. **系統地區設定** → **Beta 版：使用 Unicode UTF-8 提供全球語言支援** → 勾選
3. **重新開機**

重開後新開的 CMD 較不易亂碼（舊軟體極少數可能受影響）。

---

## 仍看到亂碼時

1. CMD 視窗標題列右鍵 → **屬性** → **字型** 選 **新細明體** 或 **Microsoft JhengHei**
2. 確認 `.ps1` 檔案是以 **UTF-8** 儲存（Cursor 預設通常正確）
3. SSH 連到 Linux 的訊息為英文是正常的，不影響部署
