import 'package:flutter/material.dart';
import 'package:guide_me/features/garage/presentation/widgets/vehicle_image_widget.dart';

class VehicleDetailsImagesSliderWidget extends StatefulWidget {
  const VehicleDetailsImagesSliderWidget({super.key});

  @override
  State<VehicleDetailsImagesSliderWidget> createState() =>
      _VehicleDetailsImagesSliderWidgetState();
}

class _VehicleDetailsImagesSliderWidgetState
    extends State<VehicleDetailsImagesSliderWidget> {
  late PageController _pageController;
  late int _pageNumber;
  @override
  void initState() {
    _pageController = PageController(viewportFraction: 0.9);
    _pageNumber = _pageController.initialPage;
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            AspectRatio(
              aspectRatio: 3 / 2.2,
              child: PageView.builder(
                controller: _pageController,
                itemCount: 5,
                onPageChanged: (pageNumber) {
                  setState(() {
                    _pageNumber = pageNumber;
                  });
                },
                itemBuilder: (BuildContext pageContext, int index) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0).copyWith(
                        left: index == 0 ? 0 : 8.0,
                        right: index == 4 ? 0 : 8.0),
                    child: VehicleImageWidget(),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 12.0,
          right: 30.0,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 4.0,
            ),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(
                24.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 20.0,
                ),
                SizedBox(
                  width: 4.0,
                ),
                Text("${_pageNumber + 1}/5"),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
