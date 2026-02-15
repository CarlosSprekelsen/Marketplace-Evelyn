import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launches the phone dialer with the given phone number.
Future<void> launchPhoneCall(String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

/// Opens WhatsApp chat with the given phone number (international format, no +).
Future<void> launchWhatsApp(String phone, {String? message}) async {
  // Remove the leading '+' for WhatsApp URL format
  final sanitized = phone.replaceAll('+', '');
  final uri = Uri.parse(
    'https://wa.me/$sanitized${message != null ? '?text=${Uri.encodeComponent(message)}' : ''}',
  );
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// A row of Call and WhatsApp icon buttons for a given phone number.
class PhoneActionButtons extends StatelessWidget {
  const PhoneActionButtons({super.key, required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.phone, color: Colors.green),
          tooltip: 'Llamar',
          onPressed: () => launchPhoneCall(phone),
        ),
        IconButton(
          icon: const Icon(Icons.chat, color: Colors.teal),
          tooltip: 'WhatsApp',
          onPressed: () => launchWhatsApp(phone),
        ),
      ],
    );
  }
}
