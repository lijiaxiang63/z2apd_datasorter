/// Auto-guess modality from a DICOM SeriesDescription string.
///
/// Priority matches the Python implementation:
/// FLAIR > T2star > T2w > SWI > dwi > bold > angio > T1w (default)
String guessModality(String description) {
  final d = description.toLowerCase();

  if (d.contains('flair') ||
      (d.contains('t2') &&
          (d.contains('dark-fluid') || d.contains('dark_fluid'))) ||
      d.contains('da-fl')) {
    return 'FLAIR';
  }
  if (d.contains('t2') && d.contains('star')) return 'T2star';
  if (d.contains('t2')) return 'T2w';
  if (d.contains('swi')) return 'SWI';
  if (d.contains('dwi') || d.contains('dti') || d.contains('diff')) {
    return 'dwi';
  }
  if (d.contains('bold') || d.contains('fmri')) return 'bold';
  if (d.contains('angio') || d.contains('tof')) return 'angio';
  if (d.contains('pet') || d.contains('fdg') || d.contains('suv')) {
    return 'pet';
  }
  return 'T1w';
}
