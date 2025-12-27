import 'dart:io';
import 'package:dio/dio.dart';
import '../models/image_prediction_model.dart';

class ImageService {
  final Dio _dio = Dio();
  final String baseUrl = "https://ripple-model-9zph.onrender.com";

  ImageService() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);
  }


  Future<ImagePredictionModel> uploadImageAndGetPrediction(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Image file does not exist');
      }

      // Check file size (limit to 10MB)
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('Image file too large. Please use an image smaller than 10MB.');
      }

      FormData formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(
          imagePath, 
          filename: "upload_${DateTime.now().millisecondsSinceEpoch}.jpg"
        ),
      });

      Response response = await _dio.post(
        "$baseUrl/predict",
        data: formData,
        options: Options(
          headers: {"Content-Type": "multipart/form-data"},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final prediction = ImagePredictionModel.fromJson(data);
        
        // Check if the API returned an error
        if (!prediction.success) {
          throw Exception(prediction.error ?? 'Unknown API error');
        }
        
        return prediction;
      } else {
        // Handle specific error responses from the API
        final errorData = response.data;
        String errorMessage = 'API Error: ${response.statusCode}';
        if (errorData is Map<String, dynamic> && errorData['error'] != null) {
          errorMessage = errorData['error'];
        }
        throw Exception(errorMessage);
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception('Network timeout. Please check your internet connection.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Connection error. Please check your internet connection.');
      } else if (e.response != null) {
        // Handle HTTP error responses
        final statusCode = e.response!.statusCode;
        if (statusCode == 400) {
          throw Exception('Invalid image format. Please use JPG, PNG, or other supported formats.');
        } else if (statusCode == 413) {
          throw Exception('Image file too large. Please use a smaller image.');
        } else if (statusCode == 500) {
          throw Exception('Server error. Please try again later.');
        } else {
          throw Exception('HTTP Error $statusCode: ${e.response?.statusMessage}');
        }
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  /// Upload image and get prediction with retry mechanism
  Future<ImagePredictionModel> uploadImageWithRetry(
    String imagePath, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    Exception? lastException;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await uploadImageAndGetPrediction(imagePath);
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * attempt);
        }
      }
    }
    
    throw lastException ?? Exception('Failed to upload image after $maxRetries attempts');
  }

  /// Get default prediction when API fails
  ImagePredictionModel getDefaultPrediction() {
    return ImagePredictionModel(
      success: false,
      predictedClass: 'Unknown',
      confidence: 0.0,
      topPredictions: [],
      timestamp: DateTime.now().toIso8601String(),
      error: 'API unavailable - using default prediction',
    );
  }

  /// Check API health status
  Future<bool> checkApiHealth() async {
    try {
      // Create a separate Dio instance with shorter timeouts for health check
      final healthDio = Dio();
      healthDio.options.connectTimeout = const Duration(seconds: 10);
      healthDio.options.receiveTimeout = const Duration(seconds: 10);
      
      final response = await healthDio.get("$baseUrl/health");
      
      if (response.statusCode == 200) {
        final data = response.data;
        return data['status'] == 'healthy' && data['model_loaded'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get available classes from the API
  Future<List<String>> getAvailableClasses() async {
    try {
      // Create a separate Dio instance with shorter timeouts for classes endpoint
      final classesDio = Dio();
      classesDio.options.connectTimeout = const Duration(seconds: 10);
      classesDio.options.receiveTimeout = const Duration(seconds: 10);
      
      final response = await classesDio.get("$baseUrl/classes");
      
      if (response.statusCode == 200) {
        final data = response.data;
        return List<String>.from(data['classes'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
