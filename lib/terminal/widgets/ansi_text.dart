import 'package:flutter/material.dart';

/// Widget that renders text with ANSI color codes.
class AnsiText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;
  final bool selectable;

  const AnsiText(
    this.text, {
    super.key,
    this.baseStyle,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final spans = _parseAnsi(text, baseStyle);

    if (selectable) {
      return SelectableText.rich(TextSpan(children: spans));
    }

    return Text.rich(TextSpan(children: spans));
  }

  List<TextSpan> _parseAnsi(String text, TextStyle? baseStyle) {
    final List<TextSpan> spans = [];

    // Remove control sequences like bracketed paste mode [?2004h/l, cursor positioning, etc.
    text = text.replaceAll(RegExp(r'\x1B\[[0-9;?]*[hl]'), '');
    text = text.replaceAll(RegExp(r'\x1B\[[0-9;]*[ABCDEFGJKST]'), '');
    text = text.replaceAll(RegExp(r'\x1B\]0;[^\x07]*\x07'), ''); // Window title
    text = text.replaceAll(
      RegExp(r'\x1B\[\?[0-9]+[hl]'),
      '',
    ); // Private mode set/reset

    final RegExp ansiPattern = RegExp(r'\x1B\[([0-9;]*)m');

    int lastIndex = 0;
    Color? currentColor;
    Color? currentBgColor;
    bool isBold = false;
    bool isUnderline = false;

    for (final match in ansiPattern.allMatches(text)) {
      // Add text before the ANSI code
      if (match.start > lastIndex) {
        final textSegment = text.substring(lastIndex, match.start);
        spans.add(
          TextSpan(
            text: textSegment,
            style: (baseStyle ?? const TextStyle()).copyWith(
              color: currentColor,
              backgroundColor: currentBgColor,
              fontWeight: isBold ? FontWeight.bold : null,
              decoration: isUnderline ? TextDecoration.underline : null,
            ),
          ),
        );
      }

      // Parse ANSI code
      final codes = match.group(1)?.split(';') ?? [];
      for (final code in codes) {
        final codeNum = int.tryParse(code);
        if (codeNum == null) continue;

        switch (codeNum) {
          case 0: // Reset
            currentColor = null;
            currentBgColor = null;
            isBold = false;
            isUnderline = false;
            break;
          case 1: // Bold
            isBold = true;
            break;
          case 4: // Underline
            isUnderline = true;
            break;
          case 22: // Normal intensity
            isBold = false;
            break;
          case 24: // Not underlined
            isUnderline = false;
            break;
          // Foreground colors
          case 30:
            currentColor = Colors.black;
            break;
          case 31:
            currentColor = Colors.red;
            break;
          case 32:
            currentColor = Colors.green;
            break;
          case 33:
            currentColor = Colors.yellow;
            break;
          case 34:
            currentColor = Colors.blue;
            break;
          case 35:
            currentColor = Colors.purple;
            break;
          case 36:
            currentColor = Colors.cyan;
            break;
          case 37:
            currentColor = Colors.white;
            break;
          case 39:
            currentColor = null;
            break; // Default
          // Bright foreground colors
          case 90:
            currentColor = Colors.grey[600];
            break;
          case 91:
            currentColor = Colors.red[300];
            break;
          case 92:
            currentColor = Colors.green[300];
            break;
          case 93:
            currentColor = Colors.yellow[300];
            break;
          case 94:
            currentColor = Colors.blue[300];
            break;
          case 95:
            currentColor = Colors.purple[300];
            break;
          case 96:
            currentColor = Colors.cyan[300];
            break;
          case 97:
            currentColor = Colors.white;
            break;
          // Background colors
          case 40:
            currentBgColor = Colors.black;
            break;
          case 41:
            currentBgColor = Colors.red;
            break;
          case 42:
            currentBgColor = Colors.green;
            break;
          case 43:
            currentBgColor = Colors.yellow;
            break;
          case 44:
            currentBgColor = Colors.blue;
            break;
          case 45:
            currentBgColor = Colors.purple;
            break;
          case 46:
            currentBgColor = Colors.cyan;
            break;
          case 47:
            currentBgColor = Colors.white;
            break;
          case 49:
            currentBgColor = null;
            break; // Default
        }
      }

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      final textSegment = text.substring(lastIndex);
      spans.add(
        TextSpan(
          text: textSegment,
          style: (baseStyle ?? const TextStyle()).copyWith(
            color: currentColor,
            backgroundColor: currentBgColor,
            fontWeight: isBold ? FontWeight.bold : null,
            decoration: isUnderline ? TextDecoration.underline : null,
          ),
        ),
      );
    }

    return spans;
  }
}
