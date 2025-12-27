# Network Layer

This directory contains the network layer for the Ripple app, organized in a clean architecture pattern.

## Structure

```
lib/common/network/
├── models/
│   └── image_prediction_model.dart    # Data models for API responses
├── services/
│   └── image_service.dart             # Image upload and prediction service
├── image_api.dart                     # Legacy API service (deprecated)
└── README.md                          # This file
```

## Usage

### Image Service

The `ImageService` handles image uploads to the Flask ML prediction API and returns structured predictions.

```dart
import 'package:ripple_sih/common/network/services/image_service.dart';
import 'package:ripple_sih/common/network/models/image_prediction_model.dart';

// Initialize the service
final imageService = ImageService();

// Upload image and get prediction
try {
  final prediction = await imageService.uploadImageAndGetPrediction(imagePath);
  if (prediction.success) {
    print('Predicted class: ${prediction.predictedClass}');
    print('Formatted title: ${prediction.title}');
    print('Confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%');
    print('Category: ${prediction.category}');
    
    // Show top predictions
    for (final topPred in prediction.topPredictions) {
      print('${topPred.className}: ${(topPred.confidence * 100).toStringAsFixed(1)}%');
    }
  } else {
    print('Prediction failed: ${prediction.error}');
  }
} catch (e) {
  print('Error: $e');
}

// Upload with retry mechanism
try {
  final prediction = await imageService.uploadImageWithRetry(
    imagePath,
    maxRetries: 3,
    retryDelay: Duration(seconds: 2),
  );
} catch (e) {
  // Get default prediction if all retries fail
  final defaultPrediction = imageService.getDefaultPrediction();
}

// Check API health
final isHealthy = await imageService.checkApiHealth();
if (isHealthy) {
  print('API is ready');
}

// Get available classes
final classes = await imageService.getAvailableClasses();
print('Available classes: $classes');
```

### Image Prediction Model

The `ImagePredictionModel` represents the structured response from the Flask API.

```dart
// Response from Flask API
final prediction = ImagePredictionModel.fromJson({
  'success': true,
  'predicted_class': 'PotHole',
  'confidence': 0.85,
  'top_predictions': [
    {'class': 'PotHole', 'confidence': 0.85},
    {'class': 'NoPotHole', 'confidence': 0.12},
    {'class': 'BrokenStreetLight', 'confidence': 0.03}
  ],
  'timestamp': '2024-01-15T10:30:00Z'
});

// Access formatted title
print(prediction.title); // "Pothole"
print(prediction.category); // "PotHole"
print(prediction.confidence); // 0.85
```

### Supported Classes

The API can detect the following civic issues:
- **BrokenStreetLight** → "Broken Street Light"
- **DrainageOverFlow** → "Drainage Overflow"  
- **GarbageNotOverflow** → "Garbage Collection Needed"
- **GarbageOverflow** → "Garbage Overflow"
- **NoPotHole** → "No Pothole Detected"
- **NotBrokenStreetLight** → "Street Light Working"
- **PotHole** → "Pothole"

## Features

- **Retry Mechanism**: Automatic retry with exponential backoff
- **Error Handling**: Comprehensive error handling with user-friendly messages
- **Timeout Management**: Configurable timeouts for network requests
- **Default Fallback**: Provides default prediction when API fails
- **Type Safety**: Strongly typed models for API responses

## Integration with Camera Screen

The camera screen automatically:
1. Takes a photo
2. Uploads it to the ML API
3. Gets a predicted title
4. Passes the title to the report page
5. Shows loading indicators during processing

## API Endpoints

- **Base URL**: `https://ripple-model-9zph.onrender.com`
- **Predict**: `POST /predict` - Upload image and get prediction
- **Health**: `GET /health` - Check API health and model status
- **Classes**: `GET /classes` - Get available prediction classes

### Predict Endpoint
- **Method**: POST
- **Content-Type**: multipart/form-data
- **Parameter**: `image` (file)
- **Supported formats**: PNG, JPG, JPEG, GIF, BMP, TIFF
- **Max file size**: 10MB

## Error Handling

The service handles various error scenarios:
- Network timeouts
- Connection errors
- API errors (4xx, 5xx)
- File not found errors
- Invalid responses

All errors are wrapped in user-friendly exceptions with appropriate messages.
