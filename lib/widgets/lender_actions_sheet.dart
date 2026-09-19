import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/loan.dart';
import '../theme/theme.dart';

/// Bottom sheet with quick actions for contacting the lender:
///   - Call (opens phone dialer)
///   - WhatsApp (opens WhatsApp chat with prefilled message)
///   - SMS (opens SMS app with prefilled message)
///   - Email (opens email client with subject + body)
///
/// Returns true if an action was launched (the sheet will close).
Future<void> showLenderActionsSheet(BuildContext context, Loan loan) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Lender header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.5)),
                ),
                child: const Icon(Icons.person, color: Theme.of(context).colorScheme.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.lenderName ?? 'Lender',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (loan.lenderPhone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        loan.lenderPhone!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'CONTACT LENDER',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          // Action grid
          Row(
            children: [
              if (loan.lenderPhone != null) ...[
                Expanded(
                  child: _ActionTile(
                    icon: Icons.call,
                    label: 'Call',
                    color: const Color(0xFF39FF14),
                    onTap: () => _launch(
                      ctx,
                      'tel:${loan.lenderPhone}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (loan.lenderPhoneNormalized != null) ...[
                Expanded(
                  child: _ActionTile(
                    icon: Icons.chat,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () => _launchWhatsApp(ctx, loan),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (loan.lenderPhone != null) ...[
                Expanded(
                  child: _ActionTile(
                    icon: Icons.sms_outlined,
                    label: 'SMS',
                    color: Theme.of(context).colorScheme.secondary,
                    onTap: () => _launch(
                      ctx,
                      'sms:${loan.lenderPhone}?body=${Uri.encodeComponent(_prefilledMessage(loan))}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (loan.lenderEmail != null) ...[
                Expanded(
                  child: _ActionTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    color: const Color(0xFFFFB020),
                    onTap: () => _launchEmail(ctx, loan),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

Future<void> _launch(BuildContext ctx, String uri) async {
  final messenger = ScaffoldMessenger.of(ctx);
  final navigator = Navigator.of(ctx);
  try {
    final launched = await launchUrl(Uri.parse(uri));
    if (!launched) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open app')),
      );
    } else {
      navigator.pop();
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

Future<void> _launchWhatsApp(BuildContext ctx, Loan loan) async {
  final phone = loan.lenderPhoneNormalized;
  if (phone == null) return;
  // Use the wa.me short link which works on both Android & iOS
  final msg = Uri.encodeComponent(_prefilledMessage(loan));
  final uri = 'https://wa.me/$phone?text=$msg';
  await _launch(ctx, uri);
}

Future<void> _launchEmail(BuildContext ctx, Loan loan) async {
  final email = loan.lenderEmail;
  if (email == null) return;
  final subject = Uri.encodeComponent('About loan: ${loan.title}');
  final body = Uri.encodeComponent(_prefilledMessage(loan));
  final uri = 'mailto:$email?subject=$subject&body=$body';
  await _launch(ctx, uri);
}

String _prefilledMessage(Loan loan) {
  final balance = loan.totalPayable - 0; // placeholder — would need provider access
  return 'Hello ${loan.lenderName ?? ""}, I hope you are well. '
      'This is regarding my loan "${loan.title}". '
      'Remaining balance: Ksh ${balance.toStringAsFixed(2)}. '
      'Due: ${loan.dueDate.day}/${loan.dueDate.month}/${loan.dueDate.year}.';
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
