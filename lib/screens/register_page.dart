import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nutri_scan_demo/home_page.dart';
import '../services/translations.dart';
import '../services/firebase_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  final List<String> _availableAllergies = ["Süt", "Yer fıstığı", "Glüten", "Yumurta", "Soya", "Deniz Ürünleri", "Kuruyemiş"];
  final List<String> _selectedAllergies = [];
  bool _isLoading = false;

  final Color _bgColor = const Color(0xFFF7F9FC);
  final Color _textColor = const Color(0xFF2D3142);
  final Color _subTextColor = const Color(0xFF9094A6);
  final Color _primaryColor = const Color(0xFF4CAF50); // Yeni Yeşil

  void _register() async {
    if (_fullNameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lütfen adınızı ve e-postanızı girin.', style: GoogleFonts.montserrat())));
      return;
    }

    setState(() => _isLoading = true);
    final user = await _firebaseService.registerWithEmail(
      _emailController.text.trim(), _passwordController.text.trim(), _fullNameController.text.trim(), _selectedAllergies,
    );
    setState(() => _isLoading = false);

    if (user != null && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kayıt Başarısız. Bilgilerinizi kontrol edin.', style: GoogleFonts.montserrat())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text("Kayıt Ol", style: GoogleFonts.montserrat(color: _textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Profilinizi Oluşturun", style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w800, color: _textColor)),
            const SizedBox(height: 8),
            Text("Kişiselleştirilmiş uyarılar için alerjilerinizi seçmeyi unutmayın.", style: GoogleFonts.montserrat(fontSize: 14, color: _subTextColor)),
            const SizedBox(height: 32),
            
            _buildTextField(controller: _fullNameController, hint: "Ad Soyad", icon: Icons.person_outline_rounded),
            const SizedBox(height: 16),
            _buildTextField(controller: _emailController, hint: "E-posta", icon: Icons.email_outlined, isEmail: true),
            const SizedBox(height: 16),
            _buildTextField(controller: _passwordController, hint: "Şifre", icon: Icons.lock_outline_rounded, isPassword: true),
            
            const SizedBox(height: 32),
            Text("Alerjileriniz & Hassasiyetleriniz", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor)),
            const SizedBox(height: 12),
            
            Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              children: _availableAllergies.map((allergy) {
                final isSelected = _selectedAllergies.contains(allergy);
                return FilterChip(
                  label: Text(allergy.tr),
                  selected: isSelected,
                  backgroundColor: Colors.white,
                  selectedColor: _primaryColor.withOpacity(0.15),
                  checkmarkColor: _primaryColor,
                  labelStyle: GoogleFonts.montserrat(color: isSelected ? _primaryColor : _textColor, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? _primaryColor.withOpacity(0.5) : Colors.grey.shade200)),
                  elevation: isSelected ? 0 : 2,
                  shadowColor: Colors.black.withOpacity(0.05),
                  onSelected: (selected) => setState(() => selected ? _selectedAllergies.add(allergy) : _selectedAllergies.remove(allergy)),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 48),
            _isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: _primaryColor.withOpacity(0.4)
                      ),
                      onPressed: _register,
                      child: Text("Kayıt Ol", style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
          ],
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
        style: GoogleFonts.montserrat(color: _textColor, fontWeight: FontWeight.w500),
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