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

  /// Cached total-paid per loan id, so completed-loans detection does not
  /// require an N+1 query every time the history screen rebuilds.
  final Map<String, double> _loanTotals = {};

  List<Loan> get loans => _loans;
  Loan? get activeLoan => _activeLoan;
  double get totalPaid => _totalPaid;
  List<Payment> get recentPayments => _recentPayments;
  Map<String, double> get loanTotals => Map.unmodifiable(_loanTotals);

  bool _loading = false;
  bool get loading => _loading;

  Future<void> loadLoans() async {
    _loading = true;
    notifyListeners();
    _loans = await _repo.getAllLoans();

    // Pre-compute total-paid per loan in one pass so the history screen
    // can resolve completion status synchronously without N+1 queries.
    for (final loan in _loans) {
      _loanTotals[loan.id] = await _repo.getTotalPaid(loan.id);
    }

    if (_activeLoan == null && _loans.isNotEmpty) {
      final visible = _loans.where((l) => !l.isHidden).toList();
      if (visible.isNotEmpty) {
        // Prefer a visible loan that is not yet completed (still has a
        // balance OR its due date is still in the future).
        final active = visible.where((l) => !isLoanCompleted(l)).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        final now = DateTime.now();
        final current = active
            .where((l) => now.isBefore(l.dueDate) || now.isSameDayAs(l.dueDate))
            .toList();
        if (current.isNotEmpty) {
          await setActiveLoan(current.first.id);
        } else if (active.isNotEmpty) {
          await setActiveLoan(active.first.id);
        } else {
          await setActiveLoan(visible.first.id);
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

  /// A loan is "completed" when its due date has passed AND it has been
  /// fully paid off. This is a derived/computed state — there is no
  /// `is_completed` column. Completed loans remain visible in the loan
  /// history screen even though they're not "active" anymore.
  bool isLoanCompleted(Loan loan) {
    if (DateTime.now().isBefore(loan.dueDate)) return false;
    final paid = _loanTotals[loan.id] ?? 0;
    return paid >= loan.totalPayable;
  }

  /// Loans that are visible AND not yet completed (the "current" set).
  List<Loan> get activeLoans =>
      _loans.where((l) => !l.isHidden && !isLoanCompleted(l)).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  /// Loans whose due date has passed AND have been fully paid.
  /// These stay queryable so the user can review their repayment history.
  List<Loan> get completedLoans =>
      _loans.where((l) => !l.isHidden && isLoanCompleted(l)).toList()
        ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

  /// Loans manually hidden by the user (not the same as completed).
  List<Loan> get hiddenLoans =>
      _loans.where((l) => l.isHidden).toList()
        ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

  Future<void> setActiveLoan(String id) async {
    _activeLoan = await _repo.getLoan(id);
    if (_activeLoan != null) {
      _totalPaid = await _repo.getTotalPaid(id);
      _recentPayments = await _repo.getPaymentsForLoan(id);
      _loanTotals[id] = _totalPaid;
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
    _loanTotals.remove(id);
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

  /// All loans NOT manually hidden by the user. Includes both active and
  /// completed loans. Used by the loan switcher on the home/payments screens.
  List<Loan> get visibleLoans =>
      _loans.where((l) => !l.isHidden).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  /// Fetch the full payment list for ANY loan (active or not). Used by
  /// the loan-history screen so the user can review every payment on a
  /// completed/closed loan without first making it active.
  Future<List<Payment>> getPaymentsForLoan(String loanId) {
    return _repo.getPaymentsForLoan(loanId);
  }

  /// Total-paid for ANY loan (cached, falls back to a one-off fetch).
  Future<double> getTotalPaidForLoan(String loanId) async {
    if (_loanTotals.containsKey(loanId)) return _loanTotals[loanId]!;
    final total = await _repo.getTotalPaid(loanId);
    _loanTotals[loanId] = total;
    return total;
  }

  Future<bool> addPayment(Payment payment) async {
    try {
      await _repo.insertPayment(payment);
    } on StateError {
      return false;
    }
    // Refresh the cached total for the loan this payment belongs to so the
    // loan-history screen reflects the new balance without a full reload.
    _loanTotals[payment.loanId] = await _repo.getTotalPaid(payment.loanId);
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
    } else if (_recentPayments.any((p) => p.id == id)) {
      // Refresh the cache for any loan this deleted payment belonged to.
      final loanId = _recentPayments.firstWhere((p) => p.id == id).loanId;
      _loanTotals[loanId] = await _repo.getTotalPaid(loanId);
      _recentPayments = await _repo.getAllPayments();
      notifyListeners();
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
