import '../services/image_service.dart';

class ApiTestUtils {
  static final ImageService _imageService = ImageService();

  /// Test API health endpoint
  static Future<String> testApiHealth() async {
    try {
      final isHealthy = await _imageService.checkApiHealth();
      if (isHealthy) {
        return '✅ API is healthy and model is loaded';
      } else {
        return '❌ API is not healthy or model is not loaded';
      }
    } catch (e) {
      return '❌ Health check failed: $e';
    }
  }

  /// Test available classes endpoint
  static Future<String> testAvailableClasses() async {
    try {
      final classes = await _imageService.getAvailableClasses();
      if (classes.isNotEmpty) {
        final buffer = StringBuffer();
        buffer.writeln('✅ Available classes:');
        for (int i = 0; i < classes.length; i++) {
          buffer.writeln('  ${i + 1}. ${classes[i]}');
        }
        return buffer.toString();
      } else {
        return '❌ No classes returned or API error';
      }
    } catch (e) {
      return '❌ Classes test failed: $e';
    }
  }

  /// Test image prediction with a sample image
  static Future<String> testImagePrediction(String imagePath) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('🔍 Testing image prediction...');
      buffer.writeln('📸 Image path: $imagePath');
      
      final prediction = await _imageService.uploadImageAndGetPrediction(imagePath);
      
      if (prediction.success) {
        buffer.writeln('✅ Prediction successful!');
        buffer.writeln('   🎯 Predicted class: ${prediction.predictedClass}');
        buffer.writeln('   📝 Formatted title: ${prediction.title}');
        buffer.writeln('   📊 Confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%');
        buffer.writeln('   🕒 Timestamp: ${prediction.timestamp}');
        
        if (prediction.topPredictions.isNotEmpty) {
          buffer.writeln('   🏆 Top predictions:');
          for (int i = 0; i < prediction.topPredictions.length; i++) {
            final pred = prediction.topPredictions[i];
            buffer.writeln('     ${i + 1}. ${pred.className} (${(pred.confidence * 100).toStringAsFixed(1)}%)');
          }
        }
      } else {
        buffer.writeln('❌ Prediction failed: ${prediction.error}');
      }
      
      return buffer.toString();
    } catch (e) {
      return '❌ Prediction test failed: $e';
    }
  }

  /// Run all tests
  static Future<String> runAllTests({String? testImagePath}) async {
    final buffer = StringBuffer();
    buffer.writeln('🚀 Starting API integration tests...\n');
    
    buffer.writeln('🔍 Testing API health...');
    buffer.writeln(await testApiHealth());
    buffer.writeln('');
    
    buffer.writeln('🔍 Testing available classes...');
    buffer.writeln(await testAvailableClasses());
    buffer.writeln('');
    
    if (testImagePath != null) {
      buffer.writeln(await testImagePrediction(testImagePath));
    } else {
      buffer.writeln('ℹ️  Skipping image prediction test (no image path provided)');
    }
    
    buffer.writeln('\n🏁 Tests completed!');
    return buffer.toString();
  }

  /// Test retry mechanism
  static Future<String> testRetryMechanism(String imagePath) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('🔍 Testing retry mechanism...');
      buffer.writeln('📸 Image path: $imagePath');
      
      final prediction = await _imageService.uploadImageWithRetry(
        imagePath,
        maxRetries: 2,
        retryDelay: const Duration(seconds: 1),
      );
      
      if (prediction.success) {
        buffer.writeln('✅ Retry mechanism successful!');
        buffer.writeln('   🎯 Final result: ${prediction.title}');
      } else {
        buffer.writeln('❌ Retry mechanism failed: ${prediction.error}');
      }
      
      return buffer.toString();
    } catch (e) {
      return '❌ Retry test failed: $e';
    }
  }
}
