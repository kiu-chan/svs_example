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

  String get sizeLabel {
    final mb = approxSizeBytes / (1024 * 1024);
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }
}

const _baseUrl = 'https://openslide.cs.cmu.edu/download/openslide-testdata/Aperio';

final List<SampleSlide> kSampleSlides = [
  SampleSlide(
    fileName: 'CMU-1-Small-Region.svs',
    title: 'CMU-1 (vùng nhỏ)',
    description: 'File nhỏ nhất, tải nhanh trong vài giây — phù hợp để test nhanh.',
    url: Uri.parse('$_baseUrl/CMU-1-Small-Region.svs'),
    approxSizeBytes: 1938955,
  ),
  SampleSlide(
    fileName: 'JP2K-33003-1.svs',
    title: 'JP2K-33003-1',
    description: 'Nén JPEG 2000, kích thước vừa phải.',
    url: Uri.parse('$_baseUrl/JP2K-33003-1.svs'),
    approxSizeBytes: 63847792,
  ),
  SampleSlide(
    fileName: 'CMU-1-JP2K-33005.svs',
    title: 'CMU-1 (JPEG 2000)',
    description: 'Cùng slide với CMU-1 nhưng nén JPEG 2000 thay vì JPEG thường.',
    url: Uri.parse('$_baseUrl/CMU-1-JP2K-33005.svs'),
    approxSizeBytes: 132565343,
  ),
  SampleSlide(
    fileName: 'CMU-1.svs',
    title: 'CMU-1',
    description: 'Slide mẫu đầy đủ, nén JPEG thường.',
    url: Uri.parse('$_baseUrl/CMU-1.svs'),
    approxSizeBytes: 177552579,
  ),
  SampleSlide(
    fileName: 'CMU-3.svs',
    title: 'CMU-3',
    description: 'Slide mẫu khác, kích thước lớn.',
    url: Uri.parse('$_baseUrl/CMU-3.svs'),
    approxSizeBytes: 253818306,
  ),
  SampleSlide(
    fileName: 'JP2K-33003-2.svs',
    title: 'JP2K-33003-2',
    description: 'Nén JPEG 2000, kích thước lớn.',
    url: Uri.parse('$_baseUrl/JP2K-33003-2.svs'),
    approxSizeBytes: 289249689,
  ),
  SampleSlide(
    fileName: 'CMU-2.svs',
    title: 'CMU-2',
    description: 'Slide mẫu, file lớn nhất trong danh sách.',
    url: Uri.parse('$_baseUrl/CMU-2.svs'),
    approxSizeBytes: 390751846,
  ),
];
