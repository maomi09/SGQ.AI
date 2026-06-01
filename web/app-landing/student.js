(function () {
  const cfg = window.SGQ_APP_LANDING || {};
  const I18n = window.SGQ_I18N;

  function t(key, params) {
    return I18n ? I18n.t(key, params) : key;
  }

  function dateLocale() {
    return I18n && I18n.getLang() === 'en' ? 'en-US' : 'zh-TW';
  }

  const supabaseUrl = (cfg.supabaseUrl || '').trim();
  const supabaseAnonKey = (cfg.supabaseAnonKey || '').trim();
  if (!supabaseUrl || !supabaseAnonKey) {
    document.body.innerHTML =
      '<div style="padding:24px;max-width:480px;margin:0 auto;font-family:system-ui,sans-serif">' +
      '<p><strong>' +
      t('student.configError') +
      '</strong></p>' +
      '<p>' +
      t('student.configHint') +
      '</p>' +
      '<p><a href="/">' +
      (I18n && I18n.getLang() === 'en' ? 'Home' : '官網') +
      '</a></p></div>';
    return;
  }

  const supabase = window.supabase.createClient(supabaseUrl, supabaseAnonKey);

  const $ = (id) => document.getElementById(id);
  const loginSection = $('login-section');
  const dashboardSection = $('dashboard-section');
  const statusEl = $('status');

  let lastDashboardUserId = null;

  const exportLink = $('export-link');
  if (exportLink && cfg.teacherExportUrl) {
    exportLink.href = cfg.teacherExportUrl;
  }

  document.addEventListener('sgq:langchange', function () {
    if (lastDashboardUserId && !dashboardSection.classList.contains('hidden')) {
      loadDashboard(lastDashboardUserId);
    }
  });

  function setStatus(message, type) {
    if (!statusEl) return;
    statusEl.textContent = message;
    statusEl.className = 'status ' + (type || 'info');
    statusEl.classList.remove('hidden');
  }

  function clearStatus() {
    if (statusEl) statusEl.classList.add('hidden');
  }

  function normalizeRole(role) {
    return String(role || '')
      .trim()
      .toLowerCase();
  }

  async function resolveIsStudent(user) {
    if (!user?.id) return false;

    const { data, error } = await supabase
      .from('users')
      .select('role')
      .eq('id', user.id)
      .maybeSingle();

    if (!error && data?.role != null && data.role !== '') {
      return normalizeRole(data.role) === 'student';
    }

    return normalizeRole(
      user?.user_metadata?.role || user?.app_metadata?.role
    ) === 'student';
  }

  function formatDate(iso) {
    if (!iso) return '—';
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return iso;
    return d.toLocaleString(dateLocale(), {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  function typeLabel(type) {
    if (type === 'multipleChoice') return t('student.type.mc');
    if (type === 'shortAnswer') return t('student.type.sa');
    return type || '—';
  }

  function renderStats(cards) {
    const grid = $('stats-grid');
    if (!grid) return;
    grid.innerHTML = cards
      .map(
        (c) =>
          '<div class="stat-card"><p class="stat-label">' +
          c.label +
          '</p><p class="stat-value">' +
          c.value +
          '</p></div>'
      )
      .join('');
  }

  function renderStageBars(counts) {
    const el = $('stage-bars');
    if (!el) return;
    const max = Math.max(1, ...counts);
    el.innerHTML = counts
      .map((n, i) => {
        const pct = Math.round((n / max) * 100);
        const label = t('student.stageLabel', { n: String(i + 1) });
        return (
          '<div class="stage-row"><span class="stage-label">' +
          label +
          '</span><div class="stage-track"><div class="stage-fill" style="width:' +
          pct +
          '%"></div></div><span class="stage-count">' +
          n +
          '</span></div>'
        );
      })
      .join('');
  }

  async function loadDashboard(userId) {
    lastDashboardUserId = userId;
    clearStatus();
    setStatus(t('student.loading'), 'info');

    const profileRes = await supabase
      .from('users')
      .select('name, student_id, email, class_id')
      .eq('id', userId)
      .maybeSingle();

    const profile = profileRes.data;
    $('student-name').textContent = profile?.name || t('student.defaultName');
    const metaParts = [];
    if (profile?.student_id) {
      metaParts.push(t('student.studentId') + profile.student_id);
    }
    if (profile?.email) metaParts.push(profile.email);
    $('student-meta').textContent = metaParts.join(' · ') || '';

    const [questionsRes, badgesRes, sessionsRes, topicStatsRes] =
      await Promise.all([
        supabase
          .from('questions')
          .select(
            'id, type, stage, created_at, grammar_topic_id, grammar_topics(title)'
          )
          .eq('student_id', userId)
          .order('created_at', { ascending: false }),
        supabase
          .from('badges')
          .select('badge_name, description, earned_at, grammar_topics(title)')
          .eq('student_id', userId)
          .order('earned_at', { ascending: false }),
        supabase
          .from('user_sessions')
          .select('id, start_time, end_time')
          .eq('student_id', userId),
        supabase
          .from('student_topic_usage_stats')
          .select(
            'question_completion_count, login_count, total_session_minutes, grammar_topics(title)'
          )
          .eq('student_id', userId)
          .order('updated_at', { ascending: false }),
      ]);

    const questions = questionsRes.data || [];
    const badges = badgesRes.data || [];
    const sessions = sessionsRes.data || [];
    const topicStats = topicStatsRes.data || [];

    if (questionsRes.error) console.warn(questionsRes.error);
    if (badgesRes.error) console.warn(badgesRes.error);
    if (sessionsRes.error) console.warn(sessionsRes.error);
    if (topicStatsRes.error) console.warn(topicStatsRes.error);

    const stageCounts = [0, 0, 0, 0];
    for (const q of questions) {
      const s = Number(q.stage);
      if (s >= 1 && s <= 4) stageCounts[s - 1]++;
    }

    let totalMinutes = 0;
    for (const sess of sessions) {
      if (sess.start_time && sess.end_time) {
        const ms =
          new Date(sess.end_time).getTime() -
          new Date(sess.start_time).getTime();
        if (ms > 0) totalMinutes += ms / 60000;
      }
    }

    const minutesValue =
      totalMinutes >= 1
        ? Math.round(totalMinutes) + t('student.minutes')
        : t('student.minutesUnder');

    renderStats([
      { label: t('student.stat.questions'), value: String(questions.length) },
      { label: t('student.stat.badges'), value: String(badges.length) },
      { label: t('student.stat.sessions'), value: String(sessions.length) },
      { label: t('student.stat.minutes'), value: minutesValue },
    ]);

    renderStageBars(stageCounts);

    const tbody = $('recent-questions-body');
    const noQ = $('no-questions');
    const recent = questions.slice(0, 15);
    if (tbody) {
      if (!recent.length) {
        tbody.innerHTML = '';
        noQ?.classList.remove('hidden');
      } else {
        noQ?.classList.add('hidden');
        tbody.innerHTML = recent
          .map((q) => {
            const title =
              (q.grammar_topics && q.grammar_topics.title) || '—';
            return (
              '<tr><td>' +
              escapeHtml(title) +
              '</td><td>' +
              typeLabel(q.type) +
              '</td><td>' +
              escapeHtml(t('student.stageLabel', { n: String(q.stage) })) +
              '</td><td>' +
              formatDate(q.created_at) +
              '</td></tr>'
            );
          })
          .join('');
      }
    }

    const badgesList = $('badges-list');
    const noB = $('no-badges');
    if (badgesList) {
      if (!badges.length) {
        badgesList.innerHTML = '';
        noB?.classList.remove('hidden');
      } else {
        noB?.classList.add('hidden');
        badgesList.innerHTML = badges
          .map((b) => {
            const topic =
              (b.grammar_topics && b.grammar_topics.title) || '';
            return (
              '<li><strong>' +
              escapeHtml(b.badge_name) +
              '</strong>' +
              (topic ? ' · ' + escapeHtml(topic) : '') +
              '<br /><span class="badge-desc">' +
              escapeHtml(b.description || '') +
              '</span><span class="badge-time">' +
              formatDate(b.earned_at) +
              '</span></li>'
            );
          })
          .join('');
      }
    }

    const statsBody = $('topic-stats-body');
    const noTs = $('no-topic-stats');
    if (statsBody) {
      if (!topicStats.length) {
        statsBody.innerHTML = '';
        noTs?.classList.remove('hidden');
      } else {
        noTs?.classList.add('hidden');
        statsBody.innerHTML = topicStats
          .map((row) => {
            const title =
              (row.grammar_topics && row.grammar_topics.title) || '—';
            return (
              '<tr><td>' +
              escapeHtml(title) +
              '</td><td>' +
              (row.question_completion_count ?? 0) +
              '</td><td>' +
              (row.login_count ?? 0) +
              '</td><td>' +
              (row.total_session_minutes ?? 0) +
              '</td></tr>'
            );
          })
          .join('');
      }
    }

    clearStatus();
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  async function showDashboard(session) {
    loginSection.classList.add('hidden');
    dashboardSection.classList.remove('hidden');
    await loadDashboard(session.user.id);
  }

  async function checkSession() {
    const { data } = await supabase.auth.getSession();
    if (data.session && (await resolveIsStudent(data.session.user))) {
      await showDashboard(data.session);
      return true;
    }
    return false;
  }

  $('login-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    clearStatus();
    setStatus(t('student.loggingIn'), 'info');
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: $('email').value.trim(),
        password: $('password').value,
      });
      if (error) throw error;
      if (!(await resolveIsStudent(data.user))) {
        await supabase.auth.signOut();
        setStatus(t('student.studentsOnly'), 'error');
        return;
      }
      await showDashboard(data.session);
    } catch (err) {
      setStatus(t('student.loginFail') + (err.message || String(err)), 'error');
    }
  });

  $('logout-btn').addEventListener('click', async () => {
    await supabase.auth.signOut();
    dashboardSection.classList.add('hidden');
    loginSection.classList.remove('hidden');
    lastDashboardUserId = null;
    clearStatus();
  });

  checkSession();
})();
