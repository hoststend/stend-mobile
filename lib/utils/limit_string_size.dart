String limitStringSize(String string, int size) {
  if (string.length > size) {
    return '${string.substring(0, size)}...';
  }
  return string;
}