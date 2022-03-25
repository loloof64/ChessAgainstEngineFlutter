import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/dialog_buttons.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _editedEnginePath;
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
      _editedEnginePath = _prefs.getString('enginePath');
      _engineThinkingTimeMs = _prefs.getDouble('engineThinkingTime') ?? 1000.0;
    });
  }

  Future<void> _savePreferences() async {
    if (_editedEnginePath != null) {
      await _prefs.setString('enginePath', _editedEnginePath!);
    } else {
      await _prefs.remove('enginePath');
    }
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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: I18nText('settings.engine_path_label'),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () async {
                    final initialPath = _editedEnginePath;
                    FilePickerResult? result = await FilePicker.platform
                        .pickFiles(initialDirectory: initialPath);
                    if (result != null) {
                      setState(() {
                        _editedEnginePath = result.files.single.path;
                      });
                    }
                  },
                  child: I18nText(
                    'settings.select',
                  ),
                ),
              )
            ],
          ),
          Expanded(
            child: Text(
              _editedEnginePath ??
                  FlutterI18n.translate(context, 'settings.no_engine'),
            ),
          ),
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
