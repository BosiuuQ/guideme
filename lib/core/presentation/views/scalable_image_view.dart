import 'package:flutter/material.dart';

class ScalableImageView extends StatelessWidget {
  final String image;
  const ScalableImageView({
    super.key,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
          child: InteractiveViewer(
        panEnabled: true,
        minScale: 1,
        maxScale: 4,
        child: Image.asset(
          image,
          gaplessPlayback: true,
          fit: BoxFit.contain,
          height: double.infinity,
          width: double.infinity,
          alignment: Alignment.center,
        ),
      )),
    );
  }
}
