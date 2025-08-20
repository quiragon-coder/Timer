import 'package:flutter/material.dart';
import '../providers.dart';
import '../models/activity.dart';

class CreateActivityPage extends StatefulWidget {
  const CreateActivityPage({super.key});

  @override
  State<CreateActivityPage> createState() => _CreateActivityPageState();
}

class _CreateActivityPageState extends State<CreateActivityPage> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController(text: '🏷️');
  Color _color = Colors.indigo;
  int? _goalDay;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle activité')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Obligatoire' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emojiCtrl,
                decoration: const InputDecoration(labelText: 'Emoji'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Couleur:'),
                  const SizedBox(width: 8),
                  _ColorDot(color: Colors.indigo, selected: _color == Colors.indigo, onTap: () => setState(() => _color = Colors.indigo)),
                  _ColorDot(color: Colors.green, selected: _color == Colors.green, onTap: () => setState(() => _color = Colors.green)),
                  _ColorDot(color: Colors.pink, selected: _color == Colors.pink, onTap: () => setState(() => _color = Colors.pink)),
                  _ColorDot(color: Colors.orange, selected: _color == Colors.orange, onTap: () => setState(() => _color = Colors.orange)),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Objectif journalier (minutes, optionnel)'),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final n = int.tryParse(v);
                  setState(() => _goalDay = n);
                },
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _onSave,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Créer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    if (!_form.currentState!.validate()) return;
    final db = dbProvider.read(context);
    await db.createActivity(
      name: _nameCtrl.text.trim(),
      emoji: _emojiCtrl.text.trim().isEmpty ? '🏷️' : _emojiCtrl.text.trim(),
      color: _color,
      dailyGoalMinutes: _goalDay,
    );
    if (mounted) Navigator.of(context).pop();
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorDot({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? Colors.black : Colors.transparent, width: 2),
        ),
      ),
    );
  }
}

extension on ProviderBase {
  T read<T>(BuildContext context) => ProviderScope.containerOf(context, listen: false).read(this as dynamic);
}
