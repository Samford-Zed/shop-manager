import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'welcome_page.dart';
import '../config/api.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final ValueNotifier<bool> _obscure = ValueNotifier<bool>(true);

  final String baseUrl = ApiConfig.baseUrl;

  Future<void> register() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          // role removed from client-side registration to prevent self-assigning roles
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Please login.')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Registration failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Server error: $e')),
      );
    }
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
    usernameController.dispose();
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
          'Register',
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
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFEBE0), Color(0xFFFFCCBC)],
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -60,
            child: _GradientBlob(
              size: 220,
              colors: const [Color(0xFFFFD1C4), Color(0xFFFFE6DE)],
            ),
          ),
          Positioned(
            bottom: -90,
            right: -70,
            child: _GradientBlob(
              size: 260,
              colors: const [Color(0xFFFF8A65), Color(0xFFFFD7C7)],
            ),
          ),

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
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33212121),
                            blurRadius: 20,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              height: 52,
                              width: 52,
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.person_add_alt_1_outlined, color: scheme.primary),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Create Owner Account',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Public registration creates an OWNER. Cashiers are added by Owner only.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                          ),

                          const SizedBox(height: 24),

                          /// Username
                          TextField(
                            controller: usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person_outline),
                              filled: true,
                            ),
                          ),

                          const SizedBox(height: 14),

                          /// Password
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
                                    icon: Icon(
                                      isObscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => _obscure.value = !isObscure,
                                  ),
                                  filled: true,
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 18),

                          SizedBox(
                            height: 50,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [scheme.primary, scheme.secondary]),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ElevatedButton(
                                onPressed: register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent, // keep gradient
                                  shadowColor: Colors.transparent,
                                  foregroundColor: scheme.onPrimary, // ✅ ensures text is visible
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text(
                                  'Register',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),


                          const SizedBox(height: 18),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Already have an account?'),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => const LoginPage()),
                                  );
                                },
                                child: const Text(' Login'),
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

/* ================= Decorative Blob ================= */

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
