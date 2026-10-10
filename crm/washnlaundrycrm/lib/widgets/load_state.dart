import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

/// The error panel shown when a screen's data fails to load or when a 404/500
/// error occurs: a clean message with Retry and Go Home actions, rather than
/// exposing raw server traces or showing an empty page.
class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final int? statusCode;
  final VoidCallback? onRetry;
  final VoidCallback? onHome;
  final IconData? icon;

  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.statusCode,
    this.onRetry,
    this.onHome,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final is404 = statusCode == 404;
    final is500 = statusCode != null && statusCode! >= 500;

    final displayIcon = icon ??
        (is404
            ? Icons.search_off_rounded
            : is500
                ? Icons.cloud_off_rounded
                : Icons.warning_amber_rounded);

    final iconBg = is404
        ? const Color(0xFFF1EFEA)
        : is500
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFF1EFEA);

    final iconColor = is404
        ? const Color(0xFF64748B)
        : is500
            ? const Color(0xFFDC2626)
            : const Color(0xFF94A3B8);

    final effectiveTitle = title != 'Something went wrong'
        ? title
        : is404
            ? 'Page Not Found'
            : is500
                ? 'Server Error'
                : 'Something went wrong';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                displayIcon,
                size: 32,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 16),
            if (statusCode != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: is500 ? const Color(0xFFFEE2E2) : const Color(0xFFF1EFEA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Error $statusCode',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: is500 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              effectiveTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF141A24),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: onRetry ?? () => context.read<AppProvider>().refresh(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF182C4F),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                if (onHome != null)
                  OutlinedButton(
                    onPressed: onHome,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF141A24),
                      side: const BorderSide(color: Color(0xFFE4E0D8)),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Back to Dashboard',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 30,
        height: 30,
        child:
            CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF182C4F)),
      ),
    );
  }
}
