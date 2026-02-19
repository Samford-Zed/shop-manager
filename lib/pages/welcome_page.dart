import 'dart:ui';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Soft gradient background matching app style
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFEBE0), Color(0xFFFFCCBC)],
              ),
            ),
          ),
          // Subtle decorative blobs
          Positioned(
            top: -80,
            left: -60,
            child: _GradientBlob(size: 220, colors: const [Color(0xFFFFD1C4), Color(0xFFFFE6DE)]),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: _GradientBlob(size: 260, colors: const [Color(0xFFFF8A65), Color(0xFFFFD7C7)]),
          ),

          // Content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // App icon in a soft container
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(color: Color(0x33212121), blurRadius: 16, offset: Offset(0, 8)),
                          ],
                        ),
                        child: Icon(Icons.storefront, size: 44, color: scheme.primary),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Headline and subtitle
                    Text(
                      'Welcome to Shop Management',
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Manage products, record sales, and view reports—all in one place.',
                      style: theme.textTheme.bodyLarge?.copyWith(color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),
                    // Feature highlights
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        _FeaturePill(icon: Icons.inventory_2, label: 'Products'),
                        SizedBox(width: 8),
                        _FeaturePill(icon: Icons.point_of_sale, label: 'Sales'),
                        SizedBox(width: 8),
                        _FeaturePill(icon: Icons.bar_chart, label: 'Reports'),
                      ],
                    ),

                    const SizedBox(height: 36),

                    // Primary CTA button with rounded style
                    SizedBox(
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(color: Color(0x33212121), blurRadius: 16, offset: Offset(0, 8)),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: scheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('I have an account'),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Secondary CTA with outline, rounded
                    SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterPage()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.primary,
                          side: BorderSide(color: scheme.primary.withValues(alpha: 0.6)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Create a new account'),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Decorative gradient blob widget for background flair (reused pattern)
class _GradientBlob extends StatelessWidget {
  final double size;
  final List<Color> colors;
  const _GradientBlob({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
