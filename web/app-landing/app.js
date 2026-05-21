(function () {
  const cfg = window.SGQ_APP_LANDING || {};
  const playUrl = (cfg.playStoreUrl || '').trim();
  const iosUrl = (cfg.appStoreUrl || '').trim();
  const teacherUrl = (cfg.teacherExportUrl || '').trim();
  const privacyUrl = (cfg.privacyPolicyUrl || '').trim();
  const supportEmail = (cfg.supportEmail || 'sgqaiapp@gmail.com').trim();
  const supportSubjectPrefix = (cfg.supportSubjectPrefix || 'SGQ App 客服').trim();
  const appName = cfg.appName || 'SGQ 學習系統';
  const tagline =
    cfg.tagline ||
    '支援大學 EFL 學生進行學生生成文法問題（SGQ）活動的教育應用程式。';

  function setText(id, text) {
    const el = document.getElementById(id);
    if (el && text) el.textContent = text;
  }

  setText('header-app-name', appName);
  setText('hero-title', appName);
  setText('hero-tagline', tagline);
  setText('footer-app-name', appName);

  if (cfg.versionLabel) {
    setText('version-label', '目前版本 ' + cfg.versionLabel);
  } else {
    const v = document.getElementById('version-label');
    if (v) v.classList.add('hidden');
  }

  const googleBadge =
    (cfg.googlePlayBadge || 'assets/google-play-badge.png').trim();
  const appleBadge = (cfg.appStoreBadge || 'assets/app-store-badge.svg').trim();

  function createStoreBadge(url, imgSrc, alt, store) {
    const el = document.createElement(url ? 'a' : 'span');
    el.className =
      'store-badge-link store-badge-link--' +
      store +
      (url ? '' : ' store-badge-disabled');
    if (url) {
      el.href = url;
      el.target = '_blank';
      el.rel = 'noopener noreferrer';
    } else {
      el.setAttribute('aria-disabled', 'true');
      el.title = '即將上架';
    }
    const img = document.createElement('img');
    img.className = 'store-badge-img store-badge-img--' + store;
    img.src = imgSrc;
    img.alt = alt;
    img.loading = 'lazy';
    img.decoding = 'async';
    el.appendChild(img);
    return el;
  }

  function fillStores(containerId) {
    const root = document.getElementById(containerId);
    if (!root) return;
    root.appendChild(
      createStoreBadge(
        playUrl,
        googleBadge,
        'Get it on Google Play',
        'google'
      )
    );
    root.appendChild(
      createStoreBadge(
        iosUrl,
        appleBadge,
        'Download on the App Store',
        'apple'
      )
    );
  }

  fillStores('hero-stores');

  const teacherLink = document.getElementById('teacher-export-link');
  if (teacherLink) {
    if (teacherUrl) {
      teacherLink.href = teacherUrl;
    } else {
      teacherLink.classList.add('hidden');
      teacherLink.parentElement.querySelector('p').textContent =
        '教師匯出功能網址尚未設定。';
    }
  }

  const privacyCard = document.getElementById('privacy-card');
  const privacyLink = document.getElementById('privacy-link');
  if (privacyLink && privacyCard) {
    if (privacyUrl) {
      privacyLink.href = privacyUrl;
      privacyLink.target = '_blank';
      privacyLink.rel = 'noopener noreferrer';
    } else {
      privacyCard.classList.add('hidden');
    }
  }

  const footerSupport = document.getElementById('footer-support');
  if (footerSupport && supportEmail) {
    footerSupport.innerHTML =
      '客服：<a href="mailto:' +
      supportEmail +
      '">' +
      supportEmail +
      '</a>';
  }

  function buildMailtoUrl(subject, body) {
    const params = new URLSearchParams();
    if (subject) params.set('subject', subject);
    if (body) params.set('body', body);
    const qs = params.toString();
    return 'mailto:' + supportEmail + (qs ? '?' + qs : '');
  }

  const supportEmailLink = document.getElementById('support-email-link');
  const supportMailtoBtn = document.getElementById('support-mailto-btn');
  if (supportEmailLink) {
    supportEmailLink.href = buildMailtoUrl(supportSubjectPrefix, '');
    supportEmailLink.textContent = supportEmail;
  }
  if (supportMailtoBtn) {
    supportMailtoBtn.href = buildMailtoUrl(supportSubjectPrefix, '');
  }

  const supportForm = document.getElementById('support-form');
  if (supportForm && supportEmail) {
    supportForm.addEventListener('submit', function (e) {
      e.preventDefault();
      const name = document.getElementById('support-name').value.trim();
      const userEmail = document.getElementById('support-user-email').value.trim();
      const role = document.getElementById('support-role').value;
      const message = document.getElementById('support-message').value.trim();
      if (!name || !userEmail || !message) {
        alert('請填寫稱呼、Email 與訊息內容。');
        return;
      }
      const subject = supportSubjectPrefix + ' - ' + role;
      const body =
        '稱呼：' +
        name +
        '\n身分：' +
        role +
        '\n聯絡 Email：' +
        userEmail +
        '\n\n訊息：\n' +
        message +
        '\n\n---\n由 app.sagp-qp.com 聯絡表單送出';
      window.location.href = buildMailtoUrl(subject, body);
    });
  }
})();
