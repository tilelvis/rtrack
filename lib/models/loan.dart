/// Loan entity — a single loan being tracked.
class Loan {
  final String id;
  final String title;
  final double principal;
  final double interestRate; // percent
  final DateTime startDate;
  final DateTime dueDate;
  final double expectedPerInterval; // amount expected per payment interval
  final PaymentInterval interval; // weekly or custom days
  final int customIntervalDays; // when interval == custom
  final String? notes;

  Loan({
    required this.id,
    required this.title,
    required this.principal,
    this.interestRate = 0,
    required this.startDate,
    required this.dueDate,
    required this.expectedPerInterval,
    required this.interval,
    this.customIntervalDays = 7,
    this.notes,
  });

  double get totalPayable {
    if (interestRate <= 0) return principal;
    return principal + (principal * interestRate / 100);
  }

  int get totalDays => dueDate.difference(startDate).inDays + 1;

  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(dueDate)) return 0;
    return dueDate.difference(now).inDays + 1;
  }

  int get intervalDays {
    switch (interval) {
      case PaymentInterval.weekly:
        return 7;
      case PaymentInterval.custom:
        return customIntervalDays <= 0 ? 7 : customIntervalDays;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'principal': principal,
      'interest_rate': interestRate,
      'start_date': startDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'expected_per_interval': expectedPerInterval,
      'interval': interval.name,
      'custom_interval_days': customIntervalDays,
      'notes': notes,
    };
  }

  factory Loan.fromMap(Map<String, dynamic> m) {
    return Loan(
      id: m['id'] as String,
      title: m['title'] as String,
      principal: (m['principal'] as num).toDouble(),
      interestRate: (m['interest_rate'] as num? ?? 0).toDouble(),
      startDate: DateTime.parse(m['start_date'] as String),
      dueDate: DateTime.parse(m['due_date'] as String),
      expectedPerInterval: (m['expected_per_interval'] as num).toDouble(),
      interval: PaymentInterval.values
          .byName(m['interval'] as String? ?? 'weekly'),
      customIntervalDays: (m['custom_interval_days'] as num? ?? 7).toInt(),
      notes: m['notes'] as String?,
    );
  }
}

enum PaymentInterval { weekly, custom }
