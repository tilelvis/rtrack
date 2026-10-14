import 'package:flutter/foundation.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../repositories/loan_repository.dart';
import '../services/daily_payment_calculator.dart';
import '../services/widget_service.dart';

/// Extension to check if two dates fall on the same calendar day.
extension DateTimeSameDay on DateTime {
  bool isSameDayAs(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

/// App-wide state manager. Holds the active loan, payment list, and
/// derived values (progress, balance, daily recommendation).
///
/// Architecture:
///   - Does NOT touch sqflite directly — goes through [LoanRepository]
///   - Does NOT contain formatting logic — that lives in services
///   - Notifies listeners on every state change
///
/// Dependency injection: repository is passed via constructor so tests
/// can inject a mock. No global singletons.
class LoanProvider extends ChangeNotifier {
  final LoanRepository _repo;
  final WidgetService _widget;

  LoanProvider({
    required LoanRepository repository,
    WidgetService? widgetService,
  })  : _repo = repository,
        _widget = widgetService ?? WidgetService();

  List<Loan> _loans = [];
  Loan? _activeLoan;
  double _totalPaid = 0;
  List<Payment> _recentPayments = [];

  List<Loan> get loans => _loans;
  Loan? get activeLoan => _activeLoan;
  double get totalPaid => _totalPaid;
  List<Payment> get recentPayments => _recentPayments;

  bool _loading = false;
  bool get loading => _loading;

  Future<void> loadLoans() async {
    _loading = true;
    notifyListeners();
    _loans = await _repo.getAllLoans();

    // Auto-hide loans that are past their due date AND fully paid.
    for (final loan in _loans) {
      if (!loan.isHidden) {
        final isPastDue = DateTime.now().isAfter(loan.dueDate);
        final totalPaid = await _repo.getTotalPaid(loan.id);
        final isFullyPaid = totalPaid >= loan.totalPayable;
        if (isPastDue && isFullyPaid) {
          await _repo.setLoanHidden(loan.id, true);
        }
      }
    }
    _loans = await _repo.getAllLoans();

    if (_activeLoan == null && _loans.isNotEmpty) {
      final visible = _loans.where((l) => !l.isHidden).toList();
      if (visible.isNotEmpty) {
        visible.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        final now = DateTime.now();
        final current = visible
            .where((l) => now.isBefore(l.dueDate) || now.isSameDayAs(l.dueDate))
            .toList();
        if (current.isNotEmpty) {
          await setActiveLoan(current.first.id);
        } else {
          await setActiveLoan(visible.last.id);
        }
      } else {
        await setActiveLoan(_loans.first.id);
      }
    } else if (_activeLoan != null) {
      await setActiveLoan(_activeLoan!.id);
    }
    _loading = false;
    notifyListeners();
    _refreshWidget();
  }

  Future<void> setActiveLoan(String id) async {
    _activeLoan = await _repo.getLoan(id);
    if (_activeLoan != null) {
      _totalPaid = await _repo.getTotalPaid(id);
      _recentPayments = await _repo.getPaymentsForLoan(id);
    } else {
      _totalPaid = 0;
      _recentPayments = [];
    }
    notifyListeners();
    _refreshWidget();
  }

  Future<String> createLoan(Loan loan) async {
    final id = await _repo.insertLoan(loan);
    await loadLoans();
    await setActiveLoan(id);
    return id;
  }

  Future<void> closePaidLoan(String id) async {
    await _repo.deleteLoan(id);
    if (_activeLoan?.id == id) _activeLoan = null;
    _loans = await _repo.getAllLoans();
    if (_loans.isNotEmpty) {
      await setActiveLoan(_loans.first.id);
    } else {
      _totalPaid = 0;
      _recentPayments = [];
      notifyListeners();
    }
    _refreshWidget();
  }

  Future<void> hideLoan(String id) async {
    await _repo.setLoanHidden(id, true);
    if (_activeLoan?.id == id) _activeLoan = null;
    _loans = await _repo.getAllLoans();
    final visible = _loans.where((l) => !l.isHidden).toList();
    if (_activeLoan == null && visible.isNotEmpty) {
      await setActiveLoan(visible.first.id);
    } else {
      _totalPaid = 0;
      _recentPayments = [];
      notifyListeners();
    }
    _refreshWidget();
  }

  Future<void> unhideLoan(String id) async {
    await _repo.setLoanHidden(id, false);
    _loans = await _repo.getAllLoans();
    notifyListeners();
  }

  List<Loan> get visibleLoans => _loans.where((l) => !l.isHidden).toList();
  List<Loan> get hiddenLoans => _loans.where((l) => l.isHidden).toList();

  Future<bool> addPayment(Payment payment) async {
    try {
      await _repo.insertPayment(payment);
    } on StateError {
      return false;
    }
    if (_activeLoan != null) {
      await setActiveLoan(_activeLoan!.id);
    } else {
      _recentPayments = await _repo.getAllPayments();
      notifyListeners();
      _refreshWidget();
    }
    return true;
  }

  Future<void> deletePayment(String id) async {
    await _repo.deletePayment(id);
    if (_activeLoan != null) {
      await setActiveLoan(_activeLoan!.id);
    }
  }

  /// Progress 0.0–1.0
  double get progress {
    if (_activeLoan == null) return 0;
    final total = _activeLoan!.totalPayable;
    if (total <= 0) return 0;
    final p = _totalPaid / total;
    if (p > 1) return 1;
    return p;
  }

  double get balanceRemaining {
    if (_activeLoan == null) return 0;
    final rem = _activeLoan!.totalPayable - _totalPaid;
    return rem < 0 ? 0 : rem;
  }

  bool get todayPaid {
    final today = DateTime.now();
    return _recentPayments.any((p) =>
        p.paidAt.year == today.year &&
        p.paidAt.month == today.month &&
        p.paidAt.day == today.day);
  }

  /// Intelligent daily payment recommendation.
  DailyPaymentRecommendation? get dailyRecommendation {
    final loan = _activeLoan;
    if (loan == null) return null;
    return DailyPaymentCalculator.compute(
      loan: loan,
      remainingBalance: balanceRemaining,
    );
  }

  Future<void> _refreshWidget() async {
    try {
      await _widget.update(
        loan: _activeLoan,
        totalPaid: _totalPaid,
      );
    } catch (_) {
      // Widget update failure should never crash the app.
    }
  }
}
