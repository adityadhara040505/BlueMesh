import 'package:flutter/material.dart';

/// App color palette for BlueMesh.
class AppColors {
  AppColors._();

  // Primary Branding
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF64B5F6);
  static const Color accentCyan = Color(0xFF00E5FF);

  // Dark Theme Backgrounds (Default)
  static const Color backgroundDark = Color(0xFF10141D);
  static const Color surfaceDark = Color(0xFF171D2A);
  static const Color surfaceContainerDark = Color(0xFF21293B);
  static const Color surfaceContainerHighDark = Color(0xFF2B364C);

  // Light Theme Backgrounds
  static const Color backgroundLight = Color(0xFFF6F8FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceContainerLight = Color(0xFFE9EEF4);

  // Chat Bubbles
  static const Color outgoingBubbleDark = Color(0xFF1565C0);
  static const Color incomingBubbleDark = Color(0xFF232D3F);
  static const Color outgoingBubbleLight = Color(0xFFBBDEFB);
  static const Color incomingBubbleLight = Color(0xFFFFFFFF);

  // Status Colors
  static const Color onlineGreen = Color(0xFF00E676);
  static const Color offlineGrey = Color(0xFF78909C);
  static const Color deliveredGrey = Color(0xFFB0BEC5);
  static const Color readTickBlue = Color(0xFF40C4FF);
  static const Color warningAmber = Color(0xFFFFB300);
  static const Color errorRed = Color(0xFFFF5252);

  // Text Colors
  static const Color textPrimaryDark = Color(0xFFECEFF1);
  static const Color textSecondaryDark = Color(0xFF90A4AE);
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF757575);
}
