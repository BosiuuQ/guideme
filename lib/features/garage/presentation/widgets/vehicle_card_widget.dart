import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/core/presentation/widgets/card_widget.dart';
import 'package:guide_me/core/presentation/widgets/no_image_widget.dart';
import 'package:guide_me/features/garage/domain/entity/vehicle.dart';

class VehicleCardWidget extends StatelessWidget {
  const VehicleCardWidget({
    super.key,
    required this.vehicle,
    required this.onLongPress,
    required this.onTap,
    required this.isChecked,
  });

  final Vehicle vehicle;
  final VoidCallback onLongPress;
  final VoidCallback onTap;
  final bool isChecked;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12.0),
      child: CardWidget(
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 4 / 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (vehicle.imageUrls.isEmpty)
                    SizedBox(
                      // height: 150.0,
                      width: double.infinity,
                      child: NoImageWidget(
                        iconSize: 40.0,
                      ),
                    ),
                  if (vehicle.imageUrls.isNotEmpty)
                    Expanded(
                      child: Ink(
                        //height: 150,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: CachedNetworkImageProvider(
                              vehicle.imageUrls.first,
                            ),
                            fit: BoxFit.cover,
                          ),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      vehicle.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                      ),
                    ),
                  )
                ],
              ),
            ),
            if (isChecked)
              Positioned.fill(
                child: Container(
                  // height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    color: AppColors.blue.withAlpha(120),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
