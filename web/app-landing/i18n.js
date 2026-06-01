(function (global) {
  const STORAGE_KEY = 'sgq_lang';
  const DEFAULT_LANG = 'zh-Hant';

  const messages = {
    'zh-Hant': {
      'meta.index.description':
        'SGQ AI（SGQ 學習系統）— 支援大學 EFL 學生進行文法出題與 AI 鷹架式學習的教育 App。提供 Google Play、App Store 下載與教師匯出連結。',
      'meta.index.title': 'SGQ AI | SGQ 學習系統 — 大學 EFL 文法出題 App',
      'meta.student.description':
        'SGQ 學生學習數據 — 使用 App 帳號登入，查看題目、徽章與學習統計。',
      'meta.student.title': '學習數據 | SGQ AI',
      'meta.privacy.title': '隱私權政策 | SGQ AI',
      'nav.features': '功能',
      'nav.download': '下載',
      'nav.student': '學習數據',
      'nav.support': '聯絡客服',
      'nav.teachers': '教師專區',
      'nav.home': '返回官網',
      'nav.privacyHome': '返回首頁',
      'lang.zh': '中文',
      'lang.en': 'EN',
      'lang.switchAria': '切換語言',
      'hero.eyebrow': 'SGQ AI · 大學 EFL · 學生生成題目 · AI 鷹架',
      'hero.phoneHint': '文法重點 · 出題 · AI 小幫手 · 徽章',
      'features.title': '功能特色',
      'features.student.title': '學生端',
      'features.student.1': '查看文法重點與出題提醒',
      'features.student.2': '建立選擇題或問答題',
      'features.student.3': 'ChatGPT 四階段鷹架引導',
      'features.student.4': '完成題目獲得徽章',
      'features.teacher.title': '教師端',
      'features.teacher.1': '班級與課程單元管理',
      'features.teacher.2': '儀錶板掌握學習進度',
      'features.teacher.3': '題目檢視與評語',
      'features.teacher.4': '使用數據統計',
      'support.title': '聯絡客服',
      'support.desc':
        '使用 App 或網站時有問題？請留下訊息，我們會以 Email 回覆（非即時線上聊天）。',
      'support.emailPrefix': '客服信箱：',
      'support.mailtoBtn': '直接寄信給客服',
      'support.panelTitle': '傳送訊息',
      'support.nameLabel': '您的稱呼',
      'support.namePlaceholder': '姓名或暱稱',
      'support.emailLabel': '您的 Email（方便回覆）',
      'support.roleLabel': '身分',
      'support.role.student': '學生',
      'support.role.teacher': '教師',
      'support.role.other': '其他',
      'support.messageLabel': '訊息內容',
      'support.messagePlaceholder': '請描述問題或建議，我們會盡快以 Email 回覆。',
      'support.submit': '送出訊息',
      'support.hint': '送出後訊息將直接寄至客服信箱，無需開啟郵件 App。',
      'links.student.title': '學生學習數據',
      'links.student.desc':
        '使用與 App 相同的學生帳號登入，在瀏覽器查看題目、徽章與學習統計。',
      'links.student.cta': '前往學習數據',
      'links.export.title': '教師匯出題目',
      'links.export.desc': '在電腦瀏覽器匯出學生題目為 Excel，需使用教師帳號登入。',
      'links.export.cta': '前往教師匯出網站',
      'links.export.missing': '教師匯出功能網址尚未設定。',
      'links.privacy.title': '隱私權',
      'links.privacy.desc': '了解我們如何處理與保護您的資料。',
      'links.privacy.cta': '隱私權政策',
      'footer.supportPrefix': '客服：',
      'version.prefix': '目前版本 ',
      'store.comingSoon': '即將上架',
      'recaptcha.sectionLabel': '安全驗證',
      'recaptcha.fail': '請完成「我不是機器人」驗證，或重新整理後再試。',
      'recaptcha.notConfigured': '驗證服務尚未設定，請稍後再試或使用「直接寄信給客服」。',
      'recaptcha.loading': '安全驗證載入中，請稍候再試。',
      'recaptcha.v3notice':
        '本頁使用 Google reCAPTCHA v3：按下「登入」或「送出訊息」時會在背景自動驗證（不會出現勾選方塊，屬正常現象）。',
      'recaptcha.v3ready': '安全驗證已就緒，可以送出。',
      'recaptcha.v3loading': '正在載入安全驗證…',
      'recaptcha.v3legal':
        '本網站受 reCAPTCHA 保護，適用 Google <a href="https://policies.google.com/privacy" target="_blank" rel="noopener noreferrer">隱私權政策</a> 與 <a href="https://policies.google.com/terms" target="_blank" rel="noopener noreferrer">服務條款</a>。',
      'support.fillRequired': '請填寫稱呼、Email 與訊息內容。',
      'support.sending': '傳送中…',
      'support.sent': '訊息已送出，我們會盡快以 Email 回覆您。',
      'support.fail': '傳送失敗，請稍後再試，或使用「直接寄信給客服」。',
      'student.brand': 'SGQ 學習數據',
      'student.loginTitle': '學生登入',
      'student.loginLead': '使用與 SGQ App 相同的 Email 與密碼，查看您的學習數據。',
      'student.emailLabel': 'Email',
      'student.emailPlaceholder': '註冊時使用的信箱',
      'student.passwordLabel': '密碼',
      'student.passwordPlaceholder': '請輸入密碼',
      'student.loginBtn': '登入',
      'student.teacherNote': '教師請使用',
      'student.teacherLink': '教師匯出網站',
      'student.teacherNoteSuffix': '。',
      'student.recaptchaHint':
        '若已登入過，開啟本頁可能會直接顯示學習數據；要測試登入驗證請先按「登出」，並完成下方「我不是機器人」驗證。',
      'student.greeting': '您好，',
      'student.logout': '登出',
      'student.studentId': '學號：',
      'student.stageTitle': '各階段題目數',
      'student.stageLabel': '第{n}階段',
      'student.recentTitle': '最近建立的題目',
      'student.th.topic': '課程單元',
      'student.th.type': '題型',
      'student.th.stage': '階段',
      'student.th.created': '建立時間',
      'student.noQuestions': '尚無題目記錄，請在 App 開始出題。',
      'student.badgesTitle': '已獲得徽章',
      'student.noBadges': '尚無徽章，完成題目後可獲得。',
      'student.topicStatsTitle': '各課程學習統計',
      'student.th.completed': '完成題數',
      'student.th.logins': '登入次數',
      'student.th.minutes': '使用分鐘',
      'student.noTopicStats': '尚無課程統計資料。',
      'student.loading': '載入學習數據…',
      'student.loggingIn': '登入中…',
      'student.studentsOnly': '此功能僅供學生使用，教師請前往教師匯出網站。',
      'student.loginFail': '登入失敗：',
      'student.configError': '無法載入設定',
      'student.configHint':
        '請按 Ctrl+Shift+R 強制重新整理此頁。若仍失敗，請確認官網已更新部署。',
      'student.stat.questions': '題目總數',
      'student.stat.badges': '徽章數',
      'student.stat.sessions': '登入學習次數',
      'student.stat.minutes': '累計使用（約）',
      'student.minutes': ' 分鐘',
      'student.minutesUnder': '< 1 分鐘',
      'student.type.mc': '選擇題',
      'student.type.sa': '簡答題',
      'student.defaultName': '學生',
      'privacy.brand': 'SGQ 學習系統',
    },
    en: {
      'meta.index.description':
        'SGQ AI — An educational app for university EFL students: grammar question generation and AI scaffolded learning. Download on Google Play and App Store.',
      'meta.index.title': 'SGQ AI | University EFL Grammar App',
      'meta.student.description':
        'SGQ student learning data — Sign in with your app account to view questions, badges, and stats.',
      'meta.student.title': 'Learning Data | SGQ AI',
      'meta.privacy.title': 'Privacy Policy | SGQ AI',
      'nav.features': 'Features',
      'nav.download': 'Download',
      'nav.student': 'Learning Data',
      'nav.support': 'Contact',
      'nav.teachers': 'Teachers',
      'nav.home': 'Back to site',
      'nav.privacyHome': 'Back to home',
      'lang.zh': '中文',
      'lang.en': 'EN',
      'lang.switchAria': 'Switch language',
      'hero.eyebrow': 'SGQ AI · University EFL · Student-generated questions · AI scaffold',
      'hero.phoneHint': 'Grammar · Questions · AI helper · Badges',
      'features.title': 'Features',
      'features.student.title': 'For students',
      'features.student.1': 'View grammar focus and question prompts',
      'features.student.2': 'Create multiple-choice or short-answer items',
      'features.student.3': 'ChatGPT four-stage scaffolding',
      'features.student.4': 'Earn badges by completing questions',
      'features.teacher.title': 'For teachers',
      'features.teacher.1': 'Class and unit management',
      'features.teacher.2': 'Dashboard for learning progress',
      'features.teacher.3': 'Review questions and give feedback',
      'features.teacher.4': 'Usage analytics',
      'support.title': 'Contact support',
      'support.desc':
        'Having trouble with the app or website? Leave a message and we will reply by email (not live chat).',
      'support.emailPrefix': 'Support email: ',
      'support.mailtoBtn': 'Email support directly',
      'support.panelTitle': 'Send a message',
      'support.nameLabel': 'Your name',
      'support.namePlaceholder': 'Name or nickname',
      'support.emailLabel': 'Your email (for reply)',
      'support.roleLabel': 'Role',
      'support.role.student': 'Student',
      'support.role.teacher': 'Teacher',
      'support.role.other': 'Other',
      'support.messageLabel': 'Message',
      'support.messagePlaceholder': 'Describe your issue or suggestion. We will reply by email.',
      'support.submit': 'Send message',
      'support.hint': 'Your message is sent to our support inbox. No mail app required.',
      'links.student.title': 'Student learning data',
      'links.student.desc':
        'Sign in with the same student account as the app to view questions, badges, and stats in your browser.',
      'links.student.cta': 'Go to learning data',
      'links.export.title': 'Teacher export',
      'links.export.desc':
        'Export student questions to Excel in your browser. Teacher account required.',
      'links.export.cta': 'Go to teacher export site',
      'links.export.missing': 'Teacher export URL is not configured yet.',
      'links.privacy.title': 'Privacy',
      'links.privacy.desc': 'Learn how we handle and protect your data.',
      'links.privacy.cta': 'Privacy policy',
      'footer.supportPrefix': 'Support: ',
      'version.prefix': 'Current version ',
      'store.comingSoon': 'Coming soon',
      'recaptcha.sectionLabel': 'Security check',
      'recaptcha.fail': 'Please complete the reCAPTCHA checkbox, or refresh and try again.',
      'recaptcha.notConfigured':
        'Verification is not configured yet. Try again later or email support directly.',
      'recaptcha.loading': 'Security verification is still loading. Please wait and try again.',
      'recaptcha.v3notice':
        'This page uses Google reCAPTCHA v3. Verification runs in the background when you sign in or submit (no checkbox is shown).',
      'recaptcha.v3ready': 'Security check is ready. You may submit.',
      'recaptcha.v3loading': 'Loading security check…',
      'recaptcha.v3legal':
        'This site is protected by reCAPTCHA and the Google <a href="https://policies.google.com/privacy" target="_blank" rel="noopener noreferrer">Privacy Policy</a> and <a href="https://policies.google.com/terms" target="_blank" rel="noopener noreferrer">Terms of Service</a> apply.',
      'support.fillRequired': 'Please fill in your name, email, and message.',
      'support.sending': 'Sending…',
      'support.sent': 'Message sent. We will reply by email as soon as we can.',
      'support.fail': 'Send failed. Please try again or use "Email support directly".',
      'student.brand': 'SGQ Learning Data',
      'student.loginTitle': 'Student sign in',
      'student.loginLead':
        'Use the same email and password as the SGQ app to view your learning data.',
      'student.emailLabel': 'Email',
      'student.emailPlaceholder': 'Email used at registration',
      'student.passwordLabel': 'Password',
      'student.passwordPlaceholder': 'Enter your password',
      'student.loginBtn': 'Sign in',
      'student.teacherNote': 'Teachers: use the',
      'student.teacherLink': 'teacher export site',
      'student.teacherNoteSuffix': '.',
      'student.recaptchaHint':
        'If you were signed in before, this page may open your dashboard directly. Sign out first, then complete the reCAPTCHA checkbox below.',
      'student.greeting': 'Hello, ',
      'student.logout': 'Sign out',
      'student.studentId': 'Student ID: ',
      'student.stageTitle': 'Questions by stage',
      'student.stageLabel': 'Stage {n}',
      'student.recentTitle': 'Recently created questions',
      'student.th.topic': 'Unit',
      'student.th.type': 'Type',
      'student.th.stage': 'Stage',
      'student.th.created': 'Created',
      'student.noQuestions': 'No questions yet. Start in the app.',
      'student.badgesTitle': 'Badges earned',
      'student.noBadges': 'No badges yet. Complete questions to earn them.',
      'student.topicStatsTitle': 'Stats by course unit',
      'student.th.completed': 'Completed',
      'student.th.logins': 'Logins',
      'student.th.minutes': 'Minutes',
      'student.noTopicStats': 'No course stats yet.',
      'student.loading': 'Loading learning data…',
      'student.loggingIn': 'Signing in…',
      'student.studentsOnly':
        'This page is for students only. Teachers should use the teacher export site.',
      'student.loginFail': 'Sign-in failed: ',
      'student.configError': 'Could not load configuration',
      'student.configHint':
        'Press Ctrl+Shift+R to hard refresh. If it still fails, the site may not be deployed yet.',
      'student.stat.questions': 'Total questions',
      'student.stat.badges': 'Badges',
      'student.stat.sessions': 'Learning sessions',
      'student.stat.minutes': 'Total time (approx.)',
      'student.minutes': ' min',
      'student.minutesUnder': '< 1 min',
      'student.type.mc': 'Multiple choice',
      'student.type.sa': 'Short answer',
      'student.defaultName': 'Student',
      'privacy.brand': 'SGQ Learning System',
    },
  };

  let currentLang = DEFAULT_LANG;

  function normalizeLang(code) {
    if (!code) return DEFAULT_LANG;
    if (code === 'en' || code.startsWith('en')) return 'en';
    return DEFAULT_LANG;
  }

  function getLang() {
    return currentLang;
  }

  function t(key, params) {
    const bag = messages[currentLang] || messages[DEFAULT_LANG];
    let s = bag[key] || messages[DEFAULT_LANG][key] || key;
    if (params) {
      Object.keys(params).forEach(function (k) {
        s = s.replace(new RegExp('\\{' + k + '\\}', 'g'), params[k]);
      });
    }
    return s;
  }

  function setLang(lang, options) {
    const next = normalizeLang(lang);
    currentLang = next;
    try {
      localStorage.setItem(STORAGE_KEY, next);
    } catch (e) {
      /* ignore */
    }
    document.documentElement.lang = next === 'en' ? 'en' : 'zh-Hant';
    applyPage();
    if (!options || !options.silent) {
      document.dispatchEvent(
        new CustomEvent('sgq:langchange', { detail: { lang: next } })
      );
    }
  }

  function applyMeta(pageId) {
    const desc = document.querySelector('meta[name="description"]');
    const titleKey = 'meta.' + pageId + '.title';
    const descKey = 'meta.' + pageId + '.description';
    if (desc && messages[currentLang][descKey]) {
      desc.setAttribute('content', t(descKey));
    }
    if (messages[currentLang][titleKey]) {
      document.title = t(titleKey);
    }
  }

  function applyElements() {
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
      const key = el.getAttribute('data-i18n');
      if (!key) return;
      el.textContent = t(key);
    });
    document.querySelectorAll('[data-i18n-placeholder]').forEach(function (el) {
      const key = el.getAttribute('data-i18n-placeholder');
      if (key) el.placeholder = t(key);
    });
    document.querySelectorAll('[data-i18n-html]').forEach(function (el) {
      const key = el.getAttribute('data-i18n-html');
      if (key) el.innerHTML = t(key);
    });
    document.querySelectorAll('[data-i18n-option]').forEach(function (el) {
      const key = el.getAttribute('data-i18n-option');
      if (key) el.textContent = t(key);
    });

    document.querySelectorAll('.legal-lang-zh').forEach(function (el) {
      el.classList.toggle('hidden', currentLang === 'en');
    });
    document.querySelectorAll('.legal-lang-en').forEach(function (el) {
      el.classList.toggle('hidden', currentLang !== 'en');
    });

    document.querySelectorAll('.lang-switch-btn').forEach(function (btn) {
      const target = btn.getAttribute('data-lang');
      btn.classList.toggle('is-active', target === currentLang);
      btn.setAttribute('aria-pressed', target === currentLang ? 'true' : 'false');
    });
  }

  function applyPage() {
    const page = document.body && document.body.getAttribute('data-page');
    if (page) applyMeta(page);
    applyElements();
  }

  function mountLangSwitcher(container) {
    if (!container || container.querySelector('.lang-switch')) return;
    const wrap = document.createElement('div');
    wrap.className = 'lang-switch';
    wrap.setAttribute('role', 'group');
    wrap.setAttribute('aria-label', t('lang.switchAria'));
    wrap.innerHTML =
      '<button type="button" class="lang-switch-btn" data-lang="zh-Hant" data-i18n="lang.zh">中文</button>' +
      '<button type="button" class="lang-switch-btn" data-lang="en" data-i18n="lang.en">EN</button>';
    container.appendChild(wrap);
    wrap.querySelectorAll('.lang-switch-btn').forEach(function (btn) {
      btn.addEventListener('click', function () {
        setLang(btn.getAttribute('data-lang'));
      });
    });
    applyElements();
  }

  function init() {
    let stored = DEFAULT_LANG;
    try {
      stored = localStorage.getItem(STORAGE_KEY) || DEFAULT_LANG;
    } catch (e) {
      stored = DEFAULT_LANG;
    }
    const urlLang = new URLSearchParams(window.location.search).get('lang');
    currentLang = normalizeLang(urlLang || stored);
    document.documentElement.lang = currentLang === 'en' ? 'en' : 'zh-Hant';
    document.querySelectorAll('[data-lang-switch]').forEach(mountLangSwitcher);
    applyPage();
  }

  global.SGQ_I18N = {
    t,
    getLang,
    setLang,
    applyPage,
    mountLangSwitcher,
    init,
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})(window);
