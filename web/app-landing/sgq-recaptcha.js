(function (global) {
  let scriptLoading = null;

  function getCfg() {
    return global.SGQ_APP_LANDING || {};
  }

  function getSiteKey() {
    return String(getCfg().recaptchaSiteKey || '').trim();
  }

  function getVersion() {
    const v = String(getCfg().recaptchaVersion || 'v3')
      .trim()
      .toLowerCase();
    return v === 'v2' ? 'v2' : 'v3';
  }

  function tr(key) {
    return global.SGQ_I18N ? global.SGQ_I18N.t(key) : key;
  }

  function getHl() {
    const I18n = global.SGQ_I18N;
    return I18n && I18n.getLang() === 'en' ? 'en' : 'zh-TW';
  }

  function loadApiV2() {
    if (global.grecaptcha && global.grecaptcha.render) {
      return Promise.resolve();
    }
    if (scriptLoading) return scriptLoading;

    scriptLoading = new Promise(function (resolve, reject) {
      const cb = '_sgqRecaptchaOnload';
      global[cb] = function () {
        delete global[cb];
        resolve();
      };
      const s = document.createElement('script');
      s.src =
        'https://www.google.com/recaptcha/api.js?onload=' +
        cb +
        '&render=explicit&hl=' +
        encodeURIComponent(getHl());
      s.async = true;
      s.defer = true;
      s.onerror = function () {
        scriptLoading = null;
        reject(new Error('recaptcha v2 load failed'));
      };
      document.head.appendChild(s);
    });

    return scriptLoading;
  }

  function loadApiV3(siteKey) {
    if (global.grecaptcha && global.grecaptcha.execute) {
      return new Promise(function (resolve) {
        global.grecaptcha.ready(resolve);
      });
    }
    if (scriptLoading) return scriptLoading;

    scriptLoading = new Promise(function (resolve, reject) {
      const s = document.createElement('script');
      s.src =
        'https://www.google.com/recaptcha/api.js?render=' +
        encodeURIComponent(siteKey);
      s.async = true;
      s.defer = true;
      s.onload = function () {
        global.grecaptcha.ready(resolve);
      };
      s.onerror = function () {
        scriptLoading = null;
        reject(new Error('recaptcha v3 load failed'));
      };
      document.head.appendChild(s);
    });

    return scriptLoading;
  }

  function mountV2(mountEl) {
    const siteKey = getSiteKey();
    mountEl.innerHTML =
      '<div class="recaptcha-panel recaptcha-panel--v2">' +
      '<div class="g-recaptcha-field"></div>' +
      '</div>';
    const container = mountEl.querySelector('.g-recaptcha-field');
    let widgetId = null;

    return loadApiV2()
      .then(function () {
        widgetId = global.grecaptcha.render(container, { sitekey: siteKey });
        return {
          enabled: true,
          verify: function () {
            const token = global.grecaptcha.getResponse(widgetId);
            return Promise.resolve({ ok: !!token, token: token || '' });
          },
          reset: function () {
            if (widgetId != null) global.grecaptcha.reset(widgetId);
          },
        };
      })
      .catch(failWidget.bind(null, mountEl));
  }

  function mountV3(mountEl, action) {
    const siteKey = getSiteKey();
    mountEl.innerHTML =
      '<div class="recaptcha-panel recaptcha-panel--v3">' +
      '<p class="recaptcha-panel-notice">' +
      tr('recaptcha.v3notice') +
      '</p>' +
      '<p id="recaptcha-status" class="recaptcha-status">' +
      tr('recaptcha.v3loading') +
      '</p>' +
      '<p class="recaptcha-legal">' +
      tr('recaptcha.v3legal') +
      '</p>' +
      '</div>';

    const statusEl = mountEl.querySelector('#recaptcha-status');

    function setStatus(text, state) {
      if (!statusEl) return;
      statusEl.textContent = text;
      statusEl.className = 'recaptcha-status' + (state ? ' recaptcha-status--' + state : '');
    }

    return loadApiV3(siteKey)
      .then(function () {
        setStatus(tr('recaptcha.v3ready'), 'ready');
        return {
          enabled: true,
          verify: function () {
            setStatus(tr('recaptcha.v3loading'), 'loading');
            return new Promise(function (resolve) {
              global.grecaptcha.ready(function () {
                global.grecaptcha
                  .execute(siteKey, { action: action })
                  .then(function (token) {
                    if (token) {
                      setStatus(tr('recaptcha.v3ready'), 'ready');
                    }
                    resolve({ ok: !!token, token: token || '' });
                  })
                  .catch(function () {
                    setStatus(tr('recaptcha.fail'), 'error');
                    resolve({ ok: false, token: '' });
                  });
              });
            });
          },
          reset: function () {
            setStatus(tr('recaptcha.v3ready'), 'ready');
          },
        };
      })
      .catch(function () {
        setStatus(tr('recaptcha.fail'), 'error');
        return failWidget(mountEl);
      });
  }

  function failWidget(mountEl) {
    mountEl.innerHTML =
      '<p class="recaptcha-hint recaptcha-hint--warn">' +
      tr('recaptcha.fail') +
      '</p>';
    return {
      enabled: false,
      verify: function () {
        return Promise.resolve({ ok: false, token: '' });
      },
      reset: function () {},
    };
  }

  function mount(mountEl, opts) {
    const siteKey = getSiteKey();
    const action = (opts && opts.action) || 'submit';

    if (!siteKey) {
      mountEl.innerHTML =
        '<p class="recaptcha-hint recaptcha-hint--warn">' +
        tr('recaptcha.notConfigured') +
        '</p>';
      return Promise.resolve({
        enabled: false,
        verify: function () {
          return Promise.resolve({ ok: false, token: '' });
        },
        reset: function () {},
      });
    }

    scriptLoading = null;
    if (getVersion() === 'v2') {
      return mountV2(mountEl);
    }
    return mountV3(mountEl, action);
  }

  function remount(mountEl, opts) {
    scriptLoading = null;
    if (mountEl) mountEl.innerHTML = '';
    return mount(mountEl, opts);
  }

  document.addEventListener('sgq:langchange', function () {
    document.querySelectorAll('[data-recaptcha-mount]').forEach(function (el) {
      const action = el.getAttribute('data-recaptcha-action') || 'submit';
      remount(el, { action: action });
    });
  });

  global.SGQRecaptcha = { mount, remount, getSiteKey, getVersion };
})(window);
