/// A curated whole-slide-image test file from OpenSlide's public Aperio test
/// dataset (https://openslide.cs.cmu.edu/download/openslide-testdata/),
/// offered in-app so users can try the viewer without sourcing their own
/// .svs file.
class SampleSlide {
  final String fileName;
  final String title;
  final String description;
  final Uri url;
  final int approxSizeBytes;

  const SampleSlide({
    required this.fileName,
    required this.title,
    required this.description,
    required this.url,
    required this.approxSizeBytes,
  });

  String get sizeLabel => formatBytes(approxSizeBytes);
}

/// Formats a byte count as a short human-readable string, switching from MB
/// to GB at 1024 MB.
String formatBytes(int bytes) {
  final mb = bytes / (1024 * 1024);
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}

const _baseUrl = 'https://openslide.cs.cmu.edu/download/openslide-testdata/Aperio';

final List<SampleSlide> kSampleSlides = [
  SampleSlide(
    fileName: 'CMU-1-Small-Region.svs',
    title: 'CMU-1 (small region)',
    description: 'Smallest file, downloads in seconds — good for a quick test.',
    url: Uri.parse('$_baseUrl/CMU-1-Small-Region.svs'),
    approxSizeBytes: 1938955,
  ),
  SampleSlide(
    fileName: 'JP2K-33003-1.svs',
    title: 'JP2K-33003-1',
    description: 'JPEG 2000 compression, medium size.',
    url: Uri.parse('$_baseUrl/JP2K-33003-1.svs'),
    approxSizeBytes: 63847265,
  ),
  SampleSlide(
    fileName: 'CMU-1-JP2K-33005.svs',
    title: 'CMU-1 (JPEG 2000)',
    description: 'Same slide as CMU-1 but JPEG 2000 compressed instead of plain JPEG.',
    url: Uri.parse('$_baseUrl/CMU-1-JP2K-33005.svs'),
    approxSizeBytes: 132565343,
  ),
  SampleSlide(
    fileName: 'CMU-1.svs',
    title: 'CMU-1',
    description: 'Full sample slide, plain JPEG compression.',
    url: Uri.parse('$_baseUrl/CMU-1.svs'),
    approxSizeBytes: 177552579,
  ),
  SampleSlide(
    fileName: 'CMU-3.svs',
    title: 'CMU-3',
    description: 'Another sample slide, large size.',
    url: Uri.parse('$_baseUrl/CMU-3.svs'),
    approxSizeBytes: 253815723,
  ),
  SampleSlide(
    fileName: 'JP2K-33003-2.svs',
    title: 'JP2K-33003-2',
    description: 'JPEG 2000 compression, large size.',
    url: Uri.parse('$_baseUrl/JP2K-33003-2.svs'),
    approxSizeBytes: 289250433,
  ),
  SampleSlide(
    fileName: 'CMU-2.svs',
    title: 'CMU-2',
    description: 'Sample slide, the largest file in the list.',
    url: Uri.parse('$_baseUrl/CMU-2.svs'),
    approxSizeBytes: 390750635,
  ),
];
