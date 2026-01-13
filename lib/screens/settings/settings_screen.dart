import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _dateFormat = 'dd/mm/yyyy';
  double _fontSize = 1.0;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Preferencias de Usuario',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold, color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Modo Oscuro'),
                  secondary: const Icon(Icons.dark_mode),
                  value: _darkMode,
                  onChanged: (val) {
                    setState(() => _darkMode = val);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.text_fields),
                  title: const Text('Tamaño de Fuente'),
                  subtitle: Slider(
                    value: _fontSize,
                    min: 0.8,
                    max: 1.4,
                    divisions: 6,
                    label: '${(_fontSize * 100).round()}%',
                    onChanged: (val) {
                      setState(() => _fontSize = val);
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Formato de Fecha'),
                  trailing: DropdownButton<String>(
                    value: _dateFormat,
                    underline: Container(),
                    items: const [
                      DropdownMenuItem(
                          value: 'dd/mm/yyyy', child: Text('dd/mm/yyyy')),
                      DropdownMenuItem(
                          value: 'mm/dd/yyyy', child: Text('mm/dd/yyyy')),
                      DropdownMenuItem(
                          value: 'yyyy/mm/dd', child: Text('yyyy/mm/dd')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _dateFormat = val);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
