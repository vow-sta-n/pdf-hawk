import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdfhawk/keyboard/layouts/gboard_layout.dart';
import 'package:pdfhawk/keyboard/layouts/macbook_layout.dart';
import 'package:pdfhawk/keyboard/models/keyboard_key.dart';
import 'package:pdfhawk/keyboard/widgets/emoji_picker_view.dart';

class InlineKeyboard extends StatefulWidget {
  final ValueChanged<String>? onTextInput;
  final VoidCallback? onBackspace;
  final VoidCallback? onEnter;
  final ValueChanged<String>? onArrowKey;
  final VoidCallback? onTab;
  final VoidCallback? onEscape;
  final VoidCallback? onClose;
  final Color? activeColor;
  final bool isDark;
  final bool? forceLandscape;

  const InlineKeyboard({
    super.key,
    this.onTextInput,
    this.onBackspace,
    this.onEnter,
    this.onArrowKey,
    this.onTab,
    this.onEscape,
    this.onClose,
    this.activeColor,
    this.isDark = false,
    this.forceLandscape,
  });

  @override
  State<InlineKeyboard> createState() => _InlineKeyboardState();
}

class _InlineKeyboardState extends State<InlineKeyboard> {
  ShiftState _shiftState = ShiftState.off;
  KeyboardMode _keyboardMode = KeyboardMode.letters;

  void _handleKeyPress(KeyData keyData) {
    switch (keyData.type) {
      case KeyType.character:
      case KeyType.space:
        widget.onTextInput?.call(keyData.currentValue);
        if (_shiftState == ShiftState.shiftOnce) {
          setState(() {
            _shiftState = ShiftState.off;
          });
        }
        break;

      case KeyType.backspace:
        widget.onBackspace?.call();
        break;

      case KeyType.enter:
        widget.onEnter?.call();
        break;

      case KeyType.tab:
        widget.onTab?.call();
        break;

      case KeyType.escape:
        widget.onEscape?.call();
        break;

      case KeyType.shift:
        setState(() {
          if (_shiftState == ShiftState.off) {
            _shiftState = ShiftState.shiftOnce;
          } else if (_shiftState == ShiftState.shiftOnce) {
            _shiftState = ShiftState.capsLock;
          } else {
            _shiftState = ShiftState.off;
          }
        });
        break;

      case KeyType.capsLock:
        setState(() {
          _shiftState = _shiftState == ShiftState.capsLock
              ? ShiftState.off
              : ShiftState.capsLock;
        });
        break;

      case KeyType.modeSwitch:
        setState(() {
          if (keyData.value == 'numbers') {
            _keyboardMode = KeyboardMode.numbers;
          } else if (keyData.value == 'symbols') {
            _keyboardMode = KeyboardMode.symbols;
          } else {
            _keyboardMode = KeyboardMode.letters;
          }
        });
        break;

      case KeyType.emoji:
        setState(() {
          _keyboardMode = _keyboardMode == KeyboardMode.emojis
              ? KeyboardMode.letters
              : KeyboardMode.emojis;
        });
        break;

      case KeyType.arrowUp:
        widget.onArrowKey?.call('up');
        break;
      case KeyType.arrowDown:
        widget.onArrowKey?.call('down');
        break;
      case KeyType.arrowLeft:
        widget.onArrowKey?.call('left');
        break;
      case KeyType.arrowRight:
        widget.onArrowKey?.call('right');
        break;

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = widget.forceLandscape ??
        (mediaQuery.orientation == Orientation.landscape || mediaQuery.size.width >= 600);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF16151B).withValues(alpha: 0.96)
            : const Color(0xFFE5E7EB).withValues(alpha: 0.96),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: isLandscape ? 240.h : 220.h,
          child: _keyboardMode == KeyboardMode.emojis
              ? EmojiPickerView(
                  onEmojiSelected: (emoji) => widget.onTextInput?.call(emoji),
                  onBackspace: () => widget.onBackspace?.call(),
                  onClose: () => setState(() => _keyboardMode = KeyboardMode.letters),
                  isDark: widget.isDark,
                )
              : (isLandscape
                  ? MacbookLayout(
                      shiftState: _shiftState,
                      onKeyPressed: _handleKeyPress,
                      isDark: widget.isDark,
                      activeColor: widget.activeColor,
                    )
                  : GboardLayout(
                      shiftState: _shiftState,
                      keyboardMode: _keyboardMode,
                      onKeyPressed: _handleKeyPress,
                      isDark: widget.isDark,
                      activeColor: widget.activeColor,
                    )),
        ),
      ),
    );
  }
}
