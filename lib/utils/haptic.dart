import 'package:flutter/services.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

class Haptic {
  void light() {
    HapticFeedback.lightImpact();
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