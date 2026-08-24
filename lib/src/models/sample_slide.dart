/// A curated whole-slide-image test file from OpenSlide's public test-data
/// mirror (see [kSampleDataSourceUrl]), offered in-app so users can try the
/// viewer without sourcing their own .svs file.
class SampleSlide {
  final String fileName;
  final String title;
  final String description;
  final Uri url;
  final int approxSizeBytes;

  /// The TIFF flavor this file uses — `svs` opens both: standard Aperio SVS,
  /// and any other tiled (Big)TIFF pyramid whose levels are JPEG or
  /// JPEG2000 compressed, which is what the "Philips TIFF" entries are.
  final String format;

  /// Who produced/scanned the underlying slide, as credited by the
  /// OpenSlide test-data index.
  final String credit;

  /// The license this specific file is distributed under.
  final String license;

  const SampleSlide({
    required this.fileName,
    required this.title,
    required this.description,
    required this.url,
    required this.approxSizeBytes,
    required this.format,
    required this.credit,
    required this.license,
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

/// Every [SampleSlide] below is downloaded from this OpenSlide project
/// mirror (https://openslide.org), which republishes vendor-donated slides
/// as free, permanently-hosted test data — see its own index at
/// `$kSampleDataSourceUrl/index.json`.
const kSampleDataSourceUrl = 'https://openslide.cs.cmu.edu/download/openslide-testdata';

const _aperioBaseUrl = '$kSampleDataSourceUrl/Aperio';
const _philipsBaseUrl = '$kSampleDataSourceUrl/Philips-TIFF';

const _openslideCredit = 'OpenSlide project (Carnegie Mellon University)';
const _camelyonCredit = 'Computational Pathology Group, Radboud University Medical Center (CAMELYON dataset)';

final List<SampleSlide> kSampleSlides = [
  SampleSlide(
    fileName: 'CMU-1-Small-Region.svs',
    title: 'CMU-1 (small region)',
    description: 'Smallest file, downloads in seconds — good for a quick test.',
    url: Uri.parse('$_aperioBaseUrl/CMU-1-Small-Region.svs'),
    approxSizeBytes: 1938955,
    format: 'Aperio SVS',
    credit: _openslideCredit,
    license: 'CC0-1.0',
  ),
  SampleSlide(
    fileName: 'JP2K-33003-1.svs',
    title: 'JP2K-33003-1',
    description: 'JPEG 2000 compression, medium size.',
    url: Uri.parse('$_aperioBaseUrl/JP2K-33003-1.svs'),
    approxSizeBytes: 63847265,
    format: 'Aperio SVS',
    credit: _openslideCredit,
    license: 'Distributable',
  ),
  SampleSlide(
    fileName: 'CMU-1-JP2K-33005.svs',
    title: 'CMU-1 (JPEG 2000)',
    description: 'Same slide as CMU-1 but JPEG 2000 compressed instead of plain JPEG.',
    url: Uri.parse('$_aperioBaseUrl/CMU-1-JP2K-33005.svs'),
    approxSizeBytes: 132565343,
    format: 'Aperio SVS',
    credit: _openslideCredit,
    license: 'CC0-1.0',
  ),
  SampleSlide(
    fileName: 'CMU-1.svs',
    title: 'CMU-1',
    description: 'Full sample slide, plain JPEG compression.',
    url: Uri.parse('$_aperioBaseUrl/CMU-1.svs'),
    approxSizeBytes: 177552579,
    format: 'Aperio SVS',
    credit: _openslideCredit,
    license: 'CC0-1.0',
  ),
  SampleSlide(
    fileName: 'CMU-3.svs',
    title: 'CMU-3',
    description: 'Another sample slide, large size.',
    url: Uri.parse('$_aperioBaseUrl/CMU-3.svs'),
    approxSizeBytes: 253815723,
    format: 'Aperio SVS',
    credit: _openslideCredit,
    license: 'CC0-1.0',
  ),
  SampleSlide(
    fileName: 'JP2K-33003-2.svs',
    title: 'JP2K-33003-2',
    description: 'JPEG 2000 compression, large size.',
    url: Uri.parse('$_aperioBaseUrl/JP2K-33003-2.svs'),
    approxSizeBytes: 289250433,
    format: 'Aperio SVS',
    credit: _openslideCredit,
    license: 'Distributable',
  ),
  SampleSlide(
    fileName: 'CMU-2.svs',
    title: 'CMU-2',
    description: 'Sample slide, the largest of the Aperio set.',
    url: Uri.parse('$_aperioBaseUrl/CMU-2.svs'),
    approxSizeBytes: 390750635,
    format: 'Aperio SVS',
    credit: _openslideCredit,
    license: 'CC0-1.0',
  ),
  SampleSlide(
    fileName: 'Philips-1.tiff',
    title: 'Philips-1',
    description: 'Lymph node section, H&E stain — BigTIFF, from the CAMELYON16 dataset.',
    url: Uri.parse('$_philipsBaseUrl/Philips-1.tiff'),
    approxSizeBytes: 326607275,
    format: 'Philips TIFF',
    credit: _camelyonCredit,
    license: 'CC0-1.0',
  ),
  SampleSlide(
    fileName: 'Philips-4.tiff',
    title: 'Philips-4',
    description: 'Lymph node section, H&E stain, sparse tiling — BigTIFF, from the CAMELYON17 dataset.',
    url: Uri.parse('$_philipsBaseUrl/Philips-4.tiff'),
    approxSizeBytes: 290991342,
    format: 'Philips TIFF',
    credit: _camelyonCredit,
    license: 'CC0-1.0',
  ),
  SampleSlide(
    fileName: 'Philips-2.tiff',
    title: 'Philips-2',
    description: 'Lymph node section, H&E stain, nearly 1 GB — BigTIFF, from the CAMELYON16 dataset.',
    url: Uri.parse('$_philipsBaseUrl/Philips-2.tiff'),
    approxSizeBytes: 914485186,
    format: 'Philips TIFF',
    credit: _camelyonCredit,
    license: 'CC0-1.0',
  ),
  SampleSlide(
    fileName: 'Philips-3.tiff',
    title: 'Philips-3',
    description: 'Lymph node section, H&E stain — over 3 GB, the largest sample offered. BigTIFF, from the CAMELYON16 dataset.',
    url: Uri.parse('$_philipsBaseUrl/Philips-3.tiff'),
    approxSizeBytes: 3305342358,
    format: 'Philips TIFF',
    credit: _camelyonCredit,
    license: 'CC0-1.0',
  ),
];
