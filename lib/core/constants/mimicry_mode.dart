enum MimicryMode {
  auto,
  manual,
}

extension MimicryModeExtension on MimicryMode {
  String get name {
    switch (this) {
      case MimicryMode.auto:
        return 'Auto (Recommended)';
      case MimicryMode.manual:
        return 'Manual Selection';
    }
  }

  String get description {
    switch (this) {
      case MimicryMode.auto:
        return 'Automatically selects best mimicry based on your location and network tests';
      case MimicryMode.manual:
        return 'You choose which traffic disguise to use';
    }
  }
}
