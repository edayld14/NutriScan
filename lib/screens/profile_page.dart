import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';
import '../services/groq_service.dart';
import '../services/translations.dart'; 
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseService _firebaseService = FirebaseService();
  final GroqService _groqService = GroqService();
  final TextEditingController _allergyController = TextEditingController();

  bool _isLoading = true;

  String _fullName = ""; 
  String _email = "";
  
  bool _sekerHassasiyeti = false; 
  bool _glutenHassasiyeti = false; 
  bool _tuzHassasiyeti = false;
  bool _vegan = false; 
  bool _vejetaryen = false; 
  bool _koruyucuIstemiyor = false;
  bool _bebekModuAktif = false; 
  int _bebekAyi = 6;

  List<String> _allergies = [];
  List<String> _favoriteProducts = []; 
  List<String> _blacklistedProducts = [];

  final Color _primaryGreen = const Color(0xFF4CAF50);
  final Color _bgColor = const Color(0xFFF4F7FA); 
  final Color _textColor = const Color(0xFF2D3142);

  @override
  void initState() { 
    super.initState(); 
    _loadProfileData(); 
  }

  @override
  void dispose() {
    _allergyController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final data = await _firebaseService.getUserData();
    if (data != null && mounted) {
      setState(() {
        _fullName = data['fullName'] ?? "Kullanıcı";
        _email = data['email'] ?? "";
        _sekerHassasiyeti = data['sekerHassasiyeti'] ?? false;
        _glutenHassasiyeti = data['glutenHassasiyeti'] ?? false;
        _tuzHassasiyeti = data['tuzHassasiyeti'] ?? false;
        _vegan = data['vegan'] ?? false;
        _vejetaryen = data['vejetaryen'] ?? false;
        _koruyucuIstemiyor = data['koruyucuIstemiyor'] ?? false;
        _bebekModuAktif = data['bebekModuAktif'] ?? false;
        _bebekAyi = data['bebekAyi'] ?? 6;
        _allergies = List<String>.from(data['allergies'] ?? []);
        _favoriteProducts = List<String>.from(data['favorites'] ?? []);
        _blacklistedProducts = List<String>.from(data['blacklist'] ?? []);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _changeLanguage(String langCode) {
    AppTranslations.appLang.value = langCode; 
    setState(() {}); 
  }

  void _addAllergy() async {
    if (_allergyController.text.isNotEmpty) {
      setState(() {
        _allergies.add(_allergyController.text.trim());
      });
      _allergyController.clear();
      await _firebaseService.updateUserAllergies(_allergies);
    }
  }

  void _removeAllergy(String allergy) async {
    setState(() {
      _allergies.remove(allergy);
    });
    await _firebaseService.updateUserAllergies(_allergies);
  }

  void _showAdminMessageDialog() {
    final TextEditingController msgController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('contact_admin'.tr, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: msgController,
          maxLines: 3,
          style: GoogleFonts.montserrat(),
          decoration: InputDecoration(
            hintText: 'type_message'.tr, 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr, style: GoogleFonts.montserrat(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              if (msgController.text.isNotEmpty) {
                await _firebaseService.sendMessageToAdmin(msgController.text.trim());
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('message_sent'.tr, style: GoogleFonts.montserrat()), backgroundColor: Colors.blueAccent));
              }
            },
            child: Text('send_message'.tr, style: GoogleFonts.montserrat(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _toggleSensitivity(String key, bool currentValue) async {
    setState(() {
      if (key == 'sekerHassasiyeti') _sekerHassasiyeti = !currentValue;
      else if (key == 'glutenHassasiyeti') _glutenHassasiyeti = !currentValue;
      else if (key == 'tuzHassasiyeti') _tuzHassasiyeti = !currentValue;
      else if (key == 'vegan') { _vegan = !currentValue; if (_vegan) _vejetaryen = false; }
      else if (key == 'vejetaryen') { _vejetaryen = !currentValue; if (_vejetaryen) _vegan = false; }
      else if (key == 'koruyucuIstemiyor') _koruyucuIstemiyor = !currentValue;
    });
    await _firebaseService.updateUserData({key: !currentValue});
    if (key == 'vegan' && _vegan) await _firebaseService.updateUserData({'vejetaryen': false});
    if (key == 'vejetaryen' && _vejetaryen) await _firebaseService.updateUserData({'vegan': false});
  }

  void _toggleBabyMode(bool value) async {
    setState(() => _bebekModuAktif = value);
    await _firebaseService.updateUserData({'bebekModuAktif': value});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: _bgColor, body: Center(child: CircularProgressIndicator(color: _primaryGreen)));
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: _textColor),
        centerTitle: false,
        titleSpacing: 0,
        title: Text('profile'.tr, style: GoogleFonts.montserrat(color: _textColor, fontWeight: FontWeight.bold, fontSize: 22)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KULLANICI BİLGİLERİ 
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: _primaryGreen.withOpacity(0.15), shape: BoxShape.circle),
                    child: CircleAvatar(radius: 40, backgroundColor: _primaryGreen.withOpacity(0.2), child: Icon(Icons.person_rounded, size: 45, color: _primaryGreen)),
                  ),
                  const SizedBox(height: 16),
                  Text(_fullName, style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: _textColor)),
                  const SizedBox(height: 4),
                  Text(_email, style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // DİL SEÇİMİ 
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.language_rounded, color: Colors.blue.shade400, size: 22),
                      const SizedBox(width: 12),
                      Text('Dil / Language', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: _textColor, fontSize: 15)),
                    ],
                  ),
                  DropdownButton<String>(
                    value: AppTranslations.appLang.value,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: _textColor),
                    items: const [
                      DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (val) => _changeLanguage(val!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // HASSASİYETLER BAŞLIĞI
            Text('health_sens'.tr, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                _buildToggleCard('sugar_sens'.tr, Icons.bloodtype, _sekerHassasiyeti, () => _toggleSensitivity('sekerHassasiyeti', _sekerHassasiyeti), Colors.red),
                _buildToggleCard('gluten_sens'.tr, Icons.grass_rounded, _glutenHassasiyeti, () => _toggleSensitivity('glutenHassasiyeti', _glutenHassasiyeti), Colors.orange),
                _buildToggleCard('salt_sens'.tr, Icons.water_drop_rounded, _tuzHassasiyeti, () => _toggleSensitivity('tuzHassasiyeti', _tuzHassasiyeti), Colors.blue),
                _buildToggleCard('vegan'.tr, Icons.eco_rounded, _vegan, () => _toggleSensitivity('vegan', _vegan), Colors.green),
                _buildToggleCard('veg'.tr, Icons.nature_people_rounded, _vejetaryen, () => _toggleSensitivity('vejetaryen', _vejetaryen), Colors.teal),
                _buildToggleCard('nopres'.tr, Icons.shield_rounded, _koruyucuIstemiyor, () => _toggleSensitivity('koruyucuIstemiyor', _koruyucuIstemiyor), Colors.purple),
              ],
            ),
            const SizedBox(height: 24),

            // BEBEK MODU KARTI 
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [Icon(Icons.child_care_rounded, color: Colors.pink.shade500, size: 28), const SizedBox(width: 10), Text('baby_profile'.tr, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink.shade700))]),
                      Switch(value: _bebekModuAktif, activeColor: Colors.pink, onChanged: _toggleBabyMode),
                    ],
                  ),
                  if (_bebekModuAktif) ...[
                    const SizedBox(height: 16),
                    Text('sel_age'.tr, style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.pink.shade900)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
                      child: Row(children: [
                        _buildBabyMonthCard(6, 'rolling'.tr, Colors.pink.shade50, Colors.pink),
                        _buildBabyMonthCard(9, 'crawling'.tr, Colors.purple.shade50, Colors.purple),
                        _buildBabyMonthCard(12, 'walking'.tr, Colors.deepPurple.shade50, Colors.deepPurple),
                        _buildBabyMonthCard(24, 'talking'.tr, Colors.indigo.shade50, Colors.indigo),
                      ]),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 24),

            // DİNAMİK ALERJİLERİM BÖLÜMÜ 
            Text('allergies'.tr, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_allergies.isEmpty)
                    Text('no_allergy'.tr, style: GoogleFonts.montserrat(color: Colors.grey, fontStyle: FontStyle.italic))
                  else
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _allergies.map((a) => Chip(
                        label: Text(a.tr, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.red.shade400)),
                        backgroundColor: Colors.red.shade50,
                        deleteIcon: const Icon(Icons.cancel, size: 18),
                        deleteIconColor: Colors.red.shade400,
                        side: BorderSide(color: Colors.red.shade100),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onDeleted: () => _removeAllergy(a),
                      )).toList(),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _allergyController, 
                          style: GoogleFonts.montserrat(),
                          decoration: InputDecoration(
                            hintText: 'add_allergy'.tr, 
                            hintStyle: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey.shade500),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
                          )
                        )
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(color: _primaryGreen, borderRadius: BorderRadius.circular(12)),
                        child: IconButton(icon: const Icon(Icons.add_rounded, color: Colors.white), onPressed: _addAllergy),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // KAYITLI LİSTELERİM 
            Text('saved_lists'.tr, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildListCard('favs'.tr, _favoriteProducts, 'favorites', Icons.favorite_rounded, Colors.red)),
                const SizedBox(width: 16),
                Expanded(child: _buildListCard('black_list_short'.tr, _blacklistedProducts, 'blacklist', Icons.gavel_rounded, Colors.black87)),
              ],
            ),
            const SizedBox(height: 24),

            // ADMİNE MESAJ BUTONU 
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _showAdminMessageDialog,
                icon: const Icon(Icons.support_agent_rounded, size: 24),
                label: Text('contact_admin'.tr, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent, 
                  foregroundColor: Colors.white, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // ÇIKIŞ VE SİLME BUTONLARI
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async { 
                  await _firebaseService.signOut(); 
                  if (!context.mounted) return; 
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())); 
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.orange),
                label: Text('logout'.tr, style: GoogleFonts.montserrat(color: Colors.orange, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                )
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('delete_warning'.tr, style: GoogleFonts.montserrat()), backgroundColor: Colors.red));
                },
                icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                label: Text('delete_account'.tr, style: GoogleFonts.montserrat(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                )
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- WİDGET YARDIMCILARI ---

  Widget _buildToggleCard(String title, IconData icon, bool isActive, VoidCallback onTap, MaterialColor color) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: (MediaQuery.of(context).size.width - 52) / 2,
        height: 110, 
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? color.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? color.shade400 : Colors.transparent, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            Icon(icon, size: 32, color: isActive ? color.shade600 : Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              title, 
              textAlign: TextAlign.center, 
              maxLines: 2, 
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.bold, color: isActive ? color.shade900 : Colors.grey.shade600)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBabyMonthCard(int month, String label, Color bgColor, Color fgColor) {
    bool isSelected = _bebekAyi == month;
    return GestureDetector(
      onTap: () async {
        setState(() => _bebekAyi = month);
        await _firebaseService.updateUserData({'bebekAyi': month});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 12),
        width: 100,
        decoration: BoxDecoration(
          color: isSelected ? fgColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? fgColor : Colors.grey.shade200, width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: isSelected ? fgColor.withOpacity(0.8) : bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
              child: Text("$month. ${'months'.tr.split(' ')[0]}", textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: isSelected ? Colors.white : fgColor, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(Icons.face_retouching_natural_rounded, color: isSelected ? Colors.white : Colors.grey.shade600, size: 28),
                  const SizedBox(height: 6),
                  Text(label, textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.grey.shade700)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(String title, List<String> items, String listType, IconData icon, Color color) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductListPage(title: title, items: items, listType: listType, icon: icon, color: color)));
        _loadProfileData(); 
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700)), const SizedBox(height: 4), Text("${items.length} ${'product_count'.tr}", style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.bold, color: _textColor))])),
          ],
        ),
      ),
    );
  }
}

// --- LİSTELENEN ÜRÜNLERİ GÖSTEREN SAYFA ---
class ProductListPage extends StatefulWidget {
  final String title;
  final List<String> items;
  final String listType;
  final IconData icon;
  final Color color;

  const ProductListPage({super.key, required this.title, required this.items, required this.listType, required this.icon, required this.color});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  late List<String> _localItems;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() { super.initState(); _localItems = List.from(widget.items); }

  void _removeItem(String item) async {
    setState(() => _localItems.remove(item));
    await _firebaseService.toggleProductInList(widget.listType, item, false);
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('item_removed'.tr, style: GoogleFonts.montserrat()), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(title: Text(widget.title, style: GoogleFonts.montserrat(color: const Color(0xFF2D3142), fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Color(0xFF2D3142))),
      body: _localItems.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text('empty_list'.tr, style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 16))]))
          : ListView.builder(
              padding: const EdgeInsets.all(20), physics: const BouncingScrollPhysics(), itemCount: _localItems.length,
              itemBuilder: (context, index) {
                final item = _localItems[index];
                return Card(
                  elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(backgroundColor: widget.color.withOpacity(0.1), child: Icon(widget.icon, color: widget.color)),
                    title: Text(item.toUpperCase(), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF2D3142))),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red), onPressed: () => _removeItem(item)),
                  ),
                );
              },
            ),
    );
  }
}