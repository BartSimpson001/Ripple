import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../common/network/services/image_service.dart';
import '../../../../common/network/models/image_prediction_model.dart';
import '../bloc/report_bloc.dart';
import '../bloc/report_event.dart';
import '../bloc/report_state.dart';

class ReportPage extends StatefulWidget {
  final String imagePath;
  final String address;
  final String coords;
  final String timestamp;
  final String phoneNumber;

  const ReportPage({
    super.key,
    required this.imagePath,
    required this.address,
    required this.coords,
    required this.timestamp,
    required this.phoneNumber,
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ImageService _imageService = ImageService();

  // ML Prediction state
  ImagePredictionModel? _predictedTitle;
  bool _isProcessingImage = false;
  bool _isImageAnalyzed = false;

  @override
  void initState() {
    super.initState();
    // Call ML API when page loads
    _analyzeImage();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _analyzeImage() async {
    if (_isImageAnalyzed) return;

    setState(() {
      _isProcessingImage = true;
    });

    try {
      final prediction = await _imageService.uploadImageWithRetry(widget.imagePath);
      setState(() {
        _predictedTitle = prediction;
        _isImageAnalyzed = true;
        _isProcessingImage = false;
      });

      if (mounted && prediction.success) {
        final confidencePercent = (prediction.confidence * 100).toStringAsFixed(1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image analyzed! Confidence: $confidencePercent%'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error analyzing image: $e");
      setState(() {
        _predictedTitle = _imageService.getDefaultPrediction();
        _isImageAnalyzed = true;
        _isProcessingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Using default classification'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String title = _predictedTitle?.title ?? 'Analyzing...';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Report Issue"),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image preview with analysis status
              Stack(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (_isProcessingImage)
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 10),
                          Text(
                            'Analyzing Image...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Location, time & phone info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Location: ${widget.address}",
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text("Time: ${widget.timestamp}"),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text("Phone: ${widget.phoneNumber}"),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // AI Detection Card
              Card(
                color: _isProcessingImage ? Colors.grey.shade300 : Colors.grey.shade100,
                child: ListTile(
                  leading: _isProcessingImage
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.auto_awesome, color: Colors.blue),
                  title: Text(
                    _isProcessingImage ? "Analyzing Image..." : "AI Detected: $title",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isProcessingImage ? Colors.grey : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    _isProcessingImage
                        ? "Please wait while we analyze your image"
                        : "This title was automatically generated by AI analysis",
                    style: TextStyle(
                      fontSize: 12,
                      color: _isProcessingImage ? Colors.grey : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description field
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: "Description",
                  hintText: "Detailed description of the issue",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter a description";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Submit button
              BlocConsumer<ReportBloc, ReportState>(
                listener: (context, state) {
                  if (state is ReportError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else if (state is ReportSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
                builder: (context, state) {
                  final bool isLoading = state is ReportLoading || _isProcessingImage;
                  final bool canSubmit = _isImageAnalyzed && !isLoading;

                  return SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: canSubmit ? () => _submitReport(userId, title) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canSubmit ? Colors.blue.shade600 : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        _isImageAnalyzed ? "Submit Report" : "Analyzing Image...",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitReport(String userId, String title) {
    if (_formKey.currentState!.validate()) {
      context.read<ReportBloc>().add(AddReport(
        userId: userId,
        title: title,
        description: _descController.text.trim(),
        contact: widget.phoneNumber,
        address: widget.address,
        coords: widget.coords,
        timestamp: widget.timestamp,
        imagePath: widget.imagePath,
      ));
    }
  }
}