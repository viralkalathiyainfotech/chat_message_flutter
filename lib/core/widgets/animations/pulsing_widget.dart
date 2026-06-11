import 'package:flutter/material.dart';

class PulsingWidget extends StatefulWidget {
  final Widget child;
  final double scaleBegin;
  final double scaleEnd;
  final Duration duration;

  const PulsingWidget({
    Key? key,
    required this.child,
    this.scaleBegin = 0.95,
    this.scaleEnd = 1.05,
    this.duration = const Duration(milliseconds: 1000),
  }) : super(key: key);

  @override
  State<PulsingWidget> createState() => _PulsingWidgetState();
}

class _PulsingWidgetState extends State<PulsingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _scaleAnimation = Tween<double>(begin: widget.scaleBegin, end: widget.scaleEnd).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}
