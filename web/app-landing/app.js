(function () {
  const cfg = window.SGQ_APP_LANDING || {};
  const I18n = window.SGQ_I18N;

  function t(key, params) {
    return I18n ? I18n.t(key, params) : key;
  }

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

  function updateAppNames() {
    setText('header-app-name', appName);
    setText('hero-title', appName);
    setText('hero-tagline', tagline);
    setText('footer-app-name', appName);
  }

  updateAppNames();

  function updateVersionLabel() {
    const v = document.getElementById('version-label');
    if (!v) return;
    const android = (cfg.androidVersion || '').trim();
    const ios = (cfg.iosVersion || '').trim();
    const legacy = (cfg.versionLabel || '').trim();
    const parts = [];
    if (android) parts.push('Android ' + android);
    if (ios) parts.push('iOS ' + ios);
    if (parts.length) {
      v.textContent = t('version.prefix') + parts.join(' · ');
    } else if (legacy) {
      v.textContent = t('version.prefix') + legacy;
    } else {
      v.classList.add('hidden');
    }
  }

  updateVersionLabel();

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
      el.title = t('store.comingSoon');
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
    root.innerHTML = '';
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
  const exportCardDesc = document.getElementById('export-card-desc');
  if (teacherLink) {
    if (teacherUrl) {
      teacherLink.href = teacherUrl;
    } else {
      teacherLink.classList.add('hidden');
      if (exportCardDesc) {
        exportCardDesc.textContent = t('links.export.missing');
      }
    }
  }

  const privacyCard = document.getElementById('privacy-card');
  const privacyLink = document.getElementById('privacy-link');
  if (privacyLink && privacyCard) {
    if (privacyUrl) {
      privacyLink.href = privacyUrl;
      const onAppSite =
        privacyUrl.indexOf('app.sagp-qp.com') !== -1 ||
        privacyUrl.startsWith('/') ||
        !/^https?:\/\//i.test(privacyUrl);
      if (!onAppSite) {
        privacyLink.target = '_blank';
        privacyLink.rel = 'noopener noreferrer';
      }
    } else {
      privacyCard.classList.add('hidden');
    }
  }

  function updateFooterSupport() {
    const footerSupport = document.getElementById('footer-support');
    if (footerSupport && supportEmail) {
      footerSupport.innerHTML =
        t('footer.supportPrefix') +
        '<a href="mailto:' +
        supportEmail +
        '">' +
        supportEmail +
        '</a>';
    }
  }

  updateFooterSupport();

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
  const web3formsKey = (cfg.web3formsAccessKey || '').trim();

  document.addEventListener('sgq:langchange', function () {
    updateVersionLabel();
    updateFooterSupport();
    fillStores('hero-stores');
  });

  if (supportForm && supportEmail) {
    supportForm.addEventListener('submit', async function (e) {
      e.preventDefault();
      const name = document.getElementById('support-name').value.trim();
      const userEmail = document.getElementById('support-user-email').value.trim();
      const role = document.getElementById('support-role').value;
      const message = document.getElementById('support-message').value.trim();
      if (!name || !userEmail || !message) {
        alert(t('support.fillRequired'));
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

      const submitBtn = supportForm.querySelector('button[type="submit"]');
      const prevLabel = submitBtn ? submitBtn.textContent : '';

      if (web3formsKey) {
        if (submitBtn) {
          submitBtn.disabled = true;
          submitBtn.textContent = t('support.sending');
        }
        try {
          const payload = {
            access_key: web3formsKey,
            subject: subject,
            from_name: name,
            email: userEmail,
            message: body,
            replyto: userEmail,
          };
          const res = await fetch('https://api.web3forms.com/submit', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
            body: JSON.stringify(payload),
          });
          const data = await res.json();
          if (!res.ok || !data.success) {
            throw new Error(data.message || 'send failed');
          }
          supportForm.reset();
          alert(t('support.sent'));
        } catch (err) {
          console.error(err);
          alert(t('support.fail'));
        } finally {
          if (submitBtn) {
            submitBtn.disabled = false;
            submitBtn.textContent = prevLabel || t('support.submit');
          }
        }
        return;
      }

      window.location.href = buildMailtoUrl(subject, body);
    });
  }
})();
