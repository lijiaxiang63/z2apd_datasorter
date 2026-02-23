class ModalityRule {
  final String pattern;
  final String modality;

  const ModalityRule({required this.pattern, required this.modality});

  Map<String, dynamic> toJson() => {'pattern': pattern, 'modality': modality};

  factory ModalityRule.fromJson(Map<String, dynamic> json) => ModalityRule(
        pattern: json['pattern'] as String,
        modality: json['modality'] as String,
      );

  ModalityRule copyWith({String? pattern, String? modality}) => ModalityRule(
        pattern: pattern ?? this.pattern,
        modality: modality ?? this.modality,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModalityRule &&
          pattern == other.pattern &&
          modality == other.modality;

  @override
  int get hashCode => Object.hash(pattern, modality);
}
