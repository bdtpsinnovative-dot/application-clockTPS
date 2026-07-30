import 'package:flutter/material.dart';

/// Visual tokens for the project/task experience.
///
/// The palette intentionally uses one brand accent. Green and red are reserved
/// for semantic success and risk states so the interface stays calm.
abstract final class ProjectDetailStyle {
  static const canvas = Color(0xFFF6F7F9);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1B1D22);
  static const secondary = Color(0xFF626873);
  static const muted = Color(0xFF9298A2);
  static const line = Color(0xFFE5E7EB);
  static const soft = Color(0xFFF1F3F5);
  // Match the work experience used throughout the app.
  static const accent = Color(0xFF2563EB);
  static const accentSoft = Color(0xFFEFF6FF);
  static const header = Color(0xFF2563EB);
  static const headerMuted = Color(0xFFDBEAFE);
  static const headerTrack = Color(0xFF60A5FA);
  static const headerProgress = Color(0xFFFFFFFF);

  // Saturated semantic colors stay unmistakable on light surfaces.
  static const success = Color(0xFF00B750);
  static const successSoft = Color(0xFFECFDF5);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFEF2F2);

  static const cardRadius = 16.0;
  static const controlRadius = 12.0;
  static const pillRadius = 24.0;
  static const tapTarget = 44.0;
  static const compactControlHeight = 32.0;
  static const actionHeight = 44.0;
  static const iconTiny = 13.0;
  static const iconSmall = 16.0;
  static const iconMedium = 18.0;

  static const cardShadow = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}

