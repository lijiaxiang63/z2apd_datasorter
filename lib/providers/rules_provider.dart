import 'package:flutter/foundation.dart';
import '../models/modality_rule.dart';
import '../services/rules_persistence.dart';

class RulesProvider extends ChangeNotifier {
  List<ModalityRule> _rules = [];
  bool _onlyMatched = true;

  List<ModalityRule> get rules => List.unmodifiable(_rules);
  bool get onlyMatched => _onlyMatched;

  Future<void> loadRules() async {
    final (rules, onlyMatched) = await RulesPersistence.loadRules();
    _rules = rules;
    _onlyMatched = onlyMatched;
    notifyListeners();
  }

  Future<void> addRule(ModalityRule rule) async {
    _rules.add(rule);
    await _persist();
  }

  Future<void> addRules(List<ModalityRule> newRules) async {
    final existingPatterns = _rules.map((r) => r.pattern).toSet();
    for (final rule in newRules) {
      if (!existingPatterns.contains(rule.pattern)) {
        _rules.add(rule);
        existingPatterns.add(rule.pattern);
      }
    }
    await _persist();
  }

  Future<void> removeRuleAt(int index) async {
    _rules.removeAt(index);
    await _persist();
  }

  Future<void> setOnlyMatched(bool value) async {
    _onlyMatched = value;
    await _persist();
  }

  bool hasPattern(String pattern) =>
      _rules.any((r) => r.pattern == pattern);

  Future<void> _persist() async {
    await RulesPersistence.saveRules(_rules, _onlyMatched);
    notifyListeners();
  }
}
