import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/dialog_buttons.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _engineThinkingTimeMs = 1000.0;
  late SharedPreferences _prefs;

  @override
  void initState() {
    _initPreferences();
    super.initState();
  }

  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _engineThinkingTimeMs = _prefs.getDouble('engineThinkingTime') ?? 1000.0;
    });
  }

  Future<void> _savePreferences() async {
    await _prefs.setDouble('engineThinkingTime', _engineThinkingTimeMs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: I18nText('settings.title'),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: I18nText('settings.engine_thinking_time_label'),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Slider(
                  value: _engineThinkingTimeMs,
                  onChanged: (newValue) {
                    setState(() {
                      _engineThinkingTimeMs = newValue;
                    });
                  },
                  divisions: null,
                  min: 500,
                  max: 5000,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: I18nText(
                  'settings.engine_thinking_time_value',
                  translationParams: {
                    'time': (_engineThinkingTimeMs / 1000.0).toStringAsFixed(2),
                  },
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: DialogActionButton(
                  onPressed: () async {
                    _savePreferences();
                    Navigator.of(context).pop(true);
                  },
                  textContent: I18nText('buttons.ok'),
                  backgroundColor: Colors.greenAccent,
                  textColor: Colors.white,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: DialogActionButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  textContent: I18nText('buttons.cancel'),
                  backgroundColor: Colors.redAccent,
                  textColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
