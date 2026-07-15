import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nutri_scan_demo/home_page.dart';
import '../services/firebase_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // Tasarım Renkleri (Logodaki konsept)
  final Color _bgColor = const Color(0xFFF7F9FC);
  final Color _textColor = const Color(0xFF2D3142);
  final Color _subTextColor = const Color(0xFF9094A6);
  final Color _primaryColor = const Color(0xFF4CAF50); // Logo Yeşili

  void _login() async {
    setState(() => _isLoading = true);
    final user = await _firebaseService.loginWithEmail(_emailController.text.trim(), _passwordController.text.trim());
    setState(() => _isLoading = false);

    if (user != null && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Giriş Başarısız. E-posta veya şifre hatalı.', style: GoogleFonts.montserrat())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- KENDİ TASARLADIĞIN PNG LOGO ALANI ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  // asset içindeki logonu çağırıyoruz
                  child: Image.asset(
                    'assets/logo.png',
                    height: 100, // Logonun boyutunu buradan ayarlayabilirsin
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                
                Text("Akıllı Gıda Analizi", style: GoogleFonts.montserrat(fontSize: 15, color: _subTextColor, fontWeight: FontWeight.w600)),
                const SizedBox(height: 48),

                // Form Alanı
                _buildTextField(controller: _emailController, hint: "E-posta", icon: Icons.email_outlined, isEmail: true),
                const SizedBox(height: 16),
                _buildTextField(controller: _passwordController, hint: "Şifre", icon: Icons.lock_outline_rounded, isPassword: true),
                const SizedBox(height: 32),
                
                _isLoading
                    ? CircularProgressIndicator(color: _primaryColor)
                    : SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            elevation: 4,
                            shadowColor: _primaryColor.withOpacity(0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _login,
                          child: Text("Giriş Yap", style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())),
                  child: Text("Hesabın yok mu? Hemen Kayıt Ol", style: GoogleFonts.montserrat(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, required IconData icon, bool isPassword = false, bool isEmail = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        style: GoogleFonts.montserrat(color: _textColor, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.montserrat(color: _subTextColor),
          prefixIcon: Icon(icon, color: _subTextColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}