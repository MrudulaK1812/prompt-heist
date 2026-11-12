import 'package:flutter/material.dart';

Color scoreColor(int s) {
  if (s >= 100) return const Color(0xFF34A853);
  if (s >= 80) return const Color(0xFF4285F4);
  if (s >= 40) return const Color(0xFFFBBC05);
  return const Color(0xFFEA4335);
}
