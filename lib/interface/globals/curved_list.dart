/*
 * SnapTag - Privacy-First GPS & Weather Camera App
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 */

import 'package:flutter/material.dart';

class CurvedCarousel extends StatefulWidget {
  final int itemCount;
  final double curveScale;
  final int initialIndex;
  final bool scaleMiddleItem;
  final bool tiltItemWithCurve;
  final double middleItemScaleRatio;
  final PageController pageController;
  final void Function(int index)? onChangeEnd;
  final void Function(int index)? onChangeStart;
  final Widget Function(BuildContext, int, int) itemBuilder;

  const CurvedCarousel({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    this.curveScale = 4.5,
    this.scaleMiddleItem = true,
    this.middleItemScaleRatio = 1.2,
    this.tiltItemWithCurve = true,
    this.onChangeStart,
    this.onChangeEnd,
    required this.pageController,
    this.initialIndex = 0,
  });

  @override
  State<CurvedCarousel> createState() => _CurvedCarouselState();
}

class _CurvedCarouselState extends State<CurvedCarousel> {
  int _currentIndex = 0;

  @override
  void initState() {
    _currentIndex = widget.initialIndex;
    setCurrentIndex(_currentIndex);
    super.initState();
  }

  void setCurrentIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.pageController.hasClients) {
        widget.pageController.jumpToPage(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: widget.pageController,
      itemCount: widget.itemCount,
      onPageChanged: (index) {
        widget.onChangeStart?.call(index);
        setState(() => _currentIndex = index);
        widget.onChangeEnd?.call(index);
      },
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: widget.pageController,
          builder: (context, child) {
            double value = 0;
            if (widget.pageController.position.haveDimensions) {
              value = widget.pageController.page! - index;
            } else {
              value = _currentIndex - index.toDouble();
            }
            final double yOffset = -(value * value) * widget.curveScale;
            final double angle = widget.tiltItemWithCurve ? value * 0.21 : 0;
            double scale = 1;
            if (widget.scaleMiddleItem) {
              scale = 1.1 - (value.abs() * 0.1);
              if (index == _currentIndex) {
                scale = widget.middleItemScaleRatio;
              }
            }
            return Transform.translate(
              offset: Offset(0, yOffset),
              child: Transform.rotate(
                angle: angle,
                child: Transform.scale(scale: scale, child: child),
              ),
            );
          },
          child: widget.itemBuilder(context, index, _currentIndex),
        );
      },
    );
  }
}
