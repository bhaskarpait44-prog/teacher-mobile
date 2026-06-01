import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/notice_provider.dart';
import 'providers/connectivity_provider.dart';
import 'utils/theme.dart';
import 'utils/notification_service.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/pin_login_page.dart';
import 'pages/pin_setup_page.dart';
import 'widgets/connectivity_banner.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.max,
    priority: Priority.high,
    visibility: NotificationVisibility.public,
    playSound: true,
    enableVibration: true,
  );

  const NotificationDetails details = NotificationDetails(android: androidDetails);

  final notification = message.notification;
  if (notification != null) {
    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(message.data),
    );
  } else if (message.data.isNotEmpty) {
    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.data['title'] ?? 'New Notice',
      message.data['body'] ?? '',
      details,
      payload: jsonEncode(message.data),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NoticeProvider()),
      ],
      child: const EduCoreTeacherApp(),
    ),
  );
}

class EduCoreTeacherApp extends StatelessWidget {
  const EduCoreTeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'EduCore Teacher',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.mode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          builder: (context, child) {
            return ConnectivityBanner(child: child ?? const SizedBox.shrink());
          },
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (authProvider.isAuthenticated) {
          if (!authProvider.hasPin) {
            return const PinSetupPage();
          }
          
          if (!authProvider.isPinAuthenticated) {
            return const PinLoginPage();
          }
          
          return const DashboardPage();
        }
        
        return const LoginPage();
      },
    );
  }
}
