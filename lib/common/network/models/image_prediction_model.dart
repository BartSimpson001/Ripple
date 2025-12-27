class ImagePredictionModel {
  final bool success;
  final String predictedClass;
  final double confidence;
  final List<TopPrediction> topPredictions;
  final String timestamp;
  final String? error;

  ImagePredictionModel({
    required this.success,
    required this.predictedClass,
    required this.confidence,
    required this.topPredictions,
    required this.timestamp,
    this.error,
  });

  // Helper getter for title (formatted class name)
  String get title => _formatClassName(predictedClass);
  
  // Helper getter for category
  String get category => predictedClass;

  factory ImagePredictionModel.fromJson(Map<String, dynamic> json) {
    return ImagePredictionModel(
      success: json['success'] ?? false,
      predictedClass: json['predicted_class'] ?? 'Unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      topPredictions: (json['top_predictions'] as List<dynamic>?)
          ?.map((pred) => TopPrediction.fromJson(pred))
          .toList() ?? [],
      timestamp: json['timestamp'] ?? '',
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'predicted_class': predictedClass,
      'confidence': confidence,
      'top_predictions': topPredictions.map((pred) => pred.toJson()).toList(),
      'timestamp': timestamp,
      'error': error,
    };
  }

  // Format class names to be more user-friendly
  String _formatClassName(String className) {
    switch (className) {
      case 'BrokenStreetLight':
        return 'Broken Street Light';
      case 'DrainageOverFlow':
        return 'Drainage Overflow';
      case 'GarbageNotOverflow':
        return 'Garbage Collection Needed';
      case 'GarbageOverflow':
        return 'Garbage Overflow';
      case 'NoPotHole':
        return 'No Pothole Detected';
      case 'NotBrokenStreetLight':
        return 'Street Light Working';
      case 'PotHole':
        return 'Pothole';
      default:
        return className.replaceAll(RegExp(r'([A-Z])'), ' \$1').trim();
    }
  }

  @override
  String toString() {
    return 'ImagePredictionModel(success: $success, predictedClass: $predictedClass, confidence: $confidence, topPredictions: $topPredictions)';
  }
}

class TopPrediction {
  final String className;
  final double confidence;

  TopPrediction({
    required this.className,
    required this.confidence,
  });

  factory TopPrediction.fromJson(Map<String, dynamic> json) {
    return TopPrediction(
      className: json['class'] ?? 'Unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class': className,
      'confidence': confidence,
    };
  }

  @override
  String toString() {
    return 'TopPrediction(className: $className, confidence: $confidence)';
  }
}
