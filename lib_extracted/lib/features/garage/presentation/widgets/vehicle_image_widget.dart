import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/core/constants/app_assets.dart';
import 'package:guide_me/features/garage/presentation/widgets/parallax_flow_delegate.dart';

class VehicleImageWidget extends StatelessWidget {
  VehicleImageWidget({super.key});

  final GlobalKey imageKey = GlobalKey();
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.pushNamed(AppRoutes.imageView, extra: AppAssets.exampleImg);
      },
      child: Card(
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Flow(
          delegate: ParallaxFlowDelegate(
              scrollable: Scrollable.of(context),
              listItemContext: context,
              backgroundImageKey: imageKey),
          children: [
            Image.asset(
              key: imageKey,
              AppAssets.exampleImg,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ],
        ),
      ),
    );
  }
}
