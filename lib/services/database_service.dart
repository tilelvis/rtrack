import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/loan.dart';
import '../models/payment.dart';

/// SQLite-backed local storage for loans and payments.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;
  final _uuid = const Uuid();

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'loan_tracker.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE loans (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        principal REAL NOT NULL,
        interest_rate REAL NOT NULL DEFAULT 0,
        start_date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        expected_per_interval REAL NOT NULL,
        interval TEXT NOT NULL,
        custom_interval_days INTEGER NOT NULL DEFAULT 7,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        loan_id TEXT NOT NULL,
        amount REAL NOT NULL,
        paid_at TEXT NOT NULL,
        mpesa_code TEXT,
        phone TEXT,
        sender TEXT,
        raw_message TEXT,
        source TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (loan_id) REFERENCES loans(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_payments_loan_id ON payments(loan_id)',
    );
    await db.execute(
      'CREATE INDEX idx_payments_paid_at ON payments(paid_at)',
    );
  }

  // ---- Loan CRUD ----
  Future<String> insertLoan(Loan loan) async {
    final db = await database;
    final id = loan.id.isEmpty ? _uuid.v4() : loan.id;
    final toSave = Loan(
      id: id,
      title: loan.title,
      principal: loan.principal,
      interestRate: loan.interestRate,
      startDate: loan.startDate,
      dueDate: loan.dueDate,
      expectedPerInterval: loan.expectedPerInterval,
      interval: loan.interval,
      customIntervalDays: loan.customIntervalDays,
      notes: loan.notes,
    );
    await db.insert('loans', toSave.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<List<Loan>> getAllLoans() async {
    final db = await database;
    final rows = await db.query('loans', orderBy: 'due_date ASC');
    return rows.map(Loan.fromMap).toList();
  }

  Future<Loan?> getLoan(String id) async {
    final db = await database;
    final rows = await db.query('loans', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Loan.fromMap(rows.first);
  }

  Future<void> deleteLoan(String id) async {
    final db = await database;
    await db.delete('loans', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Payment CRUD ----
  Future<String> insertPayment(Payment payment) async {
    final db = await database;
    final id = payment.id.isEmpty ? _uuid.v4() : payment.id;
    final toSave = Payment(
      id: id,
      loanId: payment.loanId,
      amount: payment.amount,
      paidAt: payment.paidAt,
      mpesaCode: payment.mpesaCode,
      phone: payment.phone,
      sender: payment.sender,
      rawMessage: payment.rawMessage,
      source: payment.source,
      notes: payment.notes,
    );
    await db.insert('payments', toSave.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<List<Payment>> getPaymentsForLoan(String loanId) async {
    final db = await database;
    final rows = await db.query(
      'payments',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'paid_at DESC',
    );
    return rows.map(Payment.fromMap).toList();
  }

  Future<List<Payment>> getAllPayments() async {
    final db = await database;
    final rows = await db.query('payments', orderBy: 'paid_at DESC');
    return rows.map(Payment.fromMap).toList();
  }

  Future<double> getTotalPaid(String loanId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM payments WHERE loan_id = ?',
      [loanId],
    );
    return (rows.first['total'] as num).toDouble();
  }

  Future<void> deletePayment(String id) async {
    final db = await database;
    await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }
}
