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
  late SharedPreferences _prefs;

  @override
  void initState() {
    _initPreferences();
    super.initState();
  }

  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _editedEnginePath = _loadEnginePath();
    });
  }

  String? _loadEnginePath() {
    return _prefs.getString('enginePath');
  }

  Future<bool> _saveEnginePath(String path) async {
    return await _prefs.setString('enginePath', path);
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
                    final initialPath = _editedEnginePath ?? '';
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
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: DialogActionButton(
                  onPressed: () async {
                    if (_editedEnginePath != null) {
                      _saveEnginePath(_editedEnginePath!);
                      Navigator.of(context).pop(true);
                    } else {
                      Navigator.of(context).pop(false);
                    }
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
