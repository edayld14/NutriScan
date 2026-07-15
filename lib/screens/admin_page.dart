import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final FirebaseService _firebaseService = FirebaseService();
  
  final TextEditingController _nameTrController = TextEditingController();
  final TextEditingController _nameEnController = TextEditingController();
  final TextEditingController _eCodeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _selectedRiskLevel = 'dusuk';
  String _selectedType = 'food';
  final List<String> _selectedCategories = [];

  final List<String> _riskLevels = ['dusuk', 'orta', 'dikkat', 'yuksek'];
  final List<String> _types = ['food', 'additive', 'cosmetic'];
  final List<String> _availableCategories = ['temel', 'alerjen', 'katki', 'yuksek_risk'];

  bool _isLoading = false;

  final Color _bgColor = const Color(0xFFF7F9FC);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF2D3142);
  final Color _adminColor = const Color(0xFF4CAF50); // Yönetici yeşili

  void _submitNewIngredient() async {
    if (_nameTrController.text.isEmpty || _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Türkçe adı ve kategori zorunludur.', style: GoogleFonts.montserrat())));
      return;
    }

    setState(() => _isLoading = true);
    Map<String, dynamic> newIngredient = {
      'id': _nameEnController.text.toLowerCase().replaceAll(' ', '_'),
      'name_tr': _nameTrController.text.trim(),
      'name_en': _nameEnController.text.trim(),
      'e_code': _eCodeController.text.trim().isEmpty ? null : _eCodeController.text.trim(),
      'type': _selectedType,
      'categories': _selectedCategories,
      'risk_level': _selectedRiskLevel,
      'note_tr': _noteController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    bool success = await _firebaseService.addNewIngredientAsAdmin(newIngredient);
    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        _nameTrController.clear(); _nameEnController.clear(); _eCodeController.clear(); _noteController.clear();
        setState(() => _selectedCategories.clear());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Veritabanına eklendi!', style: GoogleFonts.montserrat()), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata oluştu.', style: GoogleFonts.montserrat()), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          title: Text("Yönetici Paneli", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          backgroundColor: _textColor, // Koyu gri appBar
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            labelColor: _adminColor,
            unselectedLabelColor: Colors.white70,
            indicatorColor: _adminColor,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(icon: Icon(Icons.add_box_rounded), text: "Veri Ekle"),
              Tab(icon: Icon(Icons.forum_rounded), text: "Gelen İstekler"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAddDataForm(),
            _buildMessagesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddDataForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Sisteme İçerik Ekle", style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w800, color: _textColor)),
          const SizedBox(height: 20),
          _buildAdminField(controller: _nameTrController, label: "Türkçe Adı (Örn: Soya Lesitini)"),
          const SizedBox(height: 12),
          _buildAdminField(controller: _nameEnController, label: "İngilizce Adı (Örn: Soy lecithin)"),
          const SizedBox(height: 12),
          _buildAdminField(controller: _eCodeController, label: "E-Kodu (Yoksa boş bırakın)"),
          const SizedBox(height: 12),
          _buildAdminField(controller: _noteController, label: "Uyarı / Açıklama Metni", maxLines: 2),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildDropdown(value: _selectedRiskLevel, label: "Risk", items: _riskLevels, onChanged: (v) => setState(() => _selectedRiskLevel = v!))),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown(value: _selectedType, label: "Tip", items: _types, onChanged: (v) => setState(() => _selectedType = v!))),
            ],
          ),
          const SizedBox(height: 24),
          Text("Kategoriler (Çoklu Seçim):", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: _textColor)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8.0, runSpacing: 8.0,
            children: _availableCategories.map((cat) {
              final isSelected = _selectedCategories.contains(cat);
              return FilterChip(
                label: Text(cat, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                selected: isSelected,
                backgroundColor: Colors.white,
                selectedColor: _adminColor.withOpacity(0.15),
                checkmarkColor: _adminColor,
                labelStyle: TextStyle(color: isSelected ? _adminColor : _textColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? _adminColor.withOpacity(0.5) : Colors.grey.shade200)),
                onSelected: (s) => setState(() => s ? _selectedCategories.add(cat) : _selectedCategories.remove(cat)),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          _isLoading
              ? Center(child: CircularProgressIndicator(color: _adminColor))
              : SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _adminColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    onPressed: _submitNewIngredient,
                    icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                    label: Text("Veritabanına Kaydet", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildAdminField({required TextEditingController controller, required String label, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: TextField(
        controller: controller, maxLines: maxLines, style: GoogleFonts.montserrat(color: _textColor),
        decoration: InputDecoration(labelText: label, labelStyle: GoogleFonts.montserrat(color: Colors.grey.shade600), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), contentPadding: const EdgeInsets.all(16)),
      ),
    );
  }

  Widget _buildDropdown({required String value, required String label, required List<String> items, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, isExpanded: true, icon: Icon(Icons.keyboard_arrow_down, color: _adminColor),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i.toUpperCase(), style: GoogleFonts.montserrat(color: _textColor, fontWeight: FontWeight.w600, fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('admin_messages').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: _adminColor));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text("Gelen istek bulunmuyor.", style: GoogleFonts.montserrat()));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var msgData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            var timestamp = msgData['timestamp'] as Timestamp?;
            var dateStr = timestamp != null ? "${timestamp.toDate().day}/${timestamp.toDate().month} - ${timestamp.toDate().hour}:${timestamp.toDate().minute}" : "";

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _adminColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.mark_email_unread_rounded, color: _adminColor, size: 20)),
                      const SizedBox(width: 12),
                      // BURASI DÜZELTİLDİ: 'email' yerine 'userEmail' yazıldı.
                      Expanded(child: Text(msgData['userEmail'] ?? 'Anonim', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: _textColor, fontSize: 15))),
                      Text(dateStr, style: GoogleFonts.montserrat(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                  Text(msgData['message'] ?? '', style: GoogleFonts.montserrat(color: _textColor, fontSize: 14, height: 1.5)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}