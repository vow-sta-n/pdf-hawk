import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class EmojiPickerView extends StatefulWidget {
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onBackspace;
  final VoidCallback onClose;
  final bool isDark;

  const EmojiPickerView({
    super.key,
    required this.onEmojiSelected,
    required this.onBackspace,
    required this.onClose,
    this.isDark = false,
  });

  @override
  State<EmojiPickerView> createState() => _EmojiPickerViewState();
}

class _EmojiPickerViewState extends State<EmojiPickerView> {
  int _selectedCategoryIndex = 0;

  static const List<Map<String, dynamic>> _emojiCategories = [
    {
      'title': 'Smileys',
      'icon': '😀',
      'emojis': [
        '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇',
        '🙂', '🙃', '😉', '😍', '🥰', '😘', '😋', '😛', '😜', '🤪',
        '😎', '🤩', '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁',
        '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡',
        '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥', '😓',
        '🤗', '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄',
      ]
    },
    {
      'title': 'Gestures',
      'icon': '👍',
      'emojis': [
        '👋', '🤚', '🖐️', '✋', '🖖', '👌', '🤏', '✌️', '🤞', '🤟',
        '🤘', '🤙', '👈', '👉', '👆', '🖕', '👇', '☝️', '👍', '👎',
        '✊', '👊', '🤛', '🤜', '👏', '🙌', '👐', '🤲', '🤝', '🙏',
        '✍️', '💅', '🤳', '💪', '🦾', '🦿', '🦵', '🦶', '👂', '👃',
      ]
    },
    {
      'title': 'Symbols',
      'icon': '❤️',
      'emojis': [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
        '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '☮️',
        '✝️', '☪️', '🕉️', '☸️', '✡️', '🔯', '☯️', '☦️', '🛐', '⛎',
        '♨️', '❌', '⭕', '🛑', '⛔', '🚫', '💯', '💢', '⚠️', '✅',
      ]
    },
    {
      'title': 'Office',
      'icon': '📝',
      'emojis': [
        '✏️', '✒️', '🖊️', '🖋️', '🖌️', '🖍️', '📝', '💼', '📁', '📂',
        '📅', '📆', '📇', '📈', '📉', '📊', '📋', '📌', '📍', '📎',
        '🖇️', '📏', '📐', '✂️', '🗃️', '🗄️', '🗑️', '🔒', '🔓', '🔑',
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    final activeCategory = _emojiCategories[_selectedCategoryIndex];
    final List<String> currentEmojis = List<String>.from(activeCategory['emojis']);

    return Column(
      children: [
        // Category Tabs Bar
        Container(
          height: 38.h,
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade200,
            border: Border(
              bottom: BorderSide(
                color: widget.isDark ? Colors.white12 : Colors.grey.shade300,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  size: 18.sp,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
                onPressed: widget.onClose,
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _emojiCategories.length,
                  itemBuilder: (context, idx) {
                    final isSel = idx == _selectedCategoryIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategoryIndex = idx),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                        margin: EdgeInsets.symmetric(horizontal: 2.w),
                        decoration: BoxDecoration(
                          color: isSel
                              ? (widget.isDark ? Colors.white24 : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Center(
                          child: Text(
                            _emojiCategories[idx]['icon'],
                            style: TextStyle(fontSize: 16.sp),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.backspace_outlined,
                  size: 18.sp,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
                onPressed: widget.onBackspace,
              ),
            ],
          ),
        ),

        // Emoji Grid
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(8.r),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 12 : 7,
              crossAxisSpacing: 6.w,
              mainAxisSpacing: 6.h,
            ),
            itemCount: currentEmojis.length,
            itemBuilder: (context, index) {
              final emoji = currentEmojis[index];
              return GestureDetector(
                onTap: () => widget.onEmojiSelected(emoji),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF2C2C2E) : Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: GoogleFonts.notoColorEmoji(fontSize: 22.sp),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
