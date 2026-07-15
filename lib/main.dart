import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Oturum kontrolü için eklendi
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'firebase_options.dart';

import 'screens/login_page.dart';
import 'home_page.dart'; // Otomatik yönlendirme için ana sayfa importu eklendi
import 'services/notification_service.dart';
import 'services/translations.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder dil değiştiğinde tüm UI'ı anında yeniler!
    return ValueListenableBuilder<String>(
      valueListenable: AppTranslations.appLang,
      builder: (context, lang, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'NutriScan',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
            textTheme: GoogleFonts.montserratTextTheme(Theme.of(context).textTheme),
            useMaterial3: true,
          ),
          // --- OTOMATİK OTURUM (GİRİŞ) KONTROLÜ ---
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              // Firebase cihazın önbelleğini kontrol edene kadar bekleme animasyonu
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  ),
                );
              }
              
              // Eğer önbellekte giriş yapmış bir kullanıcı (Token) varsa direkt HomePage'e at
              if (snapshot.hasData) {
                return const HomePage();
              }
              
              // Eğer oturum açılmamışsa veya kişi çıkış yaptıysa Login sayfasını göster
              return const LoginPage();
            },
          ),
        );
      }
    );
  }
}