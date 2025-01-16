import 'package:chess_against_engine/screens/new_game_position_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:simple_chess_board/simple_chess_board.dart';
import 'package:editable_chess_board/editable_chess_board.dart';
import '../components/dialog_buttons.dart';

class NewGameParameters {
  final String startPositionFen;
  final bool playerHasWhite;

  NewGameParameters({
    required this.startPositionFen,
    required this.playerHasWhite,
  });
}

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
  late bool _playerHasWhite;
  late BoardColor _orientation;

  @override
  void initState() {
    _positionController = PositionController(widget.initialFen);
    _positionFen = _positionController.position;
    _playerHasWhite = _positionFen.split(' ')[1] == 'w';
    _orientation = _playerHasWhite ? BoardColor.white : BoardColor.black;
    super.initState();
  }

  Future<void> _showEditPositionPage() async {
    final result = await Navigator.of(context).pushNamed(
      '/new_game_editor',
      arguments:
          NewGamePositionEditorScreenArguments(_positionController.position),
    ) as String?;
    if (result != null) {
      setState(() {
        _positionController.position = result;
        _positionFen = _positionController.position;
      });
    }
  }

  void _onTurnChanged(bool newTurnValue) {
    setState(() {
      _playerHasWhite = newTurnValue;
      _orientation = _playerHasWhite ? BoardColor.white : BoardColor.black;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final chessBoard = SimpleChessBoard(
      lastMoveToHighlight: null,
      fen: _positionFen,
      blackSideAtBottom: _orientation == BoardColor.black,
      onPromotionCommited: ({required moveDone, required pieceType}) {},
      whitePlayerType: PlayerType.computer,
      blackPlayerType: PlayerType.computer,
      onMove: ({required move}) {},
      onPromote: () async => null,
      chessBoardColors: ChessBoardColors(),
      onTap: ({required String cellCoordinate}) {},
      cellHighlights: const <String, Color>{},
    );

    final editPosition = ElevatedButton(
      onPressed: () {
        _showEditPositionPage();
      },
      child: I18nText(
        'new_game.edit_position',
      ),
    );

    final pageActionButtons = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(2.0),
          child: DialogActionButton(
            onPressed: () async {
              Navigator.of(context).pop(
                NewGameParameters(
                  startPositionFen: _positionController.position,
                  playerHasWhite: _playerHasWhite,
                ),
              );
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
    );

    final sideChoiceComponent = Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        I18nText('new_game.position_editor.label_player_side'),
        ListTile(
          title: Text(
            FlutterI18n.translate(
              context,
              'new_game.position_editor.label_white_player',
            ),
          ),
          leading: Radio<bool>(
            groupValue: _playerHasWhite,
            value: true,
            onChanged: (value) {
              _onTurnChanged(value ?? true);
            },
          ),
        ),
        ListTile(
          title: Text(
            FlutterI18n.translate(
              context,
              'new_game.position_editor.label_black_player',
            ),
          ),
          leading: Radio<bool>(
            groupValue: _playerHasWhite,
            value: false,
            onChanged: (value) {
              _onTurnChanged(value ?? false);
            },
          ),
        ),
      ],
    );

    final mainZone = isLandscape
        ? Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              chessBoard,
              Flexible(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      sideChoiceComponent,
                      editPosition,
                      pageActionButtons,
                    ],
                  ),
                ),
              )
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              chessBoard,
              sideChoiceComponent,
              editPosition,
              Expanded(child: pageActionButtons),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: I18nText('new_game.title'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: mainZone,
        ),
      ),
    );
  }
}
