class SoilRecord {
  const SoilRecord({
    required this.zonaId,
    required this.predictedIndex,
    required this.confidence,
    required this.createdAt,
    this.correctedIndex,
  });

  final String zonaId;
  final int predictedIndex;
  final double confidence;
  final String createdAt;
  final int? correctedIndex;

  bool get corrected => correctedIndex != null;

  int get effectiveIndex => correctedIndex ?? predictedIndex;

  SoilRecord withCorrection(int index) {
    return SoilRecord(
      zonaId: zonaId,
      predictedIndex: predictedIndex,
      confidence: confidence,
      createdAt: createdAt,
      correctedIndex: index,
    );
  }

  Map<String, dynamic> toJson() => {
    'zona_id': zonaId,
    'predicted_index': predictedIndex,
    'confidence': confidence,
    'created_at': createdAt,
    if (correctedIndex != null) 'corrected_index': correctedIndex,
  };

  factory SoilRecord.fromJson(Map<String, dynamic> json) {
    return SoilRecord(
      zonaId: json['zona_id'] as String? ?? '',
      predictedIndex: (json['predicted_index'] as num?)?.toInt() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      correctedIndex: (json['corrected_index'] as num?)?.toInt(),
    );
  }
}
