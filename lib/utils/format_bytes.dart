String formatBytes(int bytes) {
  const sizes = ["octets", "Ko", "Mo", "Go", "To"];

  int i = 0;
  double numBytes = bytes.toDouble();

  while (numBytes >= 1000 && i < sizes.length - 1) {
    numBytes /= 1000;
    i++;
  }

  return '${numBytes.toStringAsFixed(2)} ${sizes[i]}';
}