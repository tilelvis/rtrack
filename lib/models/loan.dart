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
  final String? keyword; // SMS auto-import filter (e.g. "JOHN DOE" or phone)
  // Lender contact (for tap-to-call / WhatsApp / email statements)
  final String? lenderName;
  final String? lenderPhone; // E.164 or local, e.g. +254712345678 or 0712345678
  final String? lenderEmail;

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
    this.keyword,
    this.lenderName,
    this.lenderPhone,
    this.lenderEmail,
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

  /// Normalise phone to international format (no leading +, no spaces).
  /// Assumes Kenyan numbers if no country code is present.
  /// "0712345678" -> "254712345678"
  /// "+254712345678" -> "254712345678"
  String? get lenderPhoneNormalized {
    final raw = lenderPhone;
    if (raw == null || raw.trim().isEmpty) return null;
    var s = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (s.startsWith('+')) s = s.substring(1);
    if (s.startsWith('00')) s = s.substring(2);
    // Kenyan local -> international
    if (s.startsWith('07') || s.startsWith('01')) s = '254${s.substring(1)}';
    return s;
  }

  /// True if any lender contact info is set.
  bool get hasLenderContact =>
      (lenderName?.isNotEmpty ?? false) ||
      (lenderPhone?.isNotEmpty ?? false) ||
      (lenderEmail?.isNotEmpty ?? false);

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
      'keyword': keyword,
      'lender_name': lenderName,
      'lender_phone': lenderPhone,
      'lender_email': lenderEmail,
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
      keyword: m['keyword'] as String?,
      lenderName: m['lender_name'] as String?,
      lenderPhone: m['lender_phone'] as String?,
      lenderEmail: m['lender_email'] as String?,
    );
  }
}

enum PaymentInterval { weekly, custom }
