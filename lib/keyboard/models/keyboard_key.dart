enum KeyType {
  character,
  backspace,
  enter,
  shift,
  capsLock,
  space,
  tab,
  escape,
  modeSwitch,
  emoji,
  arrowUp,
  arrowDown,
  arrowLeft,
  arrowRight,
  function,
  modifier,
}

enum ShiftState { off, shiftOnce, capsLock }

enum KeyboardMode { letters, numbers, symbols, emojis }

class KeyData {
  final String label;
  final String? secondaryLabel;
  final String? value;
  final KeyType type;
  final double flex;
  final String? iconName;

  const KeyData({
    required this.label,
    this.secondaryLabel,
    this.value,
    this.type = KeyType.character,
    this.flex = 1.0,
    this.iconName,
  });

  String get currentValue => value ?? label;
}
