import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/modality_rule.dart';

class RulesPersistence {
  static Future<File> get _rulesFile async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/apd_modality_rules.json');
  }

  static Future<(List<ModalityRule>, bool)> loadRules() async {
    final file = await _rulesFile;
    if (!await file.exists()) return (<ModalityRule>[], true);
    try {
      final data = jsonDecode(await file.readAsString());
      final rules = (data['rules'] as List)
          .map((r) => ModalityRule.fromJson(r as Map<String, dynamic>))
          .toList();
      final onlyMatched = data['only_matched'] as bool? ?? true;
      return (rules, onlyMatched);
    } catch (_) {
      return (<ModalityRule>[], true);
    }
  }

  static Future<void> saveRules(
      List<ModalityRule> rules, bool onlyMatched) async {
    final file = await _rulesFile;
    final data = {
      'rules': rules.map((r) => r.toJson()).toList(),
      'only_matched': onlyMatched,
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
  }
}
