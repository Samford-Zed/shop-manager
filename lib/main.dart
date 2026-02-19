import 'package:flutter/material.dart';
import 'pages/welcome_page.dart';

// Easily tweak your brand color here
const kBrandOrange = Color(0xFFFF5722); // vivid orange-red (Deep Orange)

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Small delay lets web plugins register their channel listeners before messages arrive.
  // This helps avoid "ChannelBuffers message discarded" logs on web hot restart.
  await Future.delayed(const Duration(milliseconds: 60));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: kBrandOrange, brightness: Brightness.light);

    return MaterialApp(
      title: 'shopstack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFFFEBE0), // lighter orange tint for inputs
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        ),
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const WelcomePage(),
    );
  }
}
