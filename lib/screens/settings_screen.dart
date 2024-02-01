import 'package:chess_against_engine/logic/managers/stockfish_manager.dart';
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
  SkillLevel? _skillLevel;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initPreferences();
    _tryToSetupSkillLevelIfNotDoneYet();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _tryToSetupSkillLevelIfNotDoneYet() {
    if (_skillLevel != null) return;
    if (StockfishManager().skillLevel == null) return;

    final currentSkillLevel = StockfishManager().skillLevel!;
    setState(() {
      _skillLevel = currentSkillLevel;
    });
  }

  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _engineThinkingTimeMs = _prefs.getDouble('engineThinkingTime') ?? 1000.0;
    });
    final minLevel = _prefs.getInt('engineSkillLevelMin');
    final maxLevel = _prefs.getInt('engineSkillLevelMax');
    final currentLevel = _prefs.getInt('engineSkillLevelCurrent');
    final defaultLevel = _prefs.getInt('engineSkillLevelDefault');

    if (minLevel != null &&
        maxLevel != null &&
        currentLevel != null &&
        defaultLevel != null) {
      setState(() {
        _skillLevel = SkillLevel(
          defaultLevel: defaultLevel,
          currentLevel: currentLevel,
          minLevel: minLevel,
          maxLevel: maxLevel,
        );
      });
    }
  }

  Future<void> _savePreferences() async {
    await _prefs.setDouble('engineThinkingTime', _engineThinkingTimeMs);
    if (_skillLevel != null) {
      await _prefs.setInt('engineSkillLevelMin', _skillLevel!.minLevel);
      await _prefs.setInt('engineSkillLevelMax', _skillLevel!.maxLevel);
      await _prefs.setInt('engineSkillLevelCurrent', _skillLevel!.currentLevel);
      await _prefs.setInt('engineSkillLevelDefault', _skillLevel!.defaultLevel);
    }
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
          if (_skillLevel != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: I18nText('settings.engine_skill_level'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Slider(
                    value: _skillLevel!.currentLevel.toDouble(),
                    onChanged: (newValue) {
                      StockfishManager().setSkillLevel(level: newValue.toInt());
                      setState(() {
                        _skillLevel = _skillLevel!.copyWith(
                          currentLevel: newValue.toInt(),
                        );
                      });
                    },
                    divisions:
                        (_skillLevel!.maxLevel - _skillLevel!.minLevel) + 1,
                    min: _skillLevel!.minLevel.toDouble(),
                    max: _skillLevel!.maxLevel.toDouble(),
                  ),
                ),
                Text(_skillLevel!.currentLevel.toString())
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
