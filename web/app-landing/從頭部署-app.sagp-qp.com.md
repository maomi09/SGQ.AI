# 從頭部署 App 介紹網站（https://app.sagp-qp.com）

與 `export.sagp-qp.com`（教師匯出）、`api.sagp-qp.com`（後端 API）同一台 EC2，**不用重部署 Python 後端**。

---

## 這個網站做什麼

- 介紹 SGQ App 功能（學生 / 教師）
- **Google Play、App Store 下載按鈕**（在 `config.js` 填連結）
- 連到教師匯出站 `https://export.sagp-qp.com`
- 可選：隱私權政策外部連結、聯絡 Email

---

## 步驟 1：DNS

在 sagp-qp.com 的 DNS 後台新增：

| 類型 | 名稱 | 值 |
|------|------|-----|
| A | `app` | `3.80.19.9` |

檢查：

```powershell
nslookup app.sagp-qp.com
```

---

## 步驟 2：填商店連結（上架後）

編輯 `web/app-landing/config.js`：

```javascript
playStoreUrl: 'https://play.google.com/store/apps/details?id=com.sgqai.app',
appStoreUrl: 'https://apps.apple.com/app/id你的AppID',
```

尚未上架可留空 `''`，按鈕會顯示「即將上架」。

參考範例：`config.example.js`

---

## 步驟 3：本機預覽（選用）

雙擊 `本機預覽.bat`，開 **http://localhost:8081**

---

## 步驟 4：部署到 AWS

雙擊 **`run-app-domain.bat`**

或：

```powershell
cd web\app-landing
powershell -ExecutionPolicy Bypass -File .\deploy-app-domain.ps1
```

`.pem`：`C:\Users\maola\Downloads\sgqai_app.pem`

---

## 步驟 5：瀏覽器開啟

**https://app.sagp-qp.com**

若 Chrome 顯示「憑證錯誤」或 HSTS，代表 **尚未為 app 申請 SSL**（常誤用 api 憑證）。請看 **[SSL憑證錯誤排除.md](./SSL憑證錯誤排除.md)**，或 SSH 執行：

```bash
sudo bash fix-app-ssl.sh sgqaiapp@gmail.com
```

（腳本在 `deploy/fix-app-ssl.sh`，需先 scp 到 EC2）

---

## 三個子網域對照

| 網址 | 用途 |
|------|------|
| app.sagp-qp.com | App 介紹 + 商店連結 |
| export.sagp-qp.com | 教師匯出 Excel |
| api.sagp-qp.com | App 後端 API（勿動） |

---

## 更新網站

改 `index.html` / `config.js` 後，再執行一次 `run-app-domain.bat`。
