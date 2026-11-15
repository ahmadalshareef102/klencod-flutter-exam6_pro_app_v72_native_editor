import 'package:flutter/material.dart';

import '../engine_api.dart';
import '../theme.dart';

/// شريط أدوات تحرير نص السؤال (يحل محل شريط الويب).
class QuestionToolbar extends StatelessWidget {
  const QuestionToolbar({
    super.key,
    required this.api,
    required this.onPickImages,
    required this.onMessage,
  });

  final EngineApi api;

  /// يختار صوراً أصلياً ويدرجها؛ grid = شبكة صور.
  final Future<void> Function(bool grid) onPickImages;
  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) {
    Widget tool(IconData icon, String tip, VoidCallback onTap) => IconButton(
          icon: Icon(icon),
          tooltip: tip,
          color: AppColors.maroon,
          onPressed: onTap,
        );
    return Material(
      color: AppColors.navBg,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            children: [
              tool(Icons.undo, 'تراجع', api.undo),
              tool(Icons.redo, 'إعادة', api.redo),
              tool(Icons.format_bold, 'عريض', () => api.cmd('bold')),
              tool(Icons.format_underlined, 'تسطير', () => api.cmd('underline')),
              tool(Icons.format_color_text, 'لون النص', () => _colors(context)),
              tool(Icons.horizontal_rule, 'سطر إجابة', api.answerLine),
              tool(Icons.table_chart_outlined, 'إدراج جدول', () => _tableDialog(context)),
              tool(Icons.image_outlined, 'صورة حرة', () => onPickImages(false)),
              tool(Icons.grid_view, 'شبكة صور', () => onPickImages(true)),
              tool(Icons.tune, 'تحكم الصورة', () => _imageTools(context)),
              tool(Icons.table_rows_outlined, 'تحكم الجدول', () => _tableTools(context)),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ لون النص

  void _colors(BuildContext context) {
    const palette = [
      '#000000', '#dc2626', '#1d4ed8', '#166534', '#ea580c', '#7c3aed', '#8b4a5e', '#6b7280',
    ];
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final c in palette)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    api.color(c);
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Color(int.parse('FF${c.substring(1)}', radix: 16)),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- إدراج جدول

  Future<void> _tableDialog(BuildContext context) async {
    var rows = 2, cols = 2;
    var style = 'borderless-table';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('إدراج جدول'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _stepper('الصفوف', rows, 1, 20, (v) => setS(() => rows = v)),
              _stepper('الأعمدة', cols, 1, 10, (v) => setS(() => cols = v)),
              DropdownButton<String>(
                value: style,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('بحدود واضحة')),
                  DropdownMenuItem(
                      value: 'borderless-table', child: Text('بدون حدود (لترتيب الصور)')),
                  DropdownMenuItem(value: 'dashed-table', child: Text('حدود متقطعة')),
                ],
                onChanged: (v) => setS(() => style = v ?? style),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true), child: const Text('إدراج')),
          ],
        ),
      ),
    );
    if (ok == true) await api.insertTable(rows, cols, style);
  }

  Widget _stepper(String label, int v, int min, int max, void Function(int) set) => Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
              onPressed: v > min ? () => set(v - 1) : null,
              icon: const Icon(Icons.remove_circle_outline)),
          Text('$v', style: const TextStyle(fontSize: 18)),
          IconButton(
              onPressed: v < max ? () => set(v + 1) : null,
              icon: const Icon(Icons.add_circle_outline)),
        ],
      );

  // ------------------------------------------------------------- أدوات الصورة

  Future<bool> _need(String what) async {
    final sel = await api.selection();
    final has = sel != null && sel[what] == true;
    if (!has) {
      onMessage(what == 'img'
          ? 'اضغط على الصورة داخل نص السؤال أولاً'
          : 'اضغط داخل خلية الجدول أولاً');
    }
    return has;
  }

  Future<void> _imageTools(BuildContext context) async {
    if (!await _need('img') || !context.mounted) return;
    Widget chips(List<(String, String)> items, void Function(String) f, BuildContext ctx) => Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final e in items)
              ActionChip(
                label: Text(e.$2),
                backgroundColor: AppColors.pink,
                side: BorderSide.none,
                onPressed: () => f(e.$1),
              ),
          ],
        );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تحكم الصورة', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 10),
              const Text('الالتفاف', style: TextStyle(color: AppColors.muted)),
              chips(const [
                ('wrap-center', 'توسيط مستقل'),
                ('wrap-inline', 'بجانب النص'),
                ('wrap-tight-right', 'مشدود يمين النص'),
                ('wrap-tight-left', 'مشدود يسار النص'),
                ('wrap-front', 'أمام النص (سحب حر)'),
              ], api.imgWrap, ctx),
              const SizedBox(height: 10),
              const Text('الحجم', style: TextStyle(color: AppColors.muted)),
              chips(const [
                ('20%', '20%'), ('35%', '35%'), ('50%', '50%'), ('75%', '75%'), ('100%', '100%'),
              ], api.imgSize, ctx),
              const SizedBox(height: 10),
              const Text('الإطار', style: TextStyle(color: AppColors.muted)),
              chips(const [
                ('img-borderless', 'بدون إطار'),
                ('img-square', 'مربع'),
                ('img-rounded', 'حواف دائرية'),
                ('img-circle', 'دائري'),
                ('img-double', 'مزدوج'),
                ('img-dashed', 'متقطع'),
              ], api.imgShape, ctx),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _arrowDialog(context);
                  },
                  icon: const Icon(Icons.north_east, size: 18),
                  label: const Text('إضافة سهم'),
                ),
                OutlinedButton(
                    onPressed: api.imgClearArrows, child: const Text('مسح الأسهم')),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    api.imgDelete();
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  child: const Text('حذف الصورة'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _arrowDialog(BuildContext context) async {
    var dir = '⬅️';
    var color = '#dc2626';
    double x = 45, y = 45;
    final label = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('إضافة سهم على الصورة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButton<String>(
                  value: dir,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: '⬅️', child: Text('⬅️ يسار')),
                    DropdownMenuItem(value: '➡️', child: Text('➡️ يمين')),
                    DropdownMenuItem(value: '⬆️', child: Text('⬆️ أعلى')),
                    DropdownMenuItem(value: '⬇️', child: Text('⬇️ أسفل')),
                    DropdownMenuItem(value: '↖️', child: Text('↖️ أعلى يسار')),
                    DropdownMenuItem(value: '↗️', child: Text('↗️ أعلى يمين')),
                    DropdownMenuItem(value: '↙️', child: Text('↙️ أسفل يسار')),
                    DropdownMenuItem(value: '↘️', child: Text('↘️ أسفل يمين')),
                  ],
                  onChanged: (v) => setS(() => dir = v ?? dir),
                ),
                Wrap(spacing: 10, children: [
                  for (final c in const ['#dc2626', '#1d4ed8', '#166534', '#000000'])
                    GestureDetector(
                      onTap: () => setS(() => color = c),
                      child: Container(
                        width: 34,
                        height: 34,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Color(int.parse('FF${c.substring(1)}', radix: 16)),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: c == color ? AppColors.maroon : AppColors.border,
                              width: c == color ? 3 : 1),
                        ),
                      ),
                    ),
                ]),
                Text('الموضع الأفقي: ${x.round()}%'),
                Slider(value: x, min: 5, max: 90, onChanged: (v) => setS(() => x = v)),
                Text('الموضع الرأسي: ${y.round()}%'),
                Slider(value: y, min: 5, max: 90, onChanged: (v) => setS(() => y = v)),
                TextField(
                  controller: label,
                  decoration: const InputDecoration(labelText: 'تسمية (اختياري)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await api.imgArrow(dir, color, x.round(), y.round(), label.text.trim());
    }
    label.dispose();
  }

  // ------------------------------------------------------------- أدوات الجدول

  Future<void> _tableTools(BuildContext context) async {
    if (!await _need('table') || !context.mounted) return;
    Widget btn(String label, VoidCallback f, {bool danger = false}) => OutlinedButton(
          onPressed: f,
          style: OutlinedButton.styleFrom(
              foregroundColor: danger ? AppColors.danger : AppColors.maroon),
          child: Text(label),
        );
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تحكم الجدول', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                btn('حذف الحدود', () => api.tableBorder('borderless')),
                btn('إظهار الحدود', () => api.tableBorder('solid')),
                btn('+ صف', () => api.tableOp('addRow')),
                btn('- صف', () => api.tableOp('delRow')),
                btn('+ عمود', () => api.tableOp('addCol')),
                btn('- عمود', () => api.tableOp('delCol')),
                btn('حذف الجدول', () {
                  Navigator.pop(ctx);
                  api.tableOp('delTable');
                }, danger: true),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
