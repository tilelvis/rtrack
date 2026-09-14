/// Payment record — one M-Pesa (or manual) payment toward a loan.
class Payment {
  final String id;
  final String loanId;
  final double amount;
  final DateTime paidAt;
  final String? mpesaCode; // e.g. SI7K2PX1HZ
  final String? phone; // last 4 or full
  final String? sender; // e.g. "JOHN DOE"
  final String? rawMessage; // original SMS text
  final PaymentSource source; // mpesa | manual
  final String? notes;

  Payment({
    required this.id,
    required this.loanId,
    required this.amount,
    required this.paidAt,
    this.mpesaCode,
    this.phone,
    this.sender,
    this.rawMessage,
    this.source = PaymentSource.manual,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'loan_id': loanId,
      'amount': amount,
      'paid_at': paidAt.toIso8601String(),
      'mpesa_code': mpesaCode,
      'phone': phone,
      'sender': sender,
      'raw_message': rawMessage,
      'source': source.name,
      'notes': notes,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> m) {
    return Payment(
      id: m['id'] as String,
      loanId: m['loan_id'] as String,
      amount: (m['amount'] as num).toDouble(),
      paidAt: DateTime.parse(m['paid_at'] as String),
      mpesaCode: m['mpesa_code'] as String?,
      phone: m['phone'] as String?,
      sender: m['sender'] as String?,
      rawMessage: m['raw_message'] as String?,
      source:
          PaymentSource.values.byName(m['source'] as String? ?? 'manual'),
      notes: m['notes'] as String?,
    );
  }
}

enum PaymentSource { mpesa, manual }
