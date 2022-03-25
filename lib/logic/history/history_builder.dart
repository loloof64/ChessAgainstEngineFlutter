/*
    Chess exercises organizer : load your chess exercises and train yourself against the device.
    Copyright (C) 2022  Laurent Bernabe <laurent.bernabe@gmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

import "package:chess/chess.dart" as chesslib;
import 'package:flutter/material.dart';

extension FanConverter on String {
  String toFan({required bool whiteMove}) {
    const piecesRefs = "NBRQK";
    String result = this;

    final thisAsIndexedArray = split('').asMap();
    var firstOccurenceIndex = -1;
    for (var index = 0; index < thisAsIndexedArray.length; index++) {
      final element = thisAsIndexedArray[index]!;
      if (piecesRefs.contains(element)) {
        firstOccurenceIndex = index;
        break;
      }
    }

    if (firstOccurenceIndex > -1) {
      final element = thisAsIndexedArray[firstOccurenceIndex];
      dynamic replacement;
      switch (element) {
        case 'N':
          replacement = whiteMove ? "\u2658" : "\u265e";
          break;
        case 'B':
          replacement = whiteMove ? "\u2657" : "\u265d";
          break;
        case 'R':
          replacement = whiteMove ? "\u2656" : "\u265c";
          break;
        case 'Q':
          replacement = whiteMove ? "\u2655" : "\u265b";
          break;
        case 'K':
          replacement = whiteMove ? "\u2654" : "\u265a";
          break;
        default:
          throw Exception("Unrecognized piece char $element into SAN $this");
      }

      final firstPart = substring(0, firstOccurenceIndex);
      final lastPart = substring(firstOccurenceIndex + 1);

      result = "$firstPart$replacement$lastPart";
    }

    return result;
  }
}

enum File { fileA, fileB, fileC, fileD, fileE, fileF, fileG, fileH }

enum Rank { rank_1, rank_2, rank_3, rank_4, rank_5, rank_6, rank_7, rank_8 }

class Cell {
  final File file;
  final Rank rank;

  const Cell({
    required this.file,
    required this.rank,
  });
  Cell.fromSquareIndex(int squareIndex)
      : this(
            file: File.values[squareIndex % 8],
            rank: Rank.values[squareIndex ~/ 8]);

  factory Cell.from(Cell other) {
    return Cell(file: other.file, rank: other.rank);
  }

  factory Cell.fromString(String squareStr) {
    final file = File.values[squareStr.codeUnitAt(0) - 'a'.codeUnitAt(0)];
    final rank = Rank.values[squareStr.codeUnitAt(1) - '1'.codeUnitAt(0)];

    return Cell(file: file, rank: rank);
  }

  @override
  bool operator ==(Object other) =>
      other is Cell &&
      other.runtimeType == runtimeType &&
      other.file == file &&
      other.rank == rank;

  @override
  int get hashCode => file.index + (100 * rank.index);

  @override
  String toString() {
    return "${String.fromCharCode('a'.codeUnitAt(0) + file.index)}"
        "${String.fromCharCode('1'.codeUnitAt(0) + rank.index)}";
  }
}

extension CellIndexConverter on int {
  int convertSquareIndexFromChessLib() {
    final file = this % 8;
    final rank = this ~/ 16;
    return file + 8 * (7 - rank);
  }
}

class Move {
  final Cell from;
  final Cell to;

  const Move({
    required this.from,
    required this.to,
  });

  factory Move.from(Move other) =>
      Move(from: Cell.from(other.from), to: Cell.from(other.to));

  @override
  bool operator ==(Object other) =>
      other is Move &&
      other.runtimeType == runtimeType &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => from.hashCode + (10000000000 * to.hashCode);
}

class HistoryNode {
  HistoryNode? next;
  late List<HistoryNode> variations;
  String caption;
  String? fen;
  Move? relatedMove;
  String? result;

  HistoryNode({
    required this.caption,
    this.fen,
    this.relatedMove,
  }) {
    variations = <HistoryNode>[];
  }

  factory HistoryNode.from(HistoryNode other) {
    var result = HistoryNode(
        caption: other.caption,
        fen: other.fen,
        relatedMove:
            other.relatedMove != null ? Move.from(other.relatedMove!) : null);
    result.next = other.next != null ? HistoryNode.from(other.next!) : null;
    result.variations = other.variations;
    result.result = other.result;

    return result;
  }

  /*
  Caption and fen fields are enough to identify a node.
  */
  @override
  bool operator ==(Object other) =>
      other is HistoryNode &&
      other.runtimeType == runtimeType &&
      other.caption == caption &&
      other.fen == fen;

  @override
  int get hashCode => fen.hashCode + (10000 * caption.hashCode);
}

Future<HistoryNode?> buildHistoryTreeFromPgnTree(
    dynamic singleGamePgnTree) async {
  return Future(() {
    final pgnMoves = singleGamePgnTree['moves'];
    final startPositionTag = singleGamePgnTree['tags']['FEN'];
    final startPosition = startPositionTag ?? chesslib.Chess.DEFAULT_POSITION;
    final boardState = chesslib.Chess.fromFEN(startPosition);
    final result = _recursivelyBuildHistoryTreeFromPgnTree(
        pgnNodes: pgnMoves, boardState: boardState);
    return result;
  });
}

HistoryNode _recursivelyBuildHistoryTreeFromPgnTree(
    {required dynamic pgnNodes, required chesslib.Chess boardState}) {
  final rootHistoryNode = HistoryNode(
      caption:
          '${pgnNodes[0]['moveNumber']}.${pgnNodes[0]['whiteTurn'] ? '' : '...'}');
  var currentHistoryNode = rootHistoryNode;
  for (var index = 0; index < pgnNodes.length; index++) {
    final currentPgnNode = pgnNodes[index];
    final isAResultNode = currentPgnNode.containsKey('result');
    if (isAResultNode) {
      currentHistoryNode.result = currentPgnNode['result'];
      continue;
    } else {
      final needToAddMoveNumber = currentPgnNode['whiteTurn'] && index > 0;
      if (needToAddMoveNumber) {
        final nextHistoryNode_ =
            HistoryNode(caption: '${currentPgnNode['moveNumber']}.');
        currentHistoryNode.next = nextHistoryNode_;
        currentHistoryNode = nextHistoryNode_;
      }

      final currentMoveSan = currentPgnNode['notation'] as String;

      var nextHistoryNode = HistoryNode(
          caption:
              currentMoveSan.toFan(whiteMove: currentPgnNode['whiteTurn']));
      final relatedMove =
          _getMoveFromSan(san: currentMoveSan, boardState: boardState);
      nextHistoryNode.relatedMove = relatedMove;
      if (currentPgnNode['variations'].isNotEmpty) {
        currentPgnNode['variations'].forEach((currentPgnNodeVariation) {
          var clonedBoardState = chesslib.Chess.fromFEN(boardState.fen);
          final leftParenthesisNode = HistoryNode(caption: '(');
          final variationNode = _recursivelyBuildHistoryTreeFromPgnTree(
              pgnNodes: currentPgnNodeVariation, boardState: clonedBoardState);
          final rightParenthesisNode = HistoryNode(caption: ')');

          var variationLastNode = variationNode;
          while (variationLastNode.next != null) {
            variationLastNode = variationLastNode.next!;
          }

          leftParenthesisNode.next = variationNode;
          variationLastNode.next = rightParenthesisNode;
          nextHistoryNode.variations.add(leftParenthesisNode);
        });
      }
      boardState.move(currentMoveSan);
      currentHistoryNode.next = nextHistoryNode;
      currentHistoryNode = nextHistoryNode;
    }
  }
  return rootHistoryNode;
}

List<Widget> recursivelyBuildWidgetsFromHistoryTree({
  required HistoryNode tree,
  HistoryNode? selectedHistoryNode,
  required double fontSize,
  required void Function({
    required Move historyMove,
    required HistoryNode? selectedHistoryNode,
  })
      onHistoryMoveRequested,
}) {
  final result = <Widget>[];

  HistoryNode? currentHistoryNode = tree;

  do {
    final backgroundColor = selectedHistoryNode == currentHistoryNode
        ? Colors.blueAccent
        : Colors.transparent;
    final textColor =
        selectedHistoryNode == currentHistoryNode ? Colors.white : Colors.black;
    final textComponent = Text(
      currentHistoryNode!.caption,
      style: TextStyle(
        fontSize: fontSize,
        fontFamily: 'FreeSerif',
        backgroundColor: backgroundColor,
        color: textColor,
      ),
    );
    final relatedMove = currentHistoryNode.relatedMove != null
        ? Move.from(currentHistoryNode.relatedMove!)
        : null;
    final nodeToRegister = HistoryNode.from(currentHistoryNode);

    result.add(
      currentHistoryNode.fen == null
          ? textComponent
          : TextButton(
              onPressed: () {
                onHistoryMoveRequested(
                  historyMove: relatedMove!,
                  selectedHistoryNode: nodeToRegister,
                );
              },
              child: textComponent),
    );

    if (currentHistoryNode.result != null) {
      result.add(Text(currentHistoryNode.result!));
    }

    if (currentHistoryNode.variations.isNotEmpty) {
      for (var currentVariation in currentHistoryNode.variations) {
        final currentVariationResult = recursivelyBuildWidgetsFromHistoryTree(
          tree: currentVariation,
          fontSize: fontSize,
          onHistoryMoveRequested: onHistoryMoveRequested,
        );
        result.addAll(currentVariationResult);
      }
    }

    currentHistoryNode = currentHistoryNode.next != null
        ? HistoryNode.from(currentHistoryNode.next!)
        : null;
  } while (currentHistoryNode != null);

  return result;
}

Move _getMoveFromSan(
    {required String san, required chesslib.Chess boardState}) {
  final boardStateClone = chesslib.Chess.fromFEN(boardState.fen);
  boardStateClone.move(san);
  final boardLogicMove = boardStateClone.undo_move()!;
  final moveFrom = Cell.fromSquareIndex(boardLogicMove.from);
  final moveTo = Cell.fromSquareIndex(boardLogicMove.to);

  return Move(from: moveFrom, to: moveTo);
}

int getHistoryNodeIndex({
  required HistoryNode node,
  required HistoryNode rootNode,
}) {
  int result = 0;
  HistoryNode? currentNode = rootNode;

  do {
    if (currentNode == null) break;
    if (currentNode == node) break;
    if (currentNode.variations.isNotEmpty) {
      //TODO process variations
      // increment result with variation length recursively or break with found index
    }
    currentNode = currentNode.next;
    result++;
  } while (currentNode != null);

  return result;
}
