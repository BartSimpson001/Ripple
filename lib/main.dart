import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'splash_screen.dart';
import 'Repository/auth_repository.dart';
import 'Repository/user_repository.dart';
import 'Repository/report_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/Home/presentation/bloc/home_bloc.dart';
import 'features/Report/presentation/bloc/report_bloc.dart';
import 'common/services/notification_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  if (message.notification != null) {
    await NotificationService().showLocalNotification(
      title: message.notification!.title ?? 'Ripple',
      body: message.notification!.body ?? 'New update',
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  await NotificationService().initialize();

  await Supabase.initialize(
    url: 'https://chmsbijddsbpodqllctv.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNobXNiaWpkZHNicG9kcWxsY3R2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc4MzE0NTIsImV4cCI6MjA3MzQwNzQ1Mn0.o2Qe8xBE-ZJrNCbHcwnEaZleNJd9wxNpK4Yl8Zm4PUI',
  );

  final authRepository = AuthRepository();
  await authRepository.initialize();

  runApp(
    Ripple(authRepository: authRepository),
  );
}

class Ripple extends StatelessWidget {
  final AuthRepository authRepository;

  const Ripple({
    super.key,
    required this.authRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(
          value: authRepository,
        ),
        RepositoryProvider<UserRepository>(
          create: (_) => UserRepository(),
        ),
        RepositoryProvider<ReportRepository>(
          create: (_) => ReportRepository(
            supabase: Supabase.instance.client,
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) {
              final bloc = AuthBloc(
                authRepository: context.read<AuthRepository>(),
              );
              bloc.add(AppStarted());
              return bloc;
            },
          ),
          BlocProvider<HomeBloc>(
            create: (context) => HomeBloc(
              userRepository: context.read<UserRepository>(),
            ),
          ),
          BlocProvider<ReportBloc>(
            create: (context) => ReportBloc(
              reportRepository: context.read<ReportRepository>(),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}