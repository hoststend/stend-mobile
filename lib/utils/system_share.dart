import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

void systemShare(BuildContext context, String url) {
  final screenSize = MediaQuery.of(context).size;
  final rect = Rect.fromCenter(
    center: Offset(screenSize.width / 2, screenSize.height / 2),
    width: 100,
    height: 100,
  );

  Share.share(url, sharePositionOrigin: rect);
}