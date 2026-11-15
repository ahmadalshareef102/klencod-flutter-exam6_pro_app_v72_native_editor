import 'package:flutter/material.dart';

import '../editor_data.dart';
import '../engine_api.dart';
import '../exam_summary.dart';
import '../theme.dart';
import '../widgets/soft_card.dart';

const List<(String, String)> kMetaFields = [
  ('republic', 'الدولة / الجمهورية'),
  ('ministry', 'الوزارة'),
  ('governorate', 'المحافظة'),
  ('directorate', 'المديرية'),
  ('school', 'اسم المدرسة'),
  ('grade', 'الصف الدراسي'),
  ('subject', 'المادة'),
  ('semester', 'الفصل الدراسي'),
  ('year', 'العام الدراسي'),
  ('title', 'عنوان الاختبار'),
  ('duration', 'الزمن'),
  ('teacher', 'مدرس المادة'),
  ('maxscore', 'الدرجة النهائية'),
  ('notes', 'ملاحظات وتعليمات'),
];

const List<(String, String)> kVisibilityFields = [
  ('studentBar', 'شريط اسم الطالب والشعبة'),
  ('officialHeader', 'كليشة الترويسة كاملة'),
  ('bismillah', 'البسملة'),
  ('logo', 'الشعار'),
  ('govDir', 'المحافظة والمديرية'),
  ('tableHead', 'عناوين أعمدة الجدول'),
  ('footer', 'تذييل المعلم'),
];

const List<(String, String, IconData)> kQuestionTypes = [
  ('essay', 'مقالي', Icons.notes),
  ('mcq', 'اختيار متعدد', Icons.checklist),
  ('tf', 'صح وخطأ', Icons.rule),
  ('fill', 'أكمل الفراغات', Icons.more_horiz),
  ('match', 'التوصيل', Icons.swap_horiz),
  ('table', 'سؤال جدول', Icons.table_chart_outlined),
  ('image', 'صورة حرة', Icons.image_outlined),
  ('image-grid', 'شبكة صور', Icons.grid_view),
];

const List<(String, String)> kTableModes = [
  ('mode-grid', 'جدول: شبكة'),
  ('mode-horizontal', 'خطوط أفقية'),
  ('mode-outer-only', 'إطار خارجي'),
  ('mode-borderless', 'بدون حدود'),
];

const List<(String, String)> kPageFits = [
  ('fit-1', 'ضغط: صفحة 1'),
  ('fit-2', 'ضغط: صفحتان'),
  ('custom', 'ضغط: مخصص'),
];

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.api,
    required this.tick,
    required this.onPreview,
    required this.onPaste,
    required this.onNewExam,
    required this.onEditQuestion,
  });

  final EngineApi api;

  /// يتغير رقمه لإعادة قراءة الحالة من المحرك.
  final int tick;
  final VoidCallback onPreview;
  final VoidCallback onPaste;
  final VoidCallback onNewExam;
  final void Function(String qid, String name) onEditQuestion;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  EditorData? _d;
  bool _loading = true;
  bool _metaOpen = true;
  Sums _sums = const Sums(sum: 0, target: 0, match: false);
  final Map<String, TextEditingController> _meta = {};
  final Map<String, TextEditingController> _q = {};
  final TextEditingController _fontSize = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EditorScreen old) {
    super.didUpdateWidget(old);
    if (old.tick != widget.tick) _load();
  }

  @override
  void dispose() {
    for (final c in [..._meta.values, ..._q.values, _fontSize]) {
      c.dispose();
    }
    super.dispose();
  }

  void _put(Map<String, TextEditingController> m, String key, String value) {
    final c = m[key];
    if (c == null) {
      m[key] = TextEditingController(text: value);
    } else if (c.text != value) {
      c.text = value;
    }
  }

  Future<void> _load() async {
    final d = await widget.api.editorState();
    if (!mounted) return;
    if (d != null) {
      d.meta.forEach((k, v) => _put(_meta, k, v));
      for (final q in d.questions) {
        _put(_q, '${q.id}|name', q.name);
        _put(_q, '${q.id}|score', fmtNum(q.score));
        _put(_q, '${q.id}|subtitle', q.subtitle);
      }
      final ids = d.questions.map((q) => q.id).toSet();
      _q.removeWhere((k, c) {
        final drop = !ids.contains(k.split('|').first);
        if (drop) c.dispose();
        return drop;
      });
      final fs = fmtNum(d.fontSize);
      if (_fontSize.text != fs) _fontSize.text = fs;
    }
    setState(() {
      _d = d;
      _loading = false;
      if (d != null) _sums = d.sums;
    });
  }

  Future<void> _then(Future<void> Function() op) async {
    await op();
    await _load();
  }

  Future<void> _addQuestion() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إضافة سؤال',
                  style: TextStyle(fontSize: 22, color: AppColors.ink)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final t in kQuestionTypes)
                    ActionChip(
                      avatar: Icon(t.$3, size: 20, color: AppColors.maroon),
                      label: Text(t.$2),
                      backgroundColor: AppColors.pink,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      onPressed: () => Navigator.pop(ctx, t.$1),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (type == null) return;
    await _then(() => widget.api.addQuestion(type));
  }

  Future<void> _deleteQuestion(int idx, QuestionItem q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف السؤال'),
        content: Text('هل تريد حذف «${q.name}»؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) await _then(() => widget.api.remove(idx));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final d = _d;
    if (d == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('المحرك لم يجهز بعد',
                style: TextStyle(fontSize: 18, color: AppColors.muted)),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const Text('المحرر', style: TextStyle(fontSize: 26, color: AppColors.ink)),
        const SizedBox(height: 10),
        _scoreCard(d),
        const SizedBox(height: 12),
        _presetsCard(d),
        const SizedBox(height: 12),
        _headerCard(d),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text('الأسئلة (${d.questions.length})',
                  style: const TextStyle(fontSize: 22, color: AppColors.ink)),
            ),
            FilledButton.icon(
              onPressed: _addQuestion,
              icon: const Icon(Icons.add),
              label: const Text('إضافة سؤال'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.maroon,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (d.questions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('لا توجد أسئلة. أضف سؤالاً من الزر أعلاه.',
                  style: TextStyle(color: AppColors.muted)),
            ),
          ),
        for (var i = 0; i < d.questions.length; i++) ...[
          _questionCard(i, d.questions[i], d.questions.length),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ------------------------------------------------------------ شريط الدرجات

  Widget _scoreCard(EditorData d) {
    final ok = _sums.match;
    return SoftCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'المجموع: ${fmtNum(_sums.sum)} / ${fmtNum(_sums.target)}',
                  style: const TextStyle(fontSize: 22, color: AppColors.ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ok ? AppColors.chipTeal : AppColors.pink,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _sums.badge,
                  style: TextStyle(
                      fontSize: 14,
                      color: ok ? AppColors.iconTeal : AppColors.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(Icons.translate,
                  d.lang == 'en' ? 'تحويل للعربية' : 'تحويل للإنجليزية (EN)',
                  () => _then(widget.api.toggleLang)),
              _pill(Icons.visibility_outlined, 'المعاينة', widget.onPreview),
              _pill(Icons.content_paste, 'لصق', widget.onPaste),
              _pill(Icons.note_add_outlined, 'جديد', widget.onNewExam),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label, VoidCallback onTap) => ActionChip(
        avatar: Icon(icon, size: 18, color: AppColors.maroon),
        label: Text(label),
        backgroundColor: AppColors.pink,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        onPressed: onTap,
      );

  // ------------------------------------------------------- الإعدادات المسبقة

  Widget _presetsCard(EditorData d) {
    final fit = kPageFits.any((e) => e.$1 == d.pageFit) ? d.pageFit : 'custom';
    final mode = kTableModes.any((e) => e.$1 == d.tableMode) ? d.tableMode : 'mode-grid';
    return SoftCard(
      radius: 28,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _pill(Icons.format_bold, 'خط عريض 13.5',
              () => _then(widget.api.presetBold)),
          _pill(Icons.water_drop_outlined, 'توسيط العلامة المائية',
              () => _then(widget.api.presetWatermark)),
          _dropdown(
            value: fit,
            items: kPageFits,
            onChanged: (v) => _then(() => widget.api.pageFit(v)),
          ),
          _dropdown(
            value: mode,
            items: kTableModes,
            onChanged: (v) => _then(() => widget.api.syncTableMode(v)),
          ),
          SizedBox(
            width: 96,
            child: TextField(
              controller: _fontSize,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _fieldDecoration('الخط (pt)'),
              onChanged: (v) => widget.api.fontSize(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<(String, String)> items,
    required void Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        isDense: true,
        items: [
          for (final e in items) DropdownMenuItem(value: e.$1, child: Text(e.$2)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.maroon, width: 1.5),
        ),
      );

  // ------------------------------------------------------------ بيانات الرأس

  Widget _headerCard(EditorData d) {
    Widget field((String, String) f) {
      final isNum = f.$1 == 'maxscore';
      return TextField(
        controller: _meta[f.$1],
        keyboardType: isNum
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: _fieldDecoration(f.$2),
        onChanged: (v) async {
          final s = await widget.api.setMeta(f.$1, v);
          if (s != null && mounted) setState(() => _sums = s);
        },
      );
    }

    final rows = <Widget>[];
    final wide = kMetaFields.where((f) => f.$1 == 'notes').toList();
    final pairs = kMetaFields.where((f) => f.$1 != 'notes').toList();
    for (var i = 0; i < pairs.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: field(pairs[i])),
            const SizedBox(width: 10),
            Expanded(
                child: i + 1 < pairs.length ? field(pairs[i + 1]) : const SizedBox()),
          ],
        ),
      ));
    }
    for (final f in wide) {
      rows.add(field(f));
    }

    return SoftCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _metaOpen = !_metaOpen),
            child: Row(
              children: [
                const Icon(Icons.assignment_outlined, color: AppColors.maroon),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('بيانات الرأس وإظهار العناصر',
                      style: TextStyle(fontSize: 19, color: AppColors.ink)),
                ),
                Icon(_metaOpen ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.muted),
              ],
            ),
          ),
          if (_metaOpen) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final v in kVisibilityFields)
                  FilterChip(
                    label: Text(v.$2),
                    selected: d.visibility[v.$1] ?? true,
                    selectedColor: AppColors.pink,
                    checkmarkColor: AppColors.maroon,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.border),
                    shape: const StadiumBorder(),
                    onSelected: (on) async {
                      await widget.api.setVisibility(v.$1, on);
                      _load();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ...rows,
          ],
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- الأسئلة

  Widget _questionCard(int idx, QuestionItem q, int total) {
    TextField input(String suffix, String label, {bool number = false}) {
      return TextField(
        controller: _q['${q.id}|$suffix'],
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: _fieldDecoration(label),
        onChanged: (v) async {
          final s = await widget.api.setQuestion(idx, suffix, v);
          if (s != null && mounted) setState(() => _sums = s);
        },
      );
    }

    return SoftCard(
      key: ValueKey(q.id),
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: input('name', 'اسم السؤال')),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: input('score', 'الدرجة', number: true)),
            ],
          ),
          const SizedBox(height: 8),
          input('subtitle', 'عنوان فرعي (اختياري)'),
          const SizedBox(height: 8),
          Text(
            q.text.isEmpty ? '(نص السؤال فارغ)' : q.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          if (q.hasImage || q.hasTable) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              if (q.hasImage)
                const Chip(
                    avatar: Icon(Icons.image_outlined, size: 16),
                    label: Text('صورة'),
                    visualDensity: VisualDensity.compact),
              if (q.hasTable)
                const Chip(
                    avatar: Icon(Icons.table_chart_outlined, size: 16),
                    label: Text('جدول'),
                    visualDensity: VisualDensity.compact),
            ]),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => widget.onEditQuestion(q.id, q.name),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('تحرير نص السؤال'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.pink,
                    foregroundColor: AppColors.maroon,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'أعلى',
                onPressed: idx == 0 ? null : () => _then(() => widget.api.move(idx, -1)),
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'أسفل',
                onPressed: idx == total - 1
                    ? null
                    : () => _then(() => widget.api.move(idx, 1)),
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: 'نسخ',
                onPressed: () => _then(() => widget.api.duplicate(idx)),
                icon: const Icon(Icons.copy_outlined),
              ),
              IconButton(
                tooltip: 'حذف',
                onPressed: () => _deleteQuestion(idx, q),
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
