import 'package:flutter/material.dart';

class FavouriteWidget extends StatefulWidget {
  const FavouriteWidget(
      {super.key, required this.isFavourite, required this.onFavouriteChanged});
  final bool isFavourite;
  final ValueChanged<bool> onFavouriteChanged;

  @override
  createState() => _FavouriteWidgetState();
}

class _FavouriteWidgetState extends State<FavouriteWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;
  bool _isLiked = false;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: widget.isFavourite ? 1.0 : 0.0,
      duration: Duration(milliseconds: 300),
    );

    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.3)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: 1.3, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 50),
    ]).animate(_controller);

    _colorAnimation =
        ColorTween(begin: Colors.grey, end: Colors.red).animate(_controller);

    _isLiked = widget.isFavourite;
    if (_isLiked) {
      _controller.value = 1.0;
    } else {
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_isLiked) {
      _controller.reverse();
    } else {
      _controller.forward();
    }

    setState(() {
      _isLiked = !_isLiked;
    });

    widget.onFavouriteChanged.call(_isLiked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              Icons.favorite,
              color: _colorAnimation.value,
            ),
          );
        },
      ),
    );
  }
}
