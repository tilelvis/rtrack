import '../models/loan.dart';
import '../models/payment.dart';
import 'database_service.dart';

/// Repository layer — sits between the Provider (state) and the
/// DatabaseService (raw SQLite). All data access goes through here.
///
/// This separation means:
///   - LoanProvider doesn't touch sqflite directly
///   - Future swaps (e.g. to Firebase, Hive) only need a new Repository
///   - Business logic in widgets can call the repository without
///     depending on the Provider's notifyListeners cycle
///
/// Dependency injection: created once in main.dart and passed to
/// LoanProvider via constructor — no global singletons.
class LoanRepository {
  final DatabaseService _db;

  LoanRepository(this._db);

  // ---- Loans ----
  Future<List<Loan>> getAllLoans() => _db.getAllLoans();
  Future<Loan?> getLoan(String id) => _db.getLoan(id);
  Future<String> insertLoan(Loan loan) => _db.insertLoan(loan);
  Future<void> deleteLoan(String id) => _db.deleteLoan(id);
  Future<void> setLoanHidden(String id, bool hidden) =>
      _db.setLoanHidden(id, hidden);

  // ---- Payments ----
  Future<String> insertPayment(Payment payment) => _db.insertPayment(payment);
  Future<List<Payment>> getPaymentsForLoan(String loanId) =>
      _db.getPaymentsForLoan(loanId);
  Future<List<Payment>> getAllPayments() => _db.getAllPayments();
  Future<double> getTotalPaid(String loanId) => _db.getTotalPaid(loanId);
  Future<void> deletePayment(String id) => _db.deletePayment(id);
}
