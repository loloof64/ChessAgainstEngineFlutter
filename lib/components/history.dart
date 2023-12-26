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
import 'dart:io' show Platform;

class HistoryNavigationButton extends StatelessWidget {
  final double size;
  final IconData icon;
  final void Function() onClick;

  const HistoryNavigationButton({
    super.key,
    required this.icon,
    required this.size,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.5;
    final iconBackground = Theme.of(context).primaryColor;
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        iconSize: iconSize,
        onPressed: onClick,
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: iconBackground,
        ),
        icon: Icon(
          icon,
        ),
      ),
    );
  }
}

class ChessHistory extends StatelessWidget {
  final List<Widget> children;
  final ScrollController scrollController;

  final void Function() requestGotoFirst;
  final void Function() requestGotoPrevious;
  final void Function() requestGotoNext;
  final void Function() requestGotoLast;

  const ChessHistory({
    Key? key,
    required this.children,
    required this.scrollController,
    required this.requestGotoFirst,
    required this.requestGotoPrevious,
    required this.requestGotoNext,
    required this.requestGotoLast,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx2, constraints) {
      double commonSize = constraints.maxWidth * (Platform.isAndroid || Platform.isIOS ? 0.20 : 0.10);
      if (commonSize < 25) {
        commonSize = 25;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              HistoryNavigationButton(
                size: commonSize,
                icon: Icons.first_page,
                onClick: requestGotoFirst,
              ),
              HistoryNavigationButton(
                size: commonSize,
                icon: Icons.arrow_back,
                onClick: requestGotoPrevious,
              ),
              HistoryNavigationButton(
                size: commonSize,
                icon: Icons.arrow_forward,
                onClick: requestGotoNext,
              ),
              HistoryNavigationButton(
                size: commonSize,
                icon: Icons.last_page,
                onClick: requestGotoLast,
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
    });
  }
}
