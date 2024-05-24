import 'package:flutter/services.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

class Haptic {
  void micro() {
    HapticFeedback.lightImpact();
  }

  void light() {
    Haptics.vibrate(HapticsType.light);
  }

  void medium() {
    Haptics.vibrate(HapticsType.medium);
  }

  void heavy() {
    Haptics.vibrate(HapticsType.heavy);
  }

  void success() {
    Haptics.vibrate(HapticsType.success);
  }

  void warning() {
    Haptics.vibrate(HapticsType.warning);
  }

  void error() {
    Haptics.vibrate(HapticsType.error);
  }
}