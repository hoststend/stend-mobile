bool checkURL(String url) {
  try {
    Uri.parse(url);
    return true;
  } catch (e) {
    return false;
  }
}