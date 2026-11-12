import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'models.dart';

class JarPage extends StatefulWidget {
  const JarPage({super.key, required this.store});
  final Store store;

  @override
  State<JarPage> createState() => _JarPageState();
}

class _JarPageState extends State<JarPage> {
  final _amount = TextEditingController();
  final _amountFocus = FocusNode();

  Store get store => widget.store;

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Future<bool> _confirm(String text, {String ok = 'Delete', bool danger = true}) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(text, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: danger ? AppColors.red : AppColors.blue),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ok),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  void _add(Category c) {
    final amount = parseAmount(_amount.text);
    if (amount == null) {
      _toast('Type an amount first, like 4,50');
      _amountFocus.requestFocus();
      return;
    }
    HapticFeedback.lightImpact();
    store.addExpense(amount, c);
    _amount.clear();
    _amountFocus.unfocus();
  }

  Future<void> _editBudget() async {
    final ctrl = TextEditingController(text: store.budget.toStringAsFixed(2).replaceAll('.', ','));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Weekly budget'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '€ '),
          onSubmitted: (t) => Navigator.pop(ctx, parseAmount(t)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, parseAmount(ctrl.text)), child: const Text('Save')),
        ],
      ),
    );
    if (value != null) store.setBudget(value);
  }

  Future<void> _newCategory() async {
    final emoji = TextEditingController();
    final name = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          void save() {
            final err = store.addCategory(name.text, emoji.text);
            if (err != null) {
              setLocal(() => error = err);
            } else {
              Navigator.pop(ctx);
            }
          }

          return AlertDialog(
            title: const Text('New category', textAlign: TextAlign.center),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: emoji,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 30),
                      decoration: const InputDecoration(hintText: '🏷️', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final e in suggestedEmojis)
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setLocal(() => emoji.text = e),
                          child: Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F0EA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(e, style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    autofocus: true,
                    maxLength: 14,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Gym',
                      border: const OutlineInputBorder(),
                      errorText: error,
                      counterText: '',
                    ),
                    onChanged: (_) {
                      if (error != null) setLocal(() => error = null);
                    },
                    onSubmitted: (_) => save(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(onPressed: save, child: const Text('Add')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _backup() async {
    await Clipboard.setData(ClipboardData(text: store.exportBackup()));
    _toast('Backup copied. Paste it into Notes or an email to keep it safe.');
  }

  Future<void> _restore() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    final backup = Store.parseBackup(text);
    if (backup == null) {
      _toast("Copy a Spending Jar backup first, then tap Restore");
      return;
    }
    final count = (backup['expenses'] as List).length;
    final ok = await _confirm(
      'Restore this backup? It has $count entries and replaces what is in the app now.',
      ok: 'Restore',
      danger: false,
    );
    if (ok) {
      store.restore(backup);
      _toast('Backup restored');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final weekStart = startOfWeek(now);
        final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
        final week = store.between(weekStart, weekEnd);
        final spent = week.fold<double>(0, (s, e) => s + e.amount);
        final left = store.budget - spent;
        final fill = (left / store.budget).clamp(0.0, 1.0);
        final jarColor = fill > 0.5 ? AppColors.green : (fill > 0.2 ? AppColors.orange : AppColors.red);

        return SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                // ---- Jar + summary ----
                Row(
                  children: [
                    JarGraphic(fill: fill, color: jarColor),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Left this week', style: TextStyle(color: AppColors.muted, fontSize: 14)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              euro(left),
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: left < 0 ? AppColors.red : AppColors.text,
                              ),
                            ),
                          ),
                          Text('Spent ${euro(spent)}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: AppColors.blue,
                              tapTargetSize: MaterialTapTargetSize.padded,
                            ),
                            onPressed: _editBudget,
                            icon: const Icon(Icons.edit, size: 16),
                            label: Text('Budget ${euro(store.budget)}'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ---- Amount ----
                TextField(
                  controller: _amount,
                  focusNode: _amountFocus,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: '€ 0,00',
                    hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
                    filled: true,
                    fillColor: AppColors.card,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ---- Categories ----
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.25,
                  children: [
                    for (final c in store.categories)
                      CategoryTile(
                        emoji: c.emoji,
                        label: c.label,
                        onTap: () => _add(c),
                        onLongPress: () async {
                          HapticFeedback.mediumImpact();
                          if (await _confirm('Delete category ${c.emoji} ${c.label}?')) {
                            store.deleteCategory(c.key);
                          }
                        },
                      ),
                    CategoryTile(emoji: '＋', label: 'New', dashed: true, onTap: _newCategory),
                  ],
                ),

                // ---- This week ----
                const SizedBox(height: 22),
                const Text('This week', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (week.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('Nothing yet — your jar is full 🎉', style: TextStyle(color: Color(0xFF999999))),
                    ),
                  )
                else
                  for (final e in week)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: Text(store.categoryFor(e).emoji, style: const TextStyle(fontSize: 24)),
                          title: Text(store.categoryFor(e).label),
                          subtitle: Text(shortDateTime(e.date)),
                          trailing: Text(euro(e.amount),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          onLongPress: () async {
                            HapticFeedback.mediumImpact();
                            if (await _confirm('Delete ${euro(e.amount)}?')) store.deleteExpense(e.id);
                          },
                        ),
                      ),
                    ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text('Long-press an item or category to delete it',
                        style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
                  ),
                ),

                // ---- Backup ----
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: _backupStyle,
                        onPressed: _backup,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Back up'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: _backupStyle,
                        onPressed: _restore,
                        icon: const Icon(Icons.restore, size: 18),
                        label: const Text('Restore'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static final _backupStyle = OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    backgroundColor: AppColors.card,
    foregroundColor: AppColors.blue,
    side: const BorderSide(color: Color(0xFFE4DDD2)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
  );
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.dashed = false,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dashed ? Colors.transparent : AppColors.card,
      elevation: dashed ? 0 : 1,
      shadowColor: const Color(0x22000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: dashed ? const BorderSide(color: Color(0xFFC9C1B5), width: 2) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: 28, color: dashed ? const Color(0xFF888877) : null)),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: dashed ? const Color(0xFF888877) : const Color(0xFF444444)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The jar that empties as you spend. [fill] is 0..1.
class JarGraphic extends StatelessWidget {
  const JarGraphic({super.key, required this.fill, required this.color});
  final double fill;
  final Color color;

  static const double w = 90, h = 130, radius = 24;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(radius)),
            child: Container(
              color: Colors.white,
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                height: h * fill,
                width: w,
                color: color,
              ),
            ),
          ),
          const Positioned.fill(child: CustomPaint(painter: _JarOutline())),
        ],
      ),
    );
  }
}

class _JarOutline extends CustomPainter {
  const _JarOutline();

  @override
  void paint(Canvas canvas, Size size) {
    const s = 3.0; // stroke width
    const r = JarGraphic.radius;
    final w = size.width, h = size.height;
    final paint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s;
    final path = Path()
      ..moveTo(s / 2, 0)
      ..lineTo(s / 2, h - r)
      ..arcToPoint(Offset(r, h - s / 2), radius: const Radius.circular(r - s / 2), clockwise: false)
      ..lineTo(w - r, h - s / 2)
      ..arcToPoint(Offset(w - s / 2, h - r), radius: const Radius.circular(r - s / 2), clockwise: false)
      ..lineTo(w - s / 2, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
