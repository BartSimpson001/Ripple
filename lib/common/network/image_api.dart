import 'services/image_service.dart';

@Deprecated('Use ImageService instead')
class ApiService {
  final ImageService _imageService = ImageService();

  @Deprecated('Use ImageService.uploadImageAndGetPrediction instead')
  Future<Map<String, dynamic>> uploadImage(String imagePath) async {
    try {
      final prediction = await _imageService.uploadImageAndGetPrediction(imagePath);
      return prediction.toJson();
    } catch (e) {
      throw Exception("Upload error: $e");
    }
  }
}
