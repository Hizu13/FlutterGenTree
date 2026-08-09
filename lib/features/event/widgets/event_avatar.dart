import 'package:flutter/material.dart';
import '../../../config/app_color.dart';

class EventAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;

  const EventAvatar({super.key, this.imageUrl, this.radius = 26});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceWarm,
      backgroundImage: hasImage ? _getImageProvider(imageUrl!) : null,
      child: !hasImage
          ? Icon(
              Icons.calendar_month_rounded,
              color: AppColors.primary,
              size: radius * 0.9,
            )
          : null,
    );
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    return AssetImage(path);
  }
}
