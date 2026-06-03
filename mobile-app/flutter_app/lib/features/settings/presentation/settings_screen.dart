import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import 'providers/settings_notifier.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    final current = ref.read(settingsNotifierProvider).apiBaseUrl;
    _urlCtrl = TextEditingController(text: current ?? '');
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  String? _validateUrl(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Must be a valid http(s) URL';
    }
    if (uri.host.isEmpty) return 'Host is required';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final value = _urlCtrl.text.trim();
    await ref
        .read(settingsNotifierProvider.notifier)
        .setApiBaseUrl(value.isEmpty ? null : value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ERPNext server',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _urlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'API base URL',
                    hintText: 'https://erp.example.com',
                    border: const OutlineInputBorder(),
                    helperText:
                        'Leave empty to use default: ${AppConfig.env.apiBaseUrl}',
                  ),
                  validator: _validateUrl,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
                const Divider(height: 40),
                Text('Current effective URL: ${AppConfig.apiBaseUrl}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
