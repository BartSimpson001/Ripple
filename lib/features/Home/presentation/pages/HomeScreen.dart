import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ripple_sih/features/Home/presentation/pages/Camera_screen.dart';
import 'package:ripple_sih/features/Home/presentation/pages/leading_board.dart';
import 'package:ripple_sih/features/Home/presentation/pages/settings_page.dart';
import 'package:ripple_sih/features/Report/presentation/pages/my_reports_screen.dart';
import 'package:ripple_sih/features/Report/presentation/pages/community_screen.dart';
import '../../../../common/widgets/custom_card.dart';
import '../bloc/home_bloc.dart';

class RippleHomePage extends StatefulWidget {
  const RippleHomePage({super.key});

  @override
  State<RippleHomePage> createState() => _RippleHomePageState();
}

class _RippleHomePageState extends State<RippleHomePage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CameraPage()),
      );
      return;
    }
    
    // Adjust index for pages since camera is skipped
    int pageIndex = index > 1 ? index - 1 : index;
    setState(() => _selectedIndex = pageIndex);
  }

  final List<Widget> _pages = const [
    HomePage(),
    CommunityScreen(),
    MyReportsScreen(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex >= 1 ? _selectedIndex + 1 : _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'Report'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'My Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Position? _position;
  String? _address;
  String? _timestamp;
  String? _uid;
  String? _phoneNumber;
  bool _isCheckingInternet = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentUser();
      _checkInternet();
      _updateLocation();
      context.read<HomeBloc>().add(FetchUserData());
    });
  }

  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    setState(() {
      _uid = user.uid;
      _phoneNumber = doc.data()?['phone'] ?? 'Unknown';
    });
  }

  Future<void> _updateLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _position = pos;
        _address = '${pos.latitude}, ${pos.longitude}';
        _timestamp = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
      });
    }
  }

  Future<void> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final hasConnection =
          result.isNotEmpty && result.first.rawAddress.isNotEmpty;

      if (!mounted) return;

      setState(() {
        _isOffline = !hasConnection;
        _isCheckingInternet = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isOffline = true;
        _isCheckingInternet = false;
      });
    }
  }

  void _navigateToCamera() {
    if (_uid == null ||
        _phoneNumber == null ||
        _address == null ||
        _timestamp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait, data is loading'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingInternet) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isOffline) {
      return const Center(child: Text('No internet connection'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ripple 24/7'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.emoji_events, color: Colors.amber, size: 30),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LeaderboardWidget()),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            BlocBuilder<HomeBloc, HomeState>(
              builder: (context, state) {
                final greeting = state is UserLoaded
                    ? 'Hello, ${state.name} 👋'
                    : 'Welcome 👋';
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    greeting,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
            CustomReportCard(
              title: 'Report a Complaint',
              subtitle: 'Capture and report civic issues',
              imagePath: 'Assets/home/Report.png',
              buttonText: 'Submit Complaint',
              onPressed: _navigateToCamera,
            ),
            CustomReportCard(
              title: 'Community Hub',
              subtitle: 'Connect with people nearby',
              imagePath: 'Assets/home/Community.png',
              buttonText: 'Community Feed',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CommunityScreen()),
              ),
            ),
            CustomReportCard(
              title: 'Track My Complaint',
              subtitle: 'Check report status',
              imagePath: 'Assets/home/Track.png',
              buttonText: 'Track Status',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyReportsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}