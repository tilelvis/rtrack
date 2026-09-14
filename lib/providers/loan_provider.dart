import 'package:flutter/foundation.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../services/database_service.dart';

class LoanProvider extends ChangeNotifier {
  final _db = DatabaseService();

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
    _loans = await _db.getAllLoans();
    if (_activeLoan == null && _loans.isNotEmpty) {
      await setActiveLoan(_loans.first.id);
    } else if (_activeLoan != null) {
      await setActiveLoan(_activeLoan!.id);
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> setActiveLoan(String id) async {
    _activeLoan = await _db.getLoan(id);
    if (_activeLoan != null) {
      _totalPaid = await _db.getTotalPaid(id);
      _recentPayments = await _db.getPaymentsForLoan(id);
    } else {
      _totalPaid = 0;
      _recentPayments = [];
    }
    notifyListeners();
  }

  Future<String> createLoan(Loan loan) async {
    final id = await _db.insertLoan(loan);
    await loadLoans();
    await setActiveLoan(id);
    return id;
  }

  Future<void> deleteLoan(String id) async {
    await _db.deleteLoan(id);
    if (_activeLoan?.id == id) _activeLoan = null;
    await loadLoans();
  }

  Future<void> addPayment(Payment payment) async {
    await _db.insertPayment(payment);
    if (_activeLoan != null) {
      await setActiveLoan(_activeLoan!.id);
    } else {
      _recentPayments = await _db.getAllPayments();
      notifyListeners();
    }
  }

  Future<void> deletePayment(String id) async {
    await _db.deletePayment(id);
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

  /// Is today's payment done?
  bool get todayPaid {
    final today = DateTime.now();
    return _recentPayments.any((p) =>
        p.paidAt.year == today.year &&
        p.paidAt.month == today.month &&
        p.paidAt.day == today.day);
  }
}
