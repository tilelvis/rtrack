import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/loan_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init notifications
  await NotificationService().init();
  await NotificationService().requestPermissions();

  // Load saved theme preference (defaults to system)
  final themeProvider = ThemeProvider();
  await themeProvider.load();

  // Load any existing loans
  final loanProvider = LoanProvider();
  await loanProvider.loadLoans();

  // Schedule daily reminder with the intelligent recommendation
  if (loanProvider.activeLoan != null) {
    final rec = loanProvider.dailyRecommendation;
    final isCritical = rec?.severity.name == 'critical' ||
        rec?.severity.name == 'elevated';
    await NotificationService().scheduleMultipleReminders(
      times: const [ReminderTime(hour: 8, minute: 0)],
      loanTitle: loanProvider.activeLoan!.title,
      expectedAmount: rec?.dailyAmount ??
          loanProvider.activeLoan!.expectedPerInterval,
      recommendationBody: rec?.message,
      isCritical: isCritical,
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LoanProvider>.value(value: loanProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: const LoanTrackerApp(),
    ),
  );
}

class LoanTrackerApp extends StatelessWidget {
  const LoanTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    // Map our AppThemeMode enum to Flutter's ThemeMode
    final ThemeMode flutterMode;
    switch (themeProvider.mode) {
      case AppThemeMode.light:
        flutterMode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
        flutterMode = ThemeMode.dark;
        break;
      case AppThemeMode.system:
        flutterMode = ThemeMode.system;
        break;
    }

    return MaterialApp(
      title: 'Loan Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: flutterMode,
      home: const HomeScreen(),
    );
  }
}
