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

import 'package:flutter/material.dart';
import '../logic/history/history_builder.dart';

class ChessHistory extends StatelessWidget {
  final HistoryNode? historyTree;
  final List<Widget> children;
  final ScrollController scrollController;

  final void Function() requestGotoFirst;
  final void Function() requestGotoPrevious;
  final void Function() requestGotoNext;
  final void Function() requestGotoLast;

  const ChessHistory({
    Key? key,
    required this.historyTree,
    required this.children,
    required this.scrollController,
    required this.requestGotoFirst,
    required this.requestGotoPrevious,
    required this.requestGotoNext,
    required this.requestGotoLast,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: requestGotoFirst,
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
              ),
              child: const Icon(Icons.first_page),
            ),
            ElevatedButton(
              onPressed: requestGotoPrevious,
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
              ),
              child: const Icon(Icons.arrow_back),
            ),
            ElevatedButton(
              onPressed: requestGotoNext,
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
              ),
              child: const Icon(Icons.arrow_forward),
            ),
            ElevatedButton(
              onPressed: requestGotoLast,
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
              ),
              child: const Icon(Icons.last_page),
            ),
          ],
        ),
        Expanded(
          child: Container(
            color: Colors.amber[300],
            child: SingleChildScrollView(
              controller: scrollController,
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                children: children,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
