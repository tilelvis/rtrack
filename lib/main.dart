import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/theme.dart';
import 'providers/loan_provider.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init notifications
  await NotificationService().init();
  await NotificationService().requestPermissions();

  // Load any existing loans
  final provider = LoanProvider();
  await provider.loadLoans();

  // Default daily reminder at 8:00 AM
  if (provider.activeLoan != null) {
    await NotificationService().scheduleDailyReminder(
      hour: 8,
      minute: 0,
      title: 'Loan Tracker Reminder',
      body:
          'Remember to make your payment of Ksh ${provider.activeLoan!.expectedPerInterval.toStringAsFixed(0)} today.',
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LoanProvider>.value(value: provider),
      ],
      child: const LoanTrackerApp(),
    ),
  );
}

class LoanTrackerApp extends StatelessWidget {
  const LoanTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loan Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
