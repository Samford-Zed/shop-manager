import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'register_page.dart';
import 'welcome_page.dart';
import 'product_page.dart';
import 'main_dashboard_page.dart';
import '../config/api.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final ValueNotifier<bool> _obscure = ValueNotifier<bool>(true);
  final String baseUrl = ApiConfig.baseUrl;
  bool _isSubmitting = false;

  Future<void> login() async {
    if (_isSubmitting) return;
    _isSubmitting = true;

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _isSubmitting = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    final uri = Uri.parse('$baseUrl/login');
    debugPrint('Login: baseUrl=$baseUrl uri=$uri');

    // Quick health check so we can surface reachability problems faster
    try {
      final healthUri = Uri.parse('$baseUrl/health');
      final healthRes = await http.get(healthUri).timeout(const Duration(seconds: 3));
      if (healthRes.statusCode != 200) {
        if (!mounted) { _isSubmitting = false; return; }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot reach server at $baseUrl (health ${healthRes.statusCode}).\nEnsure backend is running and accessible from this device.')),
        );
        _isSubmitting = false;
        return;
      }
    } on TimeoutException catch (_) {
      if (!mounted) { _isSubmitting = false; return; }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server did not respond to health check at $baseUrl.\nMake sure the backend is running and reachable from this device.\nIf you run on an Android emulator, try using http://10.0.2.2:5000 or run with --dart-define=API_BASE_URL=http://10.0.2.2:5000'),
        ),
      );
      _isSubmitting = false;
      return;
    } catch (e) {
      if (!mounted) { _isSubmitting = false; return; }
      debugPrint('Login: health check error=$e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not contact server at $baseUrl: $e')),
      );
      _isSubmitting = false;
      return;
    }

    try {
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) { _isSubmitting = false; return; }
      debugPrint('Login: status=${res.statusCode} body=${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final token = data['token'] as String;
        final role = (data['role'] as String?) ?? 'CASHIER';
        final name = (data['name'] as String?) ?? email;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => role == 'OWNER'
                ? MainDashboardPage(username: name, token: token, role: role)
                : ProductPage(username: name, token: token, role: role),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed (${res.statusCode}): ${res.body}')),
        );
      }
    } on TimeoutException catch (_) {
      if (!mounted) { _isSubmitting = false; return; }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login request timed out. Please try again.')),
      );
    } on Exception catch (e) {
      if (!mounted) { _isSubmitting = false; return; }
      debugPrint('Login: exception=$e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login error: $e')),
      );
    } finally {
      _isSubmitting = false;
    }
  }

  void goToRegister() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  void backToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
          (route) => false,
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _obscure.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Login',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.home),
          tooltip: 'Back to Home',
          onPressed: backToHome,
        ),
        elevation: 0,
        backgroundColor: const Color(0xFFFFF3E6),
      ),
      body: Stack(
        children: [
          // Gradient backdrop
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFEBE0), Color(0xFFFFCCBC)],
              ),
            ),
          ),
          // Decorative blobs
          Positioned(
            top: -80,
            left: -60,
            child: _GradientBlob(size: 240, colors: const [Color(0xFFFFD1C4), Color(0xFFFFE6DE)]),
          ),
          Positioned(
            bottom: -90,
            right: -70,
            child: _GradientBlob(size: 280, colors: const [Color(0xFFFF8A65), Color(0xFFFFD7C7)]),
          ),
          // Curved backdrop shape for extra flair
          Positioned.fill(
            child: CustomPaint(
              painter: _CurvedBackdropPainter(color: Colors.white.withValues(alpha: 0.20)),
            ),
          ),

          // Content card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.80),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33212121), blurRadius: 20, offset: Offset(0, 12)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Icon header badge
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              height: 64,
                              width: 64,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [scheme.primary.withValues(alpha: 0.15), scheme.secondary.withValues(alpha: 0.15)]),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                              ),
                              child: Icon(Icons.lock_outline, color: scheme.primary, size: 28),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Welcome back',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please sign in to continue',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                          ),
                          const SizedBox(height: 24),

                          // Email field (replaces Username)
                          TextField(
                            controller: emailController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: const Color(0xFFF6F8FC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: scheme.primary, width: 1.6)),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),

                          // Password
                          ValueListenableBuilder<bool>(
                            valueListenable: _obscure,
                            builder: (context, isObscure, _) {
                              return TextField(
                                controller: passwordController,
                                obscureText: isObscure,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: isObscure ? 'Show password' : 'Hide password',
                                    icon: Icon(isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    onPressed: () => _obscure.value = !isObscure,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF6F8FC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: scheme.primary, width: 1.6)),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 14),

                          // Removed role dropdown

                          const SizedBox(height: 8),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Forgot password coming soon')),
                              ),
                              style: TextButton.styleFrom(foregroundColor: scheme.primary),
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Login button with gradient wrapper
                          SizedBox(
                            height: 52,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [scheme.primary, scheme.secondary]),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x55212121), blurRadius: 12, offset: Offset(0, 6)),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: scheme.onPrimary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                                child: const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Divider
                          Row(
                            children: const [
                              Expanded(child: Divider(thickness: 1, color: Color(0xFFE6E9EF))),
                              SizedBox(width: 8),
                              Text('or', style: TextStyle(color: Colors.black45)),
                              SizedBox(width: 8),
                              Expanded(child: Divider(thickness: 1, color: Color(0xFFE6E9EF))),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Register link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account?",
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                              ),
                              TextButton(
                                onPressed: goToRegister,
                                child: Text(' Register', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

class _CurvedBackdropPainter extends CustomPainter {
  final Color color;
  _CurvedBackdropPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height * 0.35);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.30, size.width * 0.5, size.height * 0.40);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.50, size.width, size.height * 0.45);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
