import 'package:flutter/material.dart';
import 'package:editable_chess_board/editable_chess_board.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:chess/chess.dart' as chess;
import '../components/dialog_buttons.dart';

class NewGamePositionEditorScreenArguments {
  final String initialFen;

  NewGamePositionEditorScreenArguments(this.initialFen);
}

class NewGamePositionEditorScreen extends StatefulWidget {
  final String initialFen;
  const NewGamePositionEditorScreen({
    super.key,
    required this.initialFen,
  });

  @override
  State<NewGamePositionEditorScreen> createState() =>
      _NewGamePositionEditorScreenState();
}

class _NewGamePositionEditorScreenState
    extends State<NewGamePositionEditorScreen> {
  late PositionController _positionController;

  @override
  void initState() {
    _positionController = PositionController(widget.initialFen);
    super.initState();
  }

  void _checkPositionAndSendIfValid() {
    final position = _positionController.currentPosition;
    final isNotEmpty = position.split(' ')[0] != '8/8/8/8/8/8/8/8';
    final isValid = chess.Chess.validate_fen(position)['valid'] == true;
    if (isNotEmpty && isValid) {
      Navigator.of(context).pop(position);
    } else {
      final snackBar = SnackBar(
        content: I18nText(
          'new_game.position_editor.illegal_position_error',
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: I18nText('new_game.title'),
      ),
      body: SizedBox(
        height: 600.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: EditableChessBoard(
                boardSize: 400.0,
                labels: Labels(
                  playerTurnLabel: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_player_turn',
                  ),
                  whitePlayerLabel: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_white_player',
                  ),
                  blackPlayerLabel: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_black_player',
                  ),
                  availableCastlesLabel: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_available_castles',
                  ),
                  whiteOOLabel: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_white_OO',
                  ),
                  whiteOOOLabel: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_white_OOO',
                  ),
                  blackOOLabel: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_black_OO',
                  ),
                  blackOOOLabel: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_black_OOO',
                  ),
                  enPassantLabel: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_en_passant',
                  ),
                  drawHalfMovesCountLabel: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_draw_half_moves_count',
                  ),
                  moveNumberLabel: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_move_number',
                  ),
                  submitFieldLabel: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_submit_field',
                  ),
                  currentPositionLabel: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_current_position',
                  ),
                  copyFenLabel: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_copy_fen',
                  ),
                  pasteFenLabel: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_paste_fen',
                  ),
                  resetPosition: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_reset_position',
                  ),
                  standardPosition: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_standard_position',
                  ),
                  erasePosition: FlutterI18n.translate(
                    context,
                    'new_game.position_editor.label_clear_position',
                  ),
                ),
                controller: _positionController,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DialogActionButton(
                    onPressed: _checkPositionAndSendIfValid,
                    textContent: I18nText('buttons.ok'),
                    backgroundColor: Colors.greenAccent,
                    textColor: Colors.white,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DialogActionButton(
                    onPressed: () {
                      Navigator.of(context).pop();
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
      ),
    );
  }
}
