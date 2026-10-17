import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/loan_provider.dart';
import 'providers/theme_provider.dart';
import 'repositories/loan_repository.dart';
import 'services/database_service.dart';
import 'services/daily_payment_calculator.dart';
import 'services/notification_service.dart';
import 'services/sms_auto_import_service.dart';
import 'screens/create_loan_screen.dart';
import 'screens/home_screen.dart';
import 'screens/manual_payment_screen.dart';
import 'screens/mpesa_paste_screen.dart';
import 'theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---- Dependency injection (no global singletons) ----
  final databaseService = DatabaseService();
  final repository = LoanRepository(databaseService);

  // ---- Init notifications ----
  await NotificationService().init();
  await NotificationService().requestPermissions();

  // ---- Load saved theme preference ----
  final themeProvider = ThemeProvider();
  await themeProvider.load();

  // ---- Load loans via repository ----
  final loanProvider = LoanProvider(repository: repository);
  await loanProvider.loadLoans();

  // ---- Schedule daily reminder with the intelligent recommendation ----
  if (loanProvider.activeLoan != null) {
    final rec = loanProvider.dailyRecommendation;
    final isCritical = rec?.severity == RecommendationSeverity.critical ||
        rec?.severity == RecommendationSeverity.elevated;
    await NotificationService().scheduleMultipleReminders(
      times: const [ReminderTime(hour: 8, minute: 0)],
      loanTitle: loanProvider.activeLoan!.title,
      expectedAmount: rec?.dailyAmount ??
          loanProvider.activeLoan!.expectedPerInterval,
      recommendationBody: rec?.message,
      isCritical: isCritical,
    );
  }

  // ---- Start auto-import SMS listener ----
  // Listens for incoming M-Pesa SMS while the app is open. When a message
  // matches the active loan's keyword (e.g. "001709" or "NCBA"), it
  // auto-creates a payment and shows a notification.
  await SmsAutoImportService().startListening(
    repository: repository,
    getActiveLoan: () => loanProvider.activeLoan,
    onPaymentImported: (payment) {
      // Refresh the provider so the dashboard updates immediately
      if (loanProvider.activeLoan != null) {
        loanProvider.setActiveLoan(loanProvider.activeLoan!.id);
      }
    },
  );

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

      // ---- Named routes ----
      // Use Navigator.pushNamed(context, '/mpesa') instead of
      // Navigator.push(MaterialPageRoute(...)) for cleaner navigation.
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/create-loan':
            return MaterialPageRoute(
              builder: (_) => const CreateLoanScreen(),
              settings: settings,
            );
          case '/manual':
            return MaterialPageRoute(
              builder: (_) => const ManualPaymentScreen(),
              settings: settings,
            );
          case '/mpesa':
            return MaterialPageRoute(
              builder: (_) => const MpesaPasteScreen(),
              settings: settings,
            );
          default:
            return null;
        }
      },
    );
  }
}
