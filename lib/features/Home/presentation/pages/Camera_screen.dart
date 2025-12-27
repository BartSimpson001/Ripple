import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../Report/presentation/pages/report_page.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  Position? _position;
  String? _googleMapsUrl;
  String? _imagePath;

  String _timestamp = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());

  String? _uid;
  String? _phoneNumber;

  bool _isPreviewMode = false;
  bool _isProcessingImage = false;

  XFile? _capturedImage;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _setupCamera();
    _checkPermissionsAndUpdateLocation();
    _getCurrentUser();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _timestamp =
              DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
        });
      }
    });
  }

  /// ================= CAMERA =================
  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showError("No camera found");
        return;
      }

      final backCamera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;

      if (mounted) setState(() {});
    } catch (e) {
      _showError("Camera init failed: $e");
    }
  }

  /// ================= USER =================
  Future<void> _getCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      setState(() {
        _uid = user.uid;
        _phoneNumber = doc.data()?['phone'] ?? "Unknown";
      });
    } catch (e) {
      debugPrint("User error: $e");
    }
  }

  /// ================= LOCATION =================
  Future<void> _checkPermissionsAndUpdateLocation() async {
    try {
      await Permission.camera.request();

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _position = pos;
          _googleMapsUrl =
          "https://www.google.com/maps?q=${pos.latitude},${pos.longitude}";
        });
      }
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  /// ================= PHOTO =================
  Future<void> _takePhoto() async {
    if (_controller == null) return;

    try {
      setState(() => _isProcessingImage = true);

      final image = await _controller!.takePicture();
      await _saveToGallery(image.path);

      setState(() {
        _capturedImage = image;
        _imagePath = image.path;
        _isPreviewMode = true;
        _isProcessingImage = false;
      });
    } catch (e) {
      _showError("Capture failed: $e");
      setState(() => _isProcessingImage = false);
    }
  }

  Future<bool> _saveToGallery(String path) async {
    try {
      if (!await Gal.hasAccess()) {
        if (!await Gal.requestAccess()) return false;
      }
      await Gal.putImage(path, album: "Ripple SIH");
      return true;
    } catch (e) {
      debugPrint("Gallery error: $e");
      return false;
    }
  }

  /// ================= CONFIRM =================
  void _confirmImage() {
    if (_imagePath == null || _uid == null || _phoneNumber == null) {
      _showError("User data missing");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPage(
          imagePath: _imagePath!,
          address: _googleMapsUrl ?? "Location unavailable",
          coords: _position != null
              ? "${_position!.latitude}, ${_position!.longitude}"
              : "Coords unavailable",
          timestamp: _timestamp,
          phoneNumber: _phoneNumber!,
        ),
      ),
    );
  }

  void _retakeImage() {
    setState(() {
      _isPreviewMode = false;
      _capturedImage = null;
      _imagePath = null;
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller?.dispose();
    super.dispose();
  }

  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isPreviewMode ? _imagePreview() : _cameraView(),
    );
  }

  Widget _cameraView() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_controller!),

        if (_googleMapsUrl != null)
          Positioned(
            bottom: 110,
            left: 16,
            right: 16,
            child: _watermark(),
          ),
        
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: 64,
              height: 64,
              child: ElevatedButton(
                onPressed: _isProcessingImage ? null : _takePhoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white70,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: _isProcessingImage
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black,
                  ),
                )
                    : const Icon(
                  Icons.camera_alt,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _watermark() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_timestamp, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              if (_googleMapsUrl != null) {
                await launchUrl(Uri.parse(_googleMapsUrl!));
              }
            },
            child: Text(
              "View on Google Maps",
              style: TextStyle(
                color: Colors.blue[200],
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(_capturedImage!.path), fit: BoxFit.cover),

        Positioned(
          bottom: 30,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _retakeImage,
                icon: const Icon(Icons.refresh),
                label: const Text("Retake"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
              ElevatedButton.icon(
                onPressed: _confirmImage,
                icon: const Icon(Icons.check),
                label: const Text("Confirm"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
