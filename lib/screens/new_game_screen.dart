import 'package:chess_against_engine/screens/new_game_position_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:simple_chess_board/simple_chess_board.dart';
import 'package:editable_chess_board/editable_chess_board.dart';
import '../components/dialog_buttons.dart';

class NewGameScreenArguments {
  final String initialFen;

  NewGameScreenArguments(this.initialFen);
}

class NewGameScreen extends StatefulWidget {
  final String initialFen;
  const NewGameScreen({
    Key? key,
    required this.initialFen,
  }) : super(key: key);

  @override
  NewGameScreenState createState() => NewGameScreenState();
}

class NewGameScreenState extends State<NewGameScreen> {
  late PositionController _positionController;
  late String _positionFen;
  BoardColor _orientation = BoardColor.white;

  @override
  void initState() {
    _positionController = PositionController(widget.initialFen);
    _positionFen = _positionController.currentPosition;
    super.initState();
  }

  Future<void> _showEditPositionPage() async {
    final result = await Navigator.of(context).pushNamed(
      '/new_game_editor',
      arguments: NewGamePositionEditorScreenArguments(
          _positionController.currentPosition),
    ) as String?;
    if (result != null) {
      setState(() {
        _positionController.value = result;
        _positionFen = _positionController.currentPosition;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: I18nText('new_game.title'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            width: 400,
            child: Column(children: <Widget>[
              SimpleChessBoard(
                lastMoveToHighlight: null,
                fen: _positionFen,
                orientation: _orientation,
                whitePlayerType: PlayerType.computer,
                blackPlayerType: PlayerType.computer,
                onMove: ({required move}) {},
                onPromote: () async => null,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () {
                    _showEditPositionPage();
                  },
                  child: I18nText(
                    'new_game.edit_position',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: DialogActionButton(
                        onPressed: () async {
                          Navigator.of(context)
                              .pop(_positionController.currentPosition);
                        },
                        textContent: I18nText('buttons.ok'),
                        backgroundColor: Colors.greenAccent,
                        textColor: Colors.white,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: DialogActionButton(
                        onPressed: () {
                          Navigator.of(context).pop(null);
                        },
                        textContent: I18nText('buttons.cancel'),
                        backgroundColor: Colors.redAccent,
                        textColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            ]),
          ),
        ),
      ),
    );
  }
}
