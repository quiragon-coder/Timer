import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

class CreateActivityPage extends ConsumerStatefulWidget {
  const CreateActivityPage({super.key});

  @override
  ConsumerState<CreateActivityPage> createState() => _CreateActivityPageState();
}

class _CreateActivityPageState extends ConsumerState<CreateActivityPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _dailyCtrl = TextEditingController();
  final _weeklyCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  final _yearlyCtrl = TextEditingController();

  // Valeurs par défaut
  String _emoji = '📚';
  Color _color = Colors.blue;

  // Emojis courants (ligne rapide)
  final List<String> _quickEmojis = const [
    '📚','🏃','🧘','🎹','🧠','📝','🧹','💻','☕','🎮','📖','🚴','🏋️','🎨','🎧','🛏️'
  ];

  // Emojis étendus (grille du bottom sheet)
  final List<String> _moreEmojis = const [
    '📚','📖','📝','🧠','💡','🎹','🎸','🥁','🎻','🎨','🧵','🪡','🧩','♟️',
    '🏃','🚴','🏊','🏋️','🤸','🧗','⛹️','🤾','🧘','⚽','🏀','🎾','🏐','⚾',
    '💻','🖥️','⌨️','🖱️','🧪','🔬','🔭','📊','📈','📉',
    '☕','🍵','🍎','🥕','🥗','🍳',
    '🛏️','🧹','🧺','🧼',
    '📅','⏰','🧭','📌',
    '🌱','🌳','🌿','🌸',
    '🎧','🎮','🎲','📷'
  ];

  // Couleurs rapides
  final List<Color> _quickColors = const [
    Colors.blue, Colors.green, Colors.orange, Colors.red,
    Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dailyCtrl.dispose();
    _weeklyCtrl.dispose();
    _monthlyCtrl.dispose();
    _yearlyCtrl.dispose();
    super.dispose();
  }

  int? _toIntOrNull(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    return v == null || v < 0 ? null : v;
  }

  Future<void> _pickEmojiBottomSheet() async {
    String temp = _emoji;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final tc = TextEditingController(text: temp);
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16,
            top: 8,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Saisir/coller n'importe quel emoji
              TextField(
                controller: tc,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28),
                decoration: const InputDecoration(
                  labelText: 'Saisir un emoji',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  if (v.runes.isEmpty) return;
                  temp = String.fromCharCode(v.runes.first);
                },
              ),
              const SizedBox(height: 12),
              // Grille d’emojis
              SizedBox(
                height: 280,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: _moreEmojis.length,
                  itemBuilder: (_, i) {
                    final e = _moreEmojis[i];
                    final sel = e == temp;
                    return InkWell(
                      onTap: () {
                        temp = e;
                        Navigator.of(ctx).pop();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: sel
                              ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          )
                              : null,
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.3),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    setState(() => _emoji = temp);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle activité')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Emoji + Nom
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Emoji pick rapide
                Column(
                  children: [
                    InkWell(
                      onTap: _pickEmojiBottomSheet,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 56, height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child:
                        Text(_emoji, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _pickEmojiBottomSheet,
                      child: const Text('Plus d\'emojis…'),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Ligne de chips emojis rapides
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickEmojis.map((e) {
                final sel = e == _emoji;
                return ChoiceChip(
                  label: Text(e, style: const TextStyle(fontSize: 18)),
                  selected: sel,
                  onSelected: (_) => setState(() => _emoji = e),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Couleurs rapides
            Text('Couleur', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _quickColors.map((c) {
                final sel = c.value == _color.value;
                return InkWell(
                  onTap: () => setState(() => _color = c),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: sel
                          ? Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                        width: 2,
                      )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            Text('Objectifs (minutes)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dailyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jour',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _weeklyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Semaine',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _monthlyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Mois',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _yearlyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ann\u00E9e',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Cr\u00E9er'),
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;

                // Appel corrigé : paramètres nommés attendus par DatabaseService.createActivity(...)
                await db.createActivity(
                  name: _nameCtrl.text.trim(),
                  emoji: _emoji,
                  color: _color,
                  dailyGoalMinutes: _toIntOrNull(_dailyCtrl.text),
                  weeklyGoalMinutes: _toIntOrNull(_weeklyCtrl.text),
                  monthlyGoalMinutes: _toIntOrNull(_monthlyCtrl.text),
                  yearlyGoalMinutes: _toIntOrNull(_yearlyCtrl.text),
                );

                if (mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
