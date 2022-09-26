import 'package:chess_against_engine/screens/new_game_position_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:simple_chess_board/simple_chess_board.dart';
import 'package:editable_chess_board/editable_chess_board.dart';
import '../components/dialog_buttons.dart';

class NewGameScreen extends StatefulWidget {
  const NewGameScreen({Key? key}) : super(key: key);

  @override
  _NewGameScreenState createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  PositionController _positionController = PositionController(
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
  late String _positionFen;
  BoardColor _orientation = BoardColor.white;

  @override
  void initState() {
    _positionFen = _positionController.currentPosition;
    super.initState();
  }

  void _showEditPositionPage() {
    Navigator.of(context).pushNamed(
      '/new_game_editor',
      arguments: NewGamePositionEditorScreenArguments(
          _positionController.currentPosition),
    );
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
                          //TODO set new game
                          Navigator.of(context).pop(true);
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
                          Navigator.of(context).pop(false);
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
