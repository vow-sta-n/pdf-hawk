import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdfhawk/keyboard/models/keyboard_key.dart';
import 'package:pdfhawk/keyboard/widgets/key_button.dart';

class MacbookLayout extends StatelessWidget {
  final ShiftState shiftState;
  final ValueChanged<KeyData> onKeyPressed;
  final bool isDark;
  final Color? activeColor;

  const MacbookLayout({
    super.key,
    required this.shiftState,
    required this.onKeyPressed,
    this.isDark = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isUpper = shiftState != ShiftState.off;

    return Container(
      padding: EdgeInsets.all(6.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E20) : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 0: Function Row (Esc, F1-F12, Touch ID)
          _buildRow(_buildFunctionRow()),
          SizedBox(height: 1.5.h),

          // Row 1: Number Row (`~`, 1-0, -, =, delete)
          _buildRow(_buildNumberRow(isUpper)),
          SizedBox(height: 1.5.h),

          // Row 2: QWERTY Row (Tab, Q-P, [, ], \)
          _buildRow(_buildQwertyRow(isUpper)),
          SizedBox(height: 1.5.h),

          // Row 3: Home Row (Caps Lock, A-L, ;, ', Return)
          _buildRow(_buildHomeRow(isUpper)),
          SizedBox(height: 1.5.h),

          // Row 4: Shift Row (Shift, Z-M, ,, ., /, Shift)
          _buildRow(_buildShiftRow(isUpper)),
          SizedBox(height: 1.5.h),

          // Row 5: Modifier Row (fn/emoji, ctrl, opt, cmd, space, cmd, opt, arrows)
          _buildRow(_buildBottomModifierRow()),
        ],
      ),
    );
  }

  Widget _buildRow(List<KeyData> keys) {
    return Row(
      children: keys.map((keyData) {
        final isShiftActive = (keyData.type == KeyType.shift || keyData.type == KeyType.capsLock) &&
            shiftState != ShiftState.off;

        return KeyButton(
          keyData: keyData,
          onTap: () => onKeyPressed(keyData),
          isDark: isDark,
          activeColor: activeColor,
          isSpecialKey: keyData.type != KeyType.character,
          isActive: isShiftActive,
          customHeight: keyData.type == KeyType.function ? 30.h : 38.h,
        );
      }).toList(),
    );
  }

  List<KeyData> _buildFunctionRow() {
    return [
      const KeyData(label: 'esc', type: KeyType.escape, flex: 1.1),
      const KeyData(label: 'F1', secondaryLabel: '🔉', type: KeyType.function, flex: 0.95),
      const KeyData(label: 'F2', secondaryLabel: '🔊', type: KeyType.function, flex: 0.95),
      const KeyData(label: 'F3', secondaryLabel: '㗊', type: KeyType.function, flex: 0.95),
      const KeyData(label: 'F4', secondaryLabel: '🔍', type: KeyType.function, flex: 0.95),
      const KeyData(label: 'F5', secondaryLabel: '🎙️', type: KeyType.function, flex: 0.95),
      const KeyData(label: 'F6', secondaryLabel: '🌙', type: KeyType.function, flex: 0.95),
      const KeyData(label: 'F7', secondaryLabel: '⏮️', type: KeyType.function, flex: 0.95),
      const KeyData(label: 'F8', secondaryLabel: '⏯️', type: KeyType.function, flex: 0.95),
      const KeyData(label: 'F9', secondaryLabel: '⏭️', type: KeyType.function, flex: 0.95),
      const KeyData(label: 'F10', secondaryLabel: '🔇', type: KeyType.function, flex: 0.95),
      const KeyData(label: 'F11', secondaryLabel: '🔉', type: KeyType.function, flex: 0.95),
      const KeyData(label: 'F12', secondaryLabel: '🔊', type: KeyType.function, flex: 0.95),
      const KeyData(label: '⏏', type: KeyType.function, flex: 1.1),
    ];
  }

  List<KeyData> _buildNumberRow(bool isUpper) {
    final pairs = [
      ['`', '~'],
      ['1', '!'],
      ['2', '@'],
      ['3', '#'],
      ['4', '\$'],
      ['5', '%'],
      ['6', '^'],
      ['7', '&'],
      ['8', '*'],
      ['9', '('],
      ['0', ')'],
      ['-', '_'],
      ['=', '+'],
    ];

    List<KeyData> row = pairs.map((p) {
      return KeyData(
        label: isUpper ? p[1] : p[0],
        secondaryLabel: isUpper ? p[0] : p[1],
        value: isUpper ? p[1] : p[0],
      );
    }).toList();

    row.add(const KeyData(
      label: 'delete ⌫',
      type: KeyType.backspace,
      flex: 1.5,
    ));

    return row;
  }

  List<KeyData> _buildQwertyRow(bool isUpper) {
    List<KeyData> row = [
      const KeyData(label: 'tab ⇥', type: KeyType.tab, flex: 1.4),
    ];

    final chars = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];
    row.addAll(chars.map((c) {
      final label = isUpper ? c.toUpperCase() : c;
      return KeyData(label: label, value: label);
    }));

    final p1 = isUpper ? '{' : '[';
    final p2 = isUpper ? '}' : ']';
    final p3 = isUpper ? '|' : '\\';

    row.add(KeyData(label: p1, secondaryLabel: isUpper ? '[' : '{', value: p1));
    row.add(KeyData(label: p2, secondaryLabel: isUpper ? ']' : '}', value: p2));
    row.add(KeyData(label: p3, secondaryLabel: isUpper ? '\\' : '|', value: p3, flex: 1.1));

    return row;
  }

  List<KeyData> _buildHomeRow(bool isUpper) {
    List<KeyData> row = [
      const KeyData(label: 'caps lock ⇪', type: KeyType.capsLock, flex: 1.75),
    ];

    final chars = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];
    row.addAll(chars.map((c) {
      final label = isUpper ? c.toUpperCase() : c;
      return KeyData(label: label, value: label);
    }));

    final p1 = isUpper ? ':' : ';';
    final p2 = isUpper ? '"' : "'";

    row.add(KeyData(label: p1, secondaryLabel: isUpper ? ';' : ':', value: p1));
    row.add(KeyData(label: p2, secondaryLabel: isUpper ? "'" : '"', value: p2));
    row.add(const KeyData(label: 'return ↩', type: KeyType.enter, flex: 1.75));

    return row;
  }

  List<KeyData> _buildShiftRow(bool isUpper) {
    List<KeyData> row = [
      const KeyData(label: 'shift ⇧', type: KeyType.shift, flex: 2.2),
    ];

    final chars = ['z', 'x', 'c', 'v', 'b', 'n', 'm'];
    row.addAll(chars.map((c) {
      final label = isUpper ? c.toUpperCase() : c;
      return KeyData(label: label, value: label);
    }));

    final p1 = isUpper ? '<' : ',';
    final p2 = isUpper ? '>' : '.';
    final p3 = isUpper ? '?' : '/';

    row.add(KeyData(label: p1, secondaryLabel: isUpper ? ',' : '<', value: p1));
    row.add(KeyData(label: p2, secondaryLabel: isUpper ? '.' : '>', value: p2));
    row.add(KeyData(label: p3, secondaryLabel: isUpper ? '/' : '?', value: p3));
    row.add(const KeyData(label: 'shift ⇧', type: KeyType.shift, flex: 2.2));

    return row;
  }

  List<KeyData> _buildBottomModifierRow() {
    return [
      const KeyData(label: 'fn 😊', type: KeyType.emoji, flex: 1.1),
      const KeyData(label: 'control ⌃', type: KeyType.modifier, flex: 1.1),
      const KeyData(label: 'option ⌥', type: KeyType.modifier, flex: 1.1),
      const KeyData(label: 'command ⌘', type: KeyType.modifier, flex: 1.3),
      const KeyData(label: 'space', type: KeyType.space, value: ' ', flex: 4.8),
      const KeyData(label: 'command ⌘', type: KeyType.modifier, flex: 1.3),
      const KeyData(label: 'option ⌥', type: KeyType.modifier, flex: 1.1),
      const KeyData(label: '◀', type: KeyType.arrowLeft, flex: 0.9),
      const KeyData(label: '▲', type: KeyType.arrowUp, flex: 0.9),
      const KeyData(label: '▼', type: KeyType.arrowDown, flex: 0.9),
      const KeyData(label: '▶', type: KeyType.arrowRight, flex: 0.9),
    ];
  }
}
