import 'package:flutter/material.dart' as mat;
import 'package:provider/provider.dart';
import 'theme/theme.dart';
import 'providers/loan_provider.dart';
import 'providers/theme_provider.dart' as providers;
import 'services/notification_service.dart';
import 'screens/home_screen.dart';

void main() async {
  mat.WidgetsFlutterBinding.ensureInitialized();

  // Init notifications
  await NotificationService().init();
  await NotificationService().requestPermissions();

  // Load saved theme preference (defaults to system)
  final themeProvider = providers.ThemeProvider();
  await themeProvider.load();

  // Load any existing loans
  final loanProvider = LoanProvider();
  await loanProvider.loadLoans();

  // Default daily reminder at 8:00 AM
  if (loanProvider.activeLoan != null) {
    await NotificationService().scheduleDailyReminder(
      hour: 8,
      minute: 0,
      title: 'Loan Tracker Reminder',
      body:
          'Remember to make your payment of Ksh ${loanProvider.activeLoan!.expectedPerInterval.toStringAsFixed(0)} today.',
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LoanProvider>.value(value: loanProvider),
        ChangeNotifierProvider<providers.ThemeProvider>.value(
            value: themeProvider),
      ],
      child: const LoanTrackerApp(),
    ),
  );
}

class LoanTrackerApp extends mat.StatelessWidget {
  const LoanTrackerApp({super.key});

  @override
  mat.Widget build(mat.BuildContext context) {
    final themeProvider = context.watch<providers.ThemeProvider>();

    // Map our enum to Flutter's ThemeMode
    final mat.ThemeMode flutterMode;
    switch (themeProvider.mode) {
      case providers.ThemeMode.light:
        flutterMode = mat.ThemeMode.light;
        break;
      case providers.ThemeMode.dark:
        flutterMode = mat.ThemeMode.dark;
        break;
      case providers.ThemeMode.system:
        flutterMode = mat.ThemeMode.system;
        break;
    }

    return mat.MaterialApp(
      title: 'Loan Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: flutterMode,
      home: const HomeScreen(),
    );
  }
}
