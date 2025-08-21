import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class CreateActivityPage extends ConsumerStatefulWidget {
  const CreateActivityPage({super.key});

  @override
  ConsumerState<CreateActivityPage> createState() => _CreateActivityPageState();
}

class _CreateActivityPageState extends ConsumerState<CreateActivityPage> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController(text: '⏱️');
  Color _color = const Color(0xFF00BCD4);

  int? _daily, _weekly, _monthly, _yearly;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = ref.read(dbProvider);

    await db.createActivity(
      name: _nameCtrl.text.trim(),
      emoji: _emojiCtrl.text.trim().isEmpty ? '⏱️' : _emojiCtrl.text.trim(),
      color: _color,
      dailyGoalMinutes: _daily,
      weeklyGoalMinutes: _weekly,
      monthlyGoalMinutes: _monthly,
      yearlyGoalMinutes: _yearly,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer une activité')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      hintText: 'ex. Yoga, Lecture…',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 64,
                  child: TextFormField(
                    controller: _emojiCtrl,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: 'Emoji'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Couleur :'),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () async {
                    final c = await showDialog<Color>(
                      context: context,
                      builder: (ctx) => _ColorPickerDialog(color: _color),
                    );
                    if (c != null) setState(() => _color = c);
                  },
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Objectifs (min)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _GoalRow(label: 'Jour', onChanged: (v) => _daily = v),
            _GoalRow(label: 'Semaine', onChanged: (v) => _weekly = v),
            _GoalRow(label: 'Mois', onChanged: (v) => _monthly = v),
            _GoalRow(label: 'Année', onChanged: (v) => _yearly = v),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Enregistrement…' : 'Créer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalRow extends StatefulWidget {
  final String label;
  final void Function(int?) onChanged;
  const _GoalRow({required this.label, required this.onChanged});

  @override
  State<_GoalRow> createState() => _GoalRowState();
}

class _GoalRowState extends State<_GoalRow> {
  final ctrl = TextEditingController();
  @override
  void dispose() { ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(widget.label)),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, hintText: '0', suffixText: 'min'),
              onChanged: (v) => widget.onChanged(int.tryParse(v)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color color;
  const _ColorPickerDialog({required this.color});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _c;
  @override
  void initState() { super.initState(); _c = widget.color; }

  static const palette = <Color>[
    Color(0xFFE91E63), Color(0xFFF44336), Color(0xFFFF9800), Color(0xFFFFC107),
    Color(0xFF4CAF50), Color(0xFF00BCD4), Color(0xFF2196F3), Color(0xFF3F51B5),
    Color(0xFF9C27B0), Color(0xFF795548), Color(0xFF607D8B), Color(0xFF009688),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choisir une couleur'),
      content: SizedBox(
        width: 280,
        child: Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            for (final c in palette)
              GestureDetector(
                onTap: () => setState(() => _c = c),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: _c == c ? const Icon(Icons.check, color: Colors.white) : null,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, _c), child: const Text('OK')),
      ],
    );
  }
}
