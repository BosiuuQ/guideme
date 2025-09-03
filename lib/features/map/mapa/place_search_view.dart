import 'package:flutter/material.dart';
import 'map_logic_handler.dart';

class PlaceSearchSheet extends StatelessWidget {
  final dynamic currentLocation;
  const PlaceSearchSheet({super.key, this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Center(child: Text('Place search (placeholder)')),
    );
  }
}
