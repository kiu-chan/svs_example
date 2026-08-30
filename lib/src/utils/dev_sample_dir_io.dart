import 'dart:io';

/// The repo's own `sample_data/` directory, if it exists — used only to
/// pre-fill the file picker's starting directory during local development.
/// Not part of the app's real functionality (nothing reads from it at
/// runtime otherwise).
String? devSampleDirPath() {
  final dir = Directory('sample_data');
  return dir.existsSync() ? dir.absolute.path : null;
}
