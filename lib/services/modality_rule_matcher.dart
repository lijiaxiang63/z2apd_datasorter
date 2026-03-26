import '../models/modality_rule.dart';

/// Performs fnmatch-style glob matching (case-insensitive).
bool fnmatch(String pattern, String text) {
  final buf = StringBuffer('^');
  for (var i = 0; i < pattern.length; i++) {
    final c = pattern[i];
    switch (c) {
      case '*':
        buf.write('.*');
      case '?':
        buf.write('.');
      case '.':
      case '+':
      case '^':
      case '\$':
      case '{':
      case '}':
      case '(':
      case ')':
      case '|':
      case '[':
      case ']':
      case '\\':
        buf.write('\\$c');
      default:
        buf.write(c);
    }
  }
  buf.write(r'$');
  return RegExp(buf.toString(), caseSensitive: false).hasMatch(text);
}

/// Returns the modality for the first matching rule, or null.
String? matchRules(String seriesDesc, List<ModalityRule> rules) {
  for (final rule in rules) {
    if (fnmatch(rule.pattern, seriesDesc)) {
      return rule.modality;
    }
  }
  return null;
}

/// Whether a PET series should be converted given the current rules.
bool shouldConvertPetSeries({
  required String seriesDesc,
  required List<ModalityRule> rules,
  required bool onlyMatched,
}) {
  if (rules.isEmpty) {
    return true;
  }

  if (matchRules(seriesDesc, rules) != null) {
    return true;
  }

  return !onlyMatched;
}
