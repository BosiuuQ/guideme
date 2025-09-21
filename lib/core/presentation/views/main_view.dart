import 'package:flutter/material.dart';
import 'package:guide_me/core/constants/app_assets.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/core/presentation/widgets/app_drawer_widget.dart';
import 'package:guide_me/features/map/mapa/main_map_widget.dart';

class MainView extends StatelessWidget {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: AppDrawerWidget(),
      appBar: AppBar(
        centerTitle: false,
        leadingWidth: 0,
        title: Image.asset(
          alignment: AlignmentDirectional.centerStart,
          AppAssets.logoImg,
          width: 100.0,
          height: 100.0,
        ),
      ),
      body: SafeArea(bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: MainMapWidget()
        ),
      ),
    );
  }
}
