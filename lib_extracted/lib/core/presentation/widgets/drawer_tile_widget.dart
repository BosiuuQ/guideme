import 'package:flutter/material.dart';
import 'package:guide_me/core/constants/app_colors.dart';

class DrawerTileWidget extends StatelessWidget {
  const DrawerTileWidget({
    Key? key,
    required this.title,
    required this.icon,
    required this.onClick,
  }) : super(key: key);

  final String title;
  final dynamic icon; // może być String (asset) LUB IconData
  final VoidCallback onClick;

  bool _isEmoji(String text) {
    return !text.contains('.') && text.runes.length <= 2;
  }

  @override
  Widget build(BuildContext context) {
    late final Widget iconWidget;

    if (icon is String && _isEmoji(icon)) {
      iconWidget = Text(
        icon,
        style: const TextStyle(fontSize: 22, color: Colors.white),
      );
    } else if (icon is String) {
      iconWidget = Image.asset(
        icon,
        color: AppColors.lightBlue,
        fit: BoxFit.contain,
        width: 22.0,
        height: 22.0,
      );
    } else if (icon is IconData) {
      iconWidget = Icon(
        icon as IconData,
        size: 22.0,
        color: AppColors.lightBlue,
      );
    } else {
      iconWidget = const Icon(Icons.help_outline, color: Colors.red);
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
      onTap: onClick,
      leading: iconWidget,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
