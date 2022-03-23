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

class DialogActionButton extends StatelessWidget {
  final void Function() onPressed;
  final Widget textContent;
  final Color backgroundColor;
  final Color textColor;
  const DialogActionButton({
    Key? key,
    required this.onPressed,
    required this.textContent,
    required this.backgroundColor,
    required this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: ElevatedButton(
        onPressed: onPressed,
        child: textContent,
        style: ElevatedButton.styleFrom(
          primary: backgroundColor,
          textStyle: TextStyle(
            color: textColor,
          ),
          elevation: 5,
        ),
      ),
    );
  }
}
