/* واجهة برمجية للواجهة الأصلية (Flutter) فوق دوال المنصة الأصلية.
   المحرك (JS) يبقى مصدر الحقيقة لحالة الاختبار؛ Flutter يقرأ ويكتب عبر هذه الدوال. */
(function () {
  if (window.Exam6Api) return;

  var META = ['republic', 'ministry', 'governorate', 'directorate', 'school', 'grade', 'subject',
              'semester', 'year', 'title', 'duration', 'teacher', 'maxscore', 'notes'];
  var VIS = { studentBar: 'vis-student-bar', officialHeader: 'vis-official-header', bismillah: 'vis-bismillah',
              logo: 'vis-logo', govDir: 'vis-gov-dir', tableHead: 'vis-table-head', footer: 'vis-footer' };
  var DES = { lang: 'tpl-lang', tableMode: 'tpl-tablemode', fontFamily: 'tpl-font', fontWeight: 'tpl-fontweight',
              lineHeight: 'tpl-lineheight', pageFrame: 'tpl-pageframe', borderColor: 'tpl-bordercolor' };

  function $(id) { return document.getElementById(id); }
  function plain(html) {
    var d = document.createElement('div');
    d.innerHTML = html || '';
    return (d.textContent || '').replace(/\s+/g, ' ').trim();
  }
  function sums() {
    var r = recalculateScores();
    return { sum: r.sum, target: r.target, match: r.isMatch };
  }
  function focusedIndex() {
    return currentExam.questions.findIndex(function (q) { return 'rich_ed_' + q.id === activeEditorId; });
  }
  function fileFrom(item, i) {
    var bin = atob(item.b64);
    var u = new Uint8Array(bin.length);
    for (var k = 0; k < bin.length; k++) u[k] = bin.charCodeAt(k);
    return new File([u], 'image' + i, { type: item.mime || 'image/jpeg' });
  }

  window.Exam6Api = {
    /* ---------- قراءة الحالة ---------- */
    state: function () {
      var e = currentExam, m = e.meta, d = e.design;
      var meta = {};
      META.forEach(function (k) {
        var v = k === 'maxscore' ? m.maxScore : m[k];
        meta[k] = v === undefined || v === null ? '' : String(v);
      });
      var vis = {};
      Object.keys(VIS).forEach(function (k) { vis[k] = !(e.visibility && e.visibility[k] === false); });
      return {
        id: e.id, meta: meta, visibility: vis,
        design: { lang: d.lang || 'ar', tableMode: d.tableMode || 'mode-grid',
                  fontSize: parseFloat(d.fontSize) || 13.5, pageFit: d.pageFit || 'custom' },
        questions: e.questions.map(function (q) {
          var h = q.content || '';
          return { id: q.id, name: q.name || '', subtitle: q.subtitle || '', score: parseFloat(q.score) || 0,
                   text: plain(h).slice(0, 140), hasImage: /<img/i.test(h), hasTable: /<table/i.test(h) };
        }),
        sums: sums()
      };
    },
    designState: function () {
      var d = currentExam.design;
      var fonts = [];
      var sel = $('tpl-font');
      for (var i = 0; i < sel.options.length; i++) fonts.push({ value: sel.options[i].value, label: sel.options[i].textContent });
      return {
        lang: d.lang || 'ar', tableMode: d.tableMode || 'mode-grid', fontFamily: d.fontFamily,
        fontSize: parseFloat(d.fontSize) || 13.5, fontWeight: String(d.fontWeight || '700'),
        lineHeight: String(d.lineHeight || '1.45'), pageFrame: d.pageFrame || 'none',
        borderColor: d.borderColor || '#000000',
        wmOpacity: d.watermarkOpacity || 8, wmScale: d.watermarkScale || 75,
        logo: d.customLogo || '', watermark: d.watermarkImg || '', fonts: fonts
      };
    },
    sums: function () { return sums(); },

    /* ---------- بيانات الرأس والإظهار ---------- */
    setMeta: function (k, v) {
      var el = $('meta-' + k);
      if (!el) return null;
      el.value = v;
      syncMeta();
      return sums();
    },
    setVisibility: function (k, on) {
      var id = VIS[k];
      if (!id) return false;
      $(id).checked = !!on;
      syncHeaderVisibility();
      return true;
    },

    /* ---------- القوالب والتنسيق ---------- */
    setDesign: function (k, v) {
      var id = DES[k];
      if (!id) return false;
      populateDesignControls();           // مزامنة حقول الواجهة مع الحالة قبل التعديل
      $(id).value = v;
      updateDesignSettings();
      if (k === 'lang') { try { updateLangButtonLabel(); } catch (e) {} }
      return true;
    },
    fontSize: function (v) { changeCustomFontSize(v); populateDesignControls(); return true; },
    syncTableMode: function (v) { syncQuickTableMode(v); populateDesignControls(); return true; },
    pageFit: function (mode) { applyPageFitPreset(mode); populateDesignControls(); return true; },
    presetBold: function () { applyPresetBold135(); populateDesignControls(); return true; },
    presetWatermark: function () { applyPresetWatermark(); populateDesignControls(); return true; },
    toggleLang: function () { toggleExamLanguage(); return true; },
    wmOpacity: function (v) { updateWatermarkOpacity(v); return true; },
    wmScale: function (v) { updateWatermarkScale(v); return true; },
    removeLogo: function () { removeCustomLogo(); return true; },
    removeWatermark: function () { removeWatermark(); return true; },
    setLogo: function (item) { handleLogoUpload({ target: { files: [fileFrom(item, 0)] } }); return true; },
    setWatermark: function (item) { handleWatermarkUpload({ target: { files: [fileFrom(item, 0)] } }); return true; },

    /* ---------- الأسئلة ---------- */
    addQuestion: function (type) { addQuestionByType(type); return true; },
    move: function (idx, dir) { moveQuestion(idx, dir); return true; },
    duplicate: function (idx) { duplicateQuestion(idx); return true; },
    remove: function (idx) {
      if (idx < 0 || idx >= currentExam.questions.length) return false;
      currentExam.questions.splice(idx, 1);
      renderQuestionsEditor(); recalculateScores(); renderLivePreview();
      return true;
    },
    setQuestion: function (idx, field, val) {
      if (!currentExam.questions[idx]) return null;
      if (field === 'score') val = parseFloat(val) || 0;
      updateQuestionField(idx, field, val);
      return sums();
    },
    newExam: function () {
      currentExam = getDefaultExamState();
      populateEditorFromState(); applyDesignVariables(); renderLivePreview();
      return true;
    },

    /* ---------- اللصق الجماعي ---------- */
    analyzePaste: function (text) {
      $('bulk-paste-input').value = text;
      analyzeBulkPaste();
      return parsedBulkQuestions.map(function (q) {
        return { name: q.name, subtitle: q.subtitle, lines: q.bodyLines.length };
      });
    },
    confirmPaste: function () { confirmBulkImport(); return true; },

    /* ---------- وضع تحرير نص سؤال واحد ---------- */
    focus: function (qid) {
      navigateTo('editor');
      renderQuestionsEditor();
      var ed = $('rich_ed_' + qid);
      if (!ed) return false;
      document.querySelectorAll('.exam6-focused').forEach(function (x) { x.classList.remove('exam6-focused'); });
      ed.classList.add('exam6-focused');
      activeEditorId = ed.id;
      return true;
    },
    unfocus: function () {
      document.querySelectorAll('.exam6-focused').forEach(function (x) { x.classList.remove('exam6-focused'); });
      var a = document.activeElement;
      if (a && a.blur) a.blur();
      return true;
    },
    selection: function () { return { img: !!selectedImageEl, table: !!selectedTableEl }; },
    undo: function () { var i = focusedIndex(); if (i >= 0) undoQuestionChange(i); return true; },
    redo: function () { var i = focusedIndex(); if (i >= 0) redoQuestionChange(i); return true; },
    cmd: function (name) { if (activeEditorId) execRichCmd(activeEditorId, name); return true; },
    color: function (hex) { if (activeEditorId) applyTextColor(activeEditorId, hex); return true; },
    answerLine: function () { if (activeEditorId) insertAnswerLine(activeEditorId); return true; },
    insertTable: function (rows, cols, style) {
      if (!activeEditorId) return false;
      $('tb-rows').value = rows; $('tb-cols').value = cols; $('tb-border-style').value = style;
      confirmInsertCustomTable();
      return true;
    },
    insertImages: function (items, mode) {
      if (!activeEditorId) return false;
      imageInsertMode = mode || 'single';
      handleQuestionImageSelected({ target: { files: items.map(fileFrom) } });
      return true;
    },
    imgWrap: function (v) { setSelectedImageWrap(v); return true; },
    imgSize: function (v) { resizeSelectedImage(v); return true; },
    imgShape: function (v) { setSelectedImageShape(v); return true; },
    imgDelete: function () { deleteSelectedImage(); return true; },
    imgClearArrows: function () { clearArrowsOnSelectedImage(); return true; },
    imgArrow: function (dir, color, x, y, label) {
      if (!selectedImageEl) return false;
      $('arrow-dir-select').value = dir; $('arrow-color-input').value = color;
      $('arrow-pos-x').value = x; $('arrow-pos-y').value = y; $('arrow-label-text').value = label || '';
      confirmInsertArrow();
      return true;
    },
    tableBorder: function (mode) { setSubTableBorder(mode); return true; },
    tableOp: function (action) { modifySubTable(action); return true; },

    /* ---------- الورقة A4 ---------- */
    fitPaper: function () {
      var sheet = $('exam-paper-sheet');
      if (!sheet) return false;
      sheet.style.zoom = '';
      var w = sheet.offsetWidth, avail = document.documentElement.clientWidth - 16;
      if (w > 0 && w > avail) sheet.style.zoom = String(avail / w);
      return true;
    },
    print: function () { triggerPrint(); return true; },
    exportWord: function () { exportToWordHTML(); return true; }
  };
})();
