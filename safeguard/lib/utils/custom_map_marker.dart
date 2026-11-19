import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Helper to generate custom Google Maps markers with:
/// 1. A circular badge with a person icon and bottom pin pointer
/// 2. An always-visible floating name tag ("You", contact names) above the pin
class CustomMapMarker {
  static final Map<String, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> createPersonPin({
    required String label,
    required Color pinColor,
    bool isVictim = false,
  }) async {
    final cacheKey = '$label-${pinColor.value}-$isVictim';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // 1. Text styling and measurement
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22.0,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 2. Label Pill measurements
    const double hPadding = 14.0;
    const double vPadding = 6.0;
    final double pillWidth = math.max(textPainter.width + (hPadding * 2), 54.0);
    final double pillHeight = textPainter.height + (vPadding * 2);

    // 3. Pin Dimensions
    const double pinRadius = 30.0;
    const double pointerHeight = 16.0;
    const double innerCircleRadius = 22.5;
    const double spacing = 6.0;

    // 4. Overall Canvas Dimensions
    final double canvasWidth = math.max(pillWidth + 24.0, (pinRadius * 2) + 24.0);
    final double canvasHeight = pillHeight + spacing + (pinRadius * 2) + pointerHeight + 12.0;

    final double centerX = canvasWidth / 2;
    const double pillTop = 4.0;
    final double pillCenterY = pillTop + (pillHeight / 2);

    // 5. Draw Always-Visible Floating Name Tag (Pill)
    final pillRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, pillCenterY),
        width: pillWidth,
        height: pillHeight,
      ),
      Radius.circular(pillHeight / 2),
    );

    // Drop shadow under pill
    final pillShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawRRect(pillRRect.shift(const Offset(0, 2)), pillShadowPaint);

    // Pill background fill
    final pillBgPaint = Paint()
      ..color = isVictim ? const Color(0xFFC62828) : const Color(0xFF1565C0);
    canvas.drawRRect(pillRRect, pillBgPaint);

    // White border around pill
    final pillBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(pillRRect, pillBorderPaint);

    // Text painted centered in pill
    textPainter.paint(
      canvas,
      Offset(centerX - (textPainter.width / 2), pillCenterY - (textPainter.height / 2)),
    );

    // 6. Draw Pin Body (Circle + Pointer Tip)
    final double pinCenterY = pillTop + pillHeight + spacing + pinRadius;
    final double tipY = pinCenterY + pinRadius + pointerHeight;

    // Ground shadow under pin tip
    final groundShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX, tipY + 1), width: 20, height: 6),
      groundShadowPaint,
    );

    // Pin outline path (Circle top + bottom pointer)
    const double angle = math.pi / 4; // 45 degrees
    final double rightX = centerX + pinRadius * math.cos(angle);
    final double rightY = pinCenterY + pinRadius * math.sin(angle);

    final Path pinPath = Path()
      ..arcTo(
        Rect.fromCircle(center: Offset(centerX, pinCenterY), radius: pinRadius),
        angle,
        (2 * math.pi) - (2 * angle),
        false,
      )
      ..lineTo(centerX, tipY)
      ..lineTo(rightX, rightY)
      ..close();

    // Fill pin
    canvas.drawPath(pinPath, Paint()..color = pinColor);

    // White outer pin border
    final pinBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawPath(pinPath, pinBorderPaint);

    // 7. Inner White Circular Avatar Badge
    canvas.drawCircle(
      Offset(centerX, pinCenterY),
      innerCircleRadius,
      Paint()..color = Colors.white,
    );

    // 8. Person Icon Silhouette inside white circle
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset(centerX, pinCenterY), radius: innerCircleRadius)),
    );

    // Head
    canvas.drawCircle(
      Offset(centerX, pinCenterY - 6.5),
      7.5,
      Paint()..color = pinColor,
    );

    // Shoulders
    final shoulderPath = Path()
      ..addArc(
        Rect.fromCenter(
          center: Offset(centerX, pinCenterY + 16.0),
          width: 30.0,
          height: 24.0,
        ),
        math.pi,
        math.pi,
      );
    canvas.drawPath(shoulderPath, Paint()..color = pinColor);

    canvas.restore();

    // 9. Rasterize to PNG Bitmap
    final ui.Image image = await pictureRecorder.endRecording().toImage(
      canvasWidth.toInt(),
      canvasHeight.toInt(),
    );
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());

    _cache[cacheKey] = descriptor;
    return descriptor;
  }
}
