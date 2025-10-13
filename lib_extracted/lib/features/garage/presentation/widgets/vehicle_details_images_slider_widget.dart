import 'package:flutter/material.dart';
import 'package:guide_me/features/garage/domain/entity/vehicle.dart';

class VehicleDetailsImagesSliderWidget extends StatelessWidget {
  final Vehicle vehicle;
  const VehicleDetailsImagesSliderWidget({Key? key, required this.vehicle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Prosta implementacja slidera – wyświetla pojedyncze zdjęcie,
    // jeśli jest więcej niż jedno, możesz dodać PageView lub Carousel.
    if (vehicle.imageUrls.isEmpty) {
      return Container(
        height: 200,
        color: Colors.grey,
        child: Center(child: Text("Brak zdjęć")),
      );
    }
    return Container(
      height: 200,
      child: PageView.builder(
        itemCount: vehicle.imageUrls.length,
        itemBuilder: (context, index) {
          return Image.network(
            vehicle.imageUrls[index],
            fit: BoxFit.cover,
          );
        },
      ),
    );
  }
}
