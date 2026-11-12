import 'package:flutter/material.dart';

class ShapeInfo {
  const ShapeInfo(this.name, this.color);
  final String name;
  final Color color;
}

const shapeInfo = <String, ShapeInfo>{
  'BLUE_CIRCLE': ShapeInfo('blue circle', Color(0xFF4285F4)),
  'RED_SQUARE': ShapeInfo('red square', Color(0xFFEA4335)),
  'YELLOW_DIAMOND': ShapeInfo('yellow diamond', Color(0xFFFBBC05)),
  'GREEN_PILL': ShapeInfo('green pill', Color(0xFF34A853)),
  'GREEN_CIRCLE': ShapeInfo('green circle', Color(0xFF34A853)),
};

class ShapeMarker extends StatelessWidget {
  const ShapeMarker(this.shape, {super.key, this.size = 20});
  final String shape;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = (shapeInfo[shape] ?? shapeInfo['BLUE_CIRCLE']!).color;
    switch (shape) {
      case 'RED_SQUARE':
        return _box(color, size, size, size * 0.28);
      case 'YELLOW_DIAMOND':
        return Transform.rotate(
          angle: 0.785398,
          child: _box(color, size * 0.78, size * 0.78, size * 0.12),
        );
      case 'GREEN_PILL':
        return _box(color, size * 1.7, size * 0.8, size);
      default:
        return _box(color, size, size, size);
    }
  }

  Widget _box(Color c, double w, double h, double r) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(r)),
  );
}
