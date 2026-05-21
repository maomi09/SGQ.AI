(function () {
  const cfg = window.SGQ_EXPORT_CONFIG;
  if (!cfg?.supabaseUrl || !cfg?.supabaseAnonKey) {
    document.body.innerHTML =
      '<p style="padding:24px">缺少 config.js 設定，請參考 README.md。</p>';
    return;
  }

  const supabase = window.supabase.createClient(
    cfg.supabaseUrl,
    cfg.supabaseAnonKey
  );

  const $ = (id) => document.getElementById(id);

  const loginSection = $('login-section');
  const exportSection = $('export-section');
  const statusEl = $('status');
  const userEmailEl = $('user-email');

  let classes = [];
  let topics = [];
  let students = [];

  function setStatus(message, type) {
    statusEl.textContent = message;
    statusEl.className = 'status ' + (type || 'info');
    statusEl.classList.remove('hidden');
  }

  function clearStatus() {
    statusEl.classList.add('hidden');
  }

  function isTeacher(user) {
    const role =
      user?.user_metadata?.role ||
      user?.app_metadata?.role ||
      user?.raw_user_meta_data?.role;
    return role === 'teacher';
  }

  function formatOptions(options) {
    if (!options) return '';
    if (Array.isArray(options)) return options.join(' | ');
    if (typeof options === 'string') {
      try {
        const parsed = JSON.parse(options);
        if (Array.isArray(parsed)) return parsed.join(' | ');
      } catch (_) {
        return options;
      }
    }
    return String(options);
  }

  function stageLabel(stage) {
    const n = Number(stage);
    if (n >= 1 && n <= 4) return '第' + n + '階段';
    return String(stage ?? '');
  }

  function typeLabel(type) {
    if (type === 'multipleChoice') return '選擇題';
    if (type === 'shortAnswer') return '簡答題';
    return type || '';
  }

  function buildRows(questions, studentsMap, topicTitle) {
    const rows = [];
    for (const q of questions) {
      const student = studentsMap[q.student_id];
      if (!student) continue;
      rows.push({
        課程單元: topicTitle || '',
        學生姓名: student.name || '',
        學號: student.student_id || '',
        班級: student.class_name || '',
        題型: typeLabel(q.type),
        題目: q.question || '',
        選項: formatOptions(q.options),
        正確答案: q.correct_answer || '',
        解析: q.explanation || '',
        階段: stageLabel(q.stage),
        教師評語: q.teacher_comment || '',
        建立時間: q.created_at || '',
        更新時間: q.updated_at || '',
      });
    }
    return rows;
  }

  function downloadCsv(rows, filename) {
    if (!rows.length) {
      setStatus('沒有可匯出的資料。', 'error');
      return;
    }
    const headers = Object.keys(rows[0]);
    const escape = (v) => {
      const s = String(v ?? '').replace(/"/g, '""');
      return '"' + s + '"';
    };
    const lines = [
      headers.map(escape).join(','),
      ...rows.map((r) => headers.map((h) => escape(r[h])).join(',')),
    ];
    const bom = '\uFEFF';
    const blob = new Blob([bom + lines.join('\r\n')], {
      type: 'text/csv;charset=utf-8',
    });
    triggerDownload(blob, filename.replace(/\.xlsx?$/i, '') + '.csv');
    setStatus('已下載 CSV（可用 Excel 開啟）。共 ' + rows.length + ' 筆。', 'success');
  }

  function downloadXlsx(rows, filename) {
    if (!rows.length) {
      setStatus('沒有可匯出的資料。', 'error');
      return;
    }
    if (typeof XLSX === 'undefined') {
      setStatus('Excel 函式庫尚未載入，請重新整理頁面。', 'error');
      return;
    }
    const sheet = XLSX.utils.json_to_sheet(rows);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, sheet, '學生題目');
    XLSX.writeFile(wb, filename.endsWith('.xlsx') ? filename : filename + '.xlsx');
    setStatus('已下載 Excel。共 ' + rows.length + ' 筆。', 'success');
  }

  function triggerDownload(blob, name) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = name;
    a.click();
    URL.revokeObjectURL(url);
  }

  async function loadClasses() {
    const { data, error } = await supabase
      .from('classes')
      .select('id, name, code')
      .order('name');
    if (error) throw error;
    classes = data || [];
    const sel = $('class-select');
    sel.innerHTML = '<option value="">全部班級</option>';
    for (const c of classes) {
      const opt = document.createElement('option');
      opt.value = c.id;
      opt.textContent = c.name + (c.code ? ' (' + c.code + ')' : '');
      sel.appendChild(opt);
    }
  }

  async function loadTopics(classId) {
    let query = supabase
      .from('grammar_topics')
      .select('id, title, class_id')
      .order('title');
    if (classId) query = query.eq('class_id', classId);
    const { data, error } = await query;
    if (error) throw error;
    topics = data || [];
    const sel = $('topic-select');
    sel.innerHTML = '<option value="">請選擇課程單元</option>';
    for (const t of topics) {
      const opt = document.createElement('option');
      opt.value = t.id;
      opt.textContent = t.title;
      sel.appendChild(opt);
    }
  }

  async function loadStudents(classId) {
    let query = supabase
      .from('users')
      .select('id, name, student_id, class_id')
      .eq('role', 'student')
      .order('name');
    if (classId) query = query.eq('class_id', classId);
    const { data, error } = await query;
    if (error) throw error;
    students = data || [];
    const classNameById = Object.fromEntries(classes.map((c) => [c.id, c.name]));
    const sel = $('student-select');
    sel.innerHTML = '<option value="">全部學生</option>';
    for (const s of students) {
      const opt = document.createElement('option');
      opt.value = s.id;
      const label =
        (s.name || '未命名') +
        (s.student_id ? ' (' + s.student_id + ')' : '');
      opt.textContent = label;
      sel.appendChild(opt);
    }
    return classNameById;
  }

  async function fetchExportRows() {
    const classId = $('class-select').value || null;
    const topicId = $('topic-select').value;
    const studentId = $('student-select').value || null;

    if (!topicId && !studentId) {
      setStatus('請至少選擇「課程單元」，或選擇「單一學生」匯出該生全部題目。', 'error');
      return null;
    }

    setStatus('正在載入題目…', 'info');
    $('btn-csv').disabled = true;
    $('btn-xlsx').disabled = true;

    try {
      const classNameById = Object.fromEntries(
        classes.map((c) => [c.id, c.name])
      );

      let questionsQuery = supabase
        .from('questions')
        .select(
          'id, student_id, grammar_topic_id, type, question, options, correct_answer, explanation, stage, teacher_comment, created_at, updated_at'
        )
        .order('created_at', { ascending: true });

      if (topicId) {
        questionsQuery = questionsQuery.eq('grammar_topic_id', topicId);
      }
      if (studentId) {
        questionsQuery = questionsQuery.eq('student_id', studentId);
      }

      const { data: questions, error: qErr } = await questionsQuery;
      if (qErr) throw qErr;
      if (!questions?.length) {
        setStatus('找不到符合條件的題目。', 'error');
        return null;
      }

      const studentIds = [...new Set(questions.map((q) => q.student_id))];
      let studentsQuery = supabase
        .from('users')
        .select('id, name, student_id, class_id')
        .eq('role', 'student')
        .in('id', studentIds);

      if (classId) {
        studentsQuery = studentsQuery.eq('class_id', classId);
      }

      const { data: studentRows, error: sErr } = await studentsQuery;
      if (sErr) throw sErr;
      if (!studentRows?.length) {
        setStatus('找不到符合班級篩選的學生資料。', 'error');
        return null;
      }

      const topicTitle =
        topics.find((t) => t.id === topicId)?.title ||
        (studentId && !topicId ? '全部單元' : '');

      const studentsMap = {};
      for (const s of studentRows) {
        studentsMap[s.id] = {
          name: s.name,
          student_id: s.student_id,
          class_name: classNameById[s.class_id] || '',
        };
      }

      const filteredQuestions = questions.filter(
        (q) => studentsMap[q.student_id]
      );

      return buildRows(filteredQuestions, studentsMap, topicTitle);
    } finally {
      $('btn-csv').disabled = false;
      $('btn-xlsx').disabled = false;
    }
  }

  function makeFilename() {
    const topic =
      $('topic-select').selectedOptions[0]?.textContent?.trim() || '題目';
    const student =
      $('student-select').value &&
      $('student-select').selectedOptions[0]?.textContent?.trim();
    const date = new Date().toISOString().slice(0, 10);
    const base = student
      ? 'SGQ_' + student + '_' + date
      : 'SGQ_' + topic + '_' + date;
    return base.replace(/[\\/:*?"<>|]/g, '_');
  }

  async function onExport(format) {
    clearStatus();
    try {
      const rows = await fetchExportRows();
      if (!rows?.length) return;
      const name = makeFilename();
      if (format === 'csv') downloadCsv(rows, name);
      else downloadXlsx(rows, name);
    } catch (e) {
      console.error(e);
      setStatus('匯出失敗：' + (e.message || String(e)), 'error');
    }
  }

  async function onClassChange() {
    const classId = $('class-select').value || null;
    clearStatus();
    try {
      await Promise.all([loadTopics(classId), loadStudents(classId)]);
    } catch (e) {
      setStatus('載入班級資料失敗：' + e.message, 'error');
    }
  }

  async function showExportUi(session) {
    loginSection.classList.add('hidden');
    exportSection.classList.remove('hidden');
    userEmailEl.textContent = session.user.email || '';
    clearStatus();
    await loadClasses();
    await loadTopics(null);
    await loadStudents(null);
  }

  async function checkSession() {
    const { data } = await supabase.auth.getSession();
    if (data.session && isTeacher(data.session.user)) {
      await showExportUi(data.session);
      return true;
    }
    return false;
  }

  $('login-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    clearStatus();
    const email = $('email').value.trim();
    const password = $('password').value;
    setStatus('登入中…', 'info');
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });
      if (error) throw error;
      if (!isTeacher(data.user)) {
        await supabase.auth.signOut();
        setStatus('此帳號不是教師，無法使用匯出功能。', 'error');
        return;
      }
      await showExportUi(data.session);
    } catch (err) {
      setStatus('登入失敗：' + (err.message || String(err)), 'error');
    }
  });

  $('logout-btn').addEventListener('click', async () => {
    await supabase.auth.signOut();
    exportSection.classList.add('hidden');
    loginSection.classList.remove('hidden');
    clearStatus();
  });

  $('class-select').addEventListener('change', onClassChange);
  $('btn-csv').addEventListener('click', () => onExport('csv'));
  $('btn-xlsx').addEventListener('click', () => onExport('xlsx'));

  checkSession().catch((e) => {
    setStatus('初始化失敗：' + e.message, 'error');
  });
})();
