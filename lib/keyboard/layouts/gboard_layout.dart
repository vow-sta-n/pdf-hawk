import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdfhawk/keyboard/models/keyboard_key.dart';
import 'package:pdfhawk/keyboard/widgets/key_button.dart';

class GboardLayout extends StatelessWidget {
  final ShiftState shiftState;
  final KeyboardMode keyboardMode;
  final ValueChanged<KeyData> onKeyPressed;
  final bool isDark;
  final Color? activeColor;

  const GboardLayout({
    super.key,
    required this.shiftState,
    required this.keyboardMode,
    required this.onKeyPressed,
    this.isDark = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    List<List<KeyData>> keyRows;

    switch (keyboardMode) {
      case KeyboardMode.numbers:
        keyRows = _buildNumbersLayout();
        break;
      case KeyboardMode.symbols:
        keyRows = _buildSymbolsLayout();
        break;
      case KeyboardMode.letters:
      default:
        keyRows = _buildLettersLayout();
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: keyRows.map((row) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 1.5.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((keyData) {
              final isShiftActive = (keyData.type == KeyType.shift || keyData.type == KeyType.capsLock) &&
                  shiftState != ShiftState.off;

              return KeyButton(
                keyData: keyData,
                onTap: () => onKeyPressed(keyData),
                isDark: isDark,
                activeColor: activeColor,
                isSpecialKey: keyData.type != KeyType.character,
                isActive: isShiftActive,
                customHeight: 44.h,
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  List<List<KeyData>> _buildLettersLayout() {
    final isUpper = shiftState != ShiftState.off;

    List<String> r1 = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];
    List<String> r2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];
    List<String> r3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm'];

    return [
      r1.map((char) {
        final label = isUpper ? char.toUpperCase() : char;
        return KeyData(label: label, value: label);
      }).toList(),
      r2.map((char) {
        final label = isUpper ? char.toUpperCase() : char;
        return KeyData(label: label, value: label);
      }).toList(),
      [
        const KeyData(
          label: 'Shift',
          type: KeyType.shift,
          flex: 1.4,
        ),
        ...r3.map((char) {
          final label = isUpper ? char.toUpperCase() : char;
          return KeyData(label: label, value: label);
        }),
        const KeyData(
          label: 'Backspace',
          type: KeyType.backspace,
          flex: 1.4,
        ),
      ],
      [
        const KeyData(
          label: '?123',
          type: KeyType.modeSwitch,
          value: 'numbers',
          flex: 1.4,
        ),
        const KeyData(
          label: '😊',
          type: KeyType.emoji,
          flex: 1.2,
        ),
        const KeyData(
          label: 'space',
          type: KeyType.space,
          value: ' ',
          flex: 4.5,
        ),
        const KeyData(
          label: '.',
          value: '.',
          flex: 1.0,
        ),
        const KeyData(
          label: 'return',
          type: KeyType.enter,
          flex: 1.5,
        ),
      ],
    ];
  }

  List<List<KeyData>> _buildNumbersLayout() {
    return [
      ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']
          .map((c) => KeyData(label: c))
          .toList(),
      ['@', '#', '\$', '%', '&', '-', '+', '(', ')']
          .map((c) => KeyData(label: c))
          .toList(),
      [
        const KeyData(
          label: '=\\<',
          type: KeyType.modeSwitch,
          value: 'symbols',
          flex: 1.4,
        ),
        ...['*', '"', "'", ':', ';', '!', '?'].map((c) => KeyData(label: c)),
        const KeyData(
          label: 'Backspace',
          type: KeyType.backspace,
          flex: 1.4,
        ),
      ],
      [
        const KeyData(
          label: 'ABC',
          type: KeyType.modeSwitch,
          value: 'letters',
          flex: 1.4,
        ),
        const KeyData(
          label: '😊',
          type: KeyType.emoji,
          flex: 1.2,
        ),
        const KeyData(
          label: ',',
          value: ',',
          flex: 1.0,
        ),
        const KeyData(
          label: 'space',
          type: KeyType.space,
          value: ' ',
          flex: 3.5,
        ),
        const KeyData(
          label: '.',
          value: '.',
          flex: 1.0,
        ),
        const KeyData(
          label: 'return',
          type: KeyType.enter,
          flex: 1.5,
        ),
      ],
    ];
  }

  List<List<KeyData>> _buildSymbolsLayout() {
    return [
      ['~', '`', '|', '•', '√', 'π', '÷', '×', '¶', '∆']
          .map((c) => KeyData(label: c))
          .toList(),
      ['£', '¥', '€', '¢', '^', '°', '=', '{', '}']
          .map((c) => KeyData(label: c))
          .toList(),
      [
        const KeyData(
          label: '?123',
          type: KeyType.modeSwitch,
          value: 'numbers',
          flex: 1.4,
        ),
        ...['\\', '%', '©', '®', '™', '[', ']'].map((c) => KeyData(label: c)),
        const KeyData(
          label: 'Backspace',
          type: KeyType.backspace,
          flex: 1.4,
        ),
      ],
      [
        const KeyData(
          label: 'ABC',
          type: KeyType.modeSwitch,
          value: 'letters',
          flex: 1.4,
        ),
        const KeyData(
          label: '😊',
          type: KeyType.emoji,
          flex: 1.2,
        ),
        const KeyData(
          label: '<',
          value: '<',
          flex: 1.0,
        ),
        const KeyData(
          label: 'space',
          type: KeyType.space,
          value: ' ',
          flex: 3.5,
        ),
        const KeyData(
          label: '>',
          value: '>',
          flex: 1.0,
        ),
        const KeyData(
          label: 'return',
          type: KeyType.enter,
          flex: 1.5,
        ),
      ],
    ];
  }
}
