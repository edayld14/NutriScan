import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; 
import 'package:nutri_scan_demo/screens/admin_page.dart';
import 'package:nutri_scan_demo/screens/profile_page.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/analysis.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart'; 
import '../services/groq_service.dart';
import '../services/translations.dart'; 
import '../screens/search_page.dart';
import '../screens/compare_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final picker = ImagePicker();
  final service = IngredientAnalysisService();
  final FirebaseService _firebaseService = FirebaseService(); 
  final TextEditingController _chatController = TextEditingController();
  final GroqService _groqService = GroqService(); 
  final List<Map<String, String>> _chatMessages = [];

  File? _image; 
  String? ocrText; 
  Map<String, dynamic>? result; 
  bool isLoading = false; 
  double _ocrFontSize = 14.0;
  
  List<String> _userAllergies = []; 
  String _userName = ""; 
  bool _isAdmin = false;
  
  bool _sekerHassasiyeti = false; 
  bool _glutenHassasiyeti = false; 
  bool _tuzHassasiyeti = false;
  bool _bebekModuAktif = false; 
  int _bebekAyi = 6;
  bool _vegan = false; 
  bool _vejetaryen = false; 
  bool _koruyucuIstemiyor = false;

  Map<String, dynamic>? _firstProductResult;
  List<String> _favoriteProducts = []; 
  List<String> _blacklistedProducts = [];

  final Color _bgColor = const Color(0xFFF7F9FC); 
  final Color _cardColor = Colors.white; 
  final Color _textColor = const Color(0xFF2D3142); 
  final Color _subTextColor = const Color(0xFF9094A6); 
  final Color _primaryColor = const Color(0xFF4CAF50);

  @override
  void initState() { 
    super.initState(); 
    service.loadDataset(); 
    _loadUserData(); 
    _setupNotifications(); 
  }

  Future<void> _setupNotifications() async { 
    await NotificationService.requestPermission(); 
    await NotificationService.scheduleDailyReminder(); 
  }

  Future<void> _loadUserData() async {
    final userData = await _firebaseService.getUserData();
    if (userData != null && mounted) {
      setState(() {
        _userName = userData['fullName'] ?? "Kullanıcı"; 
        _isAdmin = userData['role'] == 'admin';
        if (userData['allergies'] != null) _userAllergies = List<String>.from(userData['allergies']);
        _sekerHassasiyeti = userData['sekerHassasiyeti'] ?? false; 
        _glutenHassasiyeti = userData['glutenHassasiyeti'] ?? false; 
        _tuzHassasiyeti = userData['tuzHassasiyeti'] ?? false;
        _bebekModuAktif = userData['bebekModuAktif'] ?? false; 
        _bebekAyi = userData['bebekAyi'] ?? 6;
        _vegan = userData['vegan'] ?? false; 
        _vejetaryen = userData['vejetaryen'] ?? false; 
        _koruyucuIstemiyor = userData['koruyucuIstemiyor'] ?? false;
        
        _favoriteProducts = List<String>.from(userData['favorites'] ?? []).map((e) => service.normalize(e)).toList(); 
        _blacklistedProducts = List<String>.from(userData['blacklist'] ?? []).map((e) => service.normalize(e)).toList();
      });
    }
  }

  String _predictProductName(String fullText) {
    if (fullText.trim().isEmpty) return "Bilinmeyen Ürün";
    List<String> lines = fullText.split('\n').where((l) => l.trim().isNotEmpty).toList();
    String firstLine = lines.isNotEmpty ? lines[0] : fullText;
    if (firstLine.toLowerCase().contains("icindekiler")) {
      firstLine = firstLine.replaceAll(RegExp(r'(?i)icindekiler\:?'), '').trim();
    }
    List<String> words = firstLine.split(' ');
    if (words.length > 4) return words.sublist(0, 4).join(' ');
    return firstLine.trim();
  }

  void _openNameInputDialog(String listName, bool isInList) {
    String currentNormalizedText = service.normalize(ocrText ?? "");
    if (isInList) {
      String foundItem = listName == 'favorites' 
          ? _favoriteProducts.firstWhere((e) => currentNormalizedText.contains(e), orElse: () => "") 
          : _blacklistedProducts.firstWhere((e) => currentNormalizedText.contains(e), orElse: () => "");
      if (foundItem.isNotEmpty) _executeToggle(listName, foundItem, true);
      return;
    }
    String predictedName = _predictProductName(ocrText ?? "");
    final TextEditingController nameController = TextEditingController(text: predictedName);

    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
        title: Text(
          listName == 'favorites' ? 'add_fav_title'.tr : 'add_black_title'.tr, 
          style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold)
        ), 
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Text('enter_custom_name'.tr, style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey)), 
            const SizedBox(height: 10), 
            TextField(
              controller: nameController, 
              autofocus: true, 
              style: GoogleFonts.montserrat(), 
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
              )
            )
          ]
        ), 
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('cancel'.tr, style: GoogleFonts.montserrat(color: Colors.grey))
          ), 
          ElevatedButton(
            onPressed: () { 
              String customName = nameController.text.trim(); 
              if (customName.isNotEmpty) { 
                Navigator.pop(context); 
                _executeToggle(listName, customName, false); 
              } 
            }, 
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ), 
            child: Text('save'.tr, style: GoogleFonts.montserrat(color: Colors.white))
          )
        ]
      )
    );
  }

  void _executeToggle(String listName, String productText, bool isInList) async {
    String finalName = service.normalize(productText);
    await _firebaseService.toggleProductInList(listName, finalName, !isInList);
    await _loadUserData(); 
    setState(() {}); 
  }

  void _showAiExplanation(String ingredientName) async {
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (context) => const Center(child: CircularProgressIndicator())
    );
    
    String langPrompt = AppTranslations.appLang.value == 'en' ? 'in English' : 'Türkçe olarak';
    String explanation = await _groqService.askAi("$ingredientName gıda maddesi nedir, zararları nelerdir? $langPrompt açıkla.");
    
    if (!context.mounted) return; 
    Navigator.pop(context); 
    
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.white, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), 
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9, 
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(24), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Text(ingredientName, style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold)), 
              const Divider(), 
              const SizedBox(height: 10), 
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  physics: const BouncingScrollPhysics(),
                  child: Text(explanation, style: GoogleFonts.montserrat(fontSize: 16, height: 1.5)),
                ),
              ), 
              const SizedBox(height: 20), 
              SizedBox(
                width: double.infinity, 
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context), 
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor), 
                  child: Text('cancel'.tr, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold))
                )
              )
            ]
          )
        )
      )
    );
  }

  void _openChatDialog() {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), 
          child: Container(
            height: 500, 
            decoration: const BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))
            ), 
            padding: const EdgeInsets.all(20), 
            child: Column(
              children: [
                Text('ask_assistant'.tr, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)), 
                const Divider(), 
                Expanded(
                  child: ListView.builder(
                    itemCount: _chatMessages.length, 
                    itemBuilder: (context, index) { 
                      final msg = _chatMessages[index]; 
                      final isUser = msg["role"] == "user"; 
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft, 
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4), 
                          padding: const EdgeInsets.all(12), 
                          decoration: BoxDecoration(
                            color: isUser ? _primaryColor.withOpacity(0.15) : Colors.grey[200], 
                            borderRadius: BorderRadius.circular(12)
                          ), 
                          child: Text(msg["content"] ?? "", style: GoogleFonts.montserrat(color: _textColor))
                        )
                      ); 
                    }
                  )
                ), 
                const SizedBox(height: 8), 
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController, 
                        style: GoogleFonts.montserrat(), 
                        decoration: InputDecoration(
                          hintText: 'type_question'.tr, 
                          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24)))
                        )
                      )
                    ), 
                    IconButton(
                      icon: Icon(Icons.send, color: _primaryColor), 
                      onPressed: () async { 
                        String msg = _chatController.text.trim(); 
                        if (msg.isEmpty) return; 
                        
                        _chatController.clear(); 
                        setModalState(() { _chatMessages.add({'role': 'user', 'content': msg}); }); 
                        
                        String langPrompt = AppTranslations.appLang.value == 'en' ? 'Respond in English.' : 'Türkçe cevap ver.'; 
                        String reply = await _groqService.askAi("$msg $langPrompt"); 
                        
                        setModalState(() { _chatMessages.add({'role': 'ai', 'content': reply}); }); 
                      }
                    )
                  ]
                )
              ]
            )
          )
        )
      )
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    bool permissionGranted = false;
    if (source == ImageSource.camera) { 
      final status = await Permission.camera.request(); 
      permissionGranted = status.isGranted; 
    } else { 
      if (Platform.isAndroid) { 
        final statusPhotos = await Permission.photos.request(); 
        final statusStorage = await Permission.storage.request(); 
        permissionGranted = statusPhotos.isGranted || statusStorage.isGranted; 
      } else { 
        final status = await Permission.photos.request(); 
        permissionGranted = status.isGranted; 
      } 
    }
    
    try {
      final XFile? pickedFile = await picker.pickImage(source: source); 
      if (pickedFile == null) return;

      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Etiketi Kırp',
            toolbarColor: _primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            hideBottomControls: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9
            ],
          ),
          IOSUiSettings(
            title: 'Etiketi Kırp',
            doneButtonTitle: 'Bitti',
            cancelButtonTitle: 'İptal',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9
            ],
          ),
        ],
      );

      if (croppedFile == null) return;

      setState(() { _image = File(croppedFile.path); isLoading = true; result = null; });
      
      final text = await service.runOcr(croppedFile.path);
      
      String activeLang = AppTranslations.appLang.value; // DİL DEĞİŞKENİ BURADAN GÖNDERİLİR
      
      final analysis = service.analyze(
        text, 
        userAllergies: _userAllergies, 
        sekerHassasiyeti: _sekerHassasiyeti, 
        glutenHassasiyeti: _glutenHassasiyeti, 
        tuzHassasiyeti: _tuzHassasiyeti, 
        bebekModuAktif: _bebekModuAktif, 
        bebekAyi: _bebekAyi, 
        vegan: _vegan, 
        vejetaryen: _vejetaryen, 
        koruyucuIstemiyor: _koruyucuIstemiyor,
        lang: activeLang // YENİ: DİL PARAMETRESİ EKLENDİ
      );
      
      if (analysis['color'] == 'red' || analysis['color'] == 'yellow') {
        List<String> activeProfiles = [];
        
        // YAPAY ZEKAYA GÖNDERİLECEK BİLGİLERİ DİLE GÖRE TERCÜME ETTİK Kİ YANITI DOĞRU VERSİN
        if (_vegan) activeProfiles.add(activeLang == 'en' ? "On a vegan diet" : "Vegan diyet uyguluyor");
        if (_vejetaryen && !_vegan) activeProfiles.add(activeLang == 'en' ? "On a vegetarian diet" : "Vejetaryen diyet uyguluyor");
        if (_sekerHassasiyeti) activeProfiles.add(activeLang == 'en' ? "Diabetic / Sugar sensitive" : "Şeker hastası / Şeker hassasiyeti var");
        if (_glutenHassasiyeti) activeProfiles.add(activeLang == 'en' ? "Celiac / Gluten sensitive" : "Glüten hassasiyeti / Çölyak var");
        if (_tuzHassasiyeti) activeProfiles.add(activeLang == 'en' ? "High blood pressure / Salt restriction" : "Tansiyon hastası / Tuz kısıtlaması var");
        if (_userAllergies.isNotEmpty) activeProfiles.add((activeLang == 'en' ? "Allergic to: " : "Şunlara alerjisi var: ") + _userAllergies.join(', '));

        String userProfileStr = activeProfiles.isEmpty 
            ? (activeLang == 'en' ? "No specific health restrictions, just wants to eat healthy." : "Özel bir sağlık kısıtlaması yok, sadece sağlıklı beslenmek istiyor.") 
            : activeProfiles.join(', ');
            
        String categoryToAsk = analysis['detectedCategory'];

        String aiAlternative = await _groqService.getHealthyAlternative(categoryToAsk, userProfileStr, activeLang);
        if (aiAlternative.isNotEmpty) {
          analysis['alternatif'] = aiAlternative;
        }
      }

      setState(() { ocrText = text; result = analysis; isLoading = false; });
    } catch (e) { 
      setState(() { ocrText = "Hata: $e"; isLoading = false; }); 
    }
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent, 
      builder: (context) { 
        return Container(
          margin: const EdgeInsets.all(16), 
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)), 
          child: SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8), 
                    decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), 
                    child: const Icon(Icons.camera_alt, color: Colors.blue)
                  ), 
                  title: Text('camera'.tr, style: GoogleFonts.montserrat(color: _textColor, fontWeight: FontWeight.w600)), 
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }
                ), 
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8), 
                    decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle), 
                    child: const Icon(Icons.photo_library, color: Colors.green)
                  ), 
                  title: Text('gallery'.tr, style: GoogleFonts.montserrat(color: _textColor, fontWeight: FontWeight.w600)), 
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }
                ), 
                const SizedBox(height: 10)
              ]
            )
          )
        ); 
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentNormalizedText = service.normalize(ocrText ?? "");
    bool isBlack = _blacklistedProducts.isNotEmpty && _blacklistedProducts.any((product) => currentNormalizedText.contains(product));
    bool isFav = _favoriteProducts.isNotEmpty && _favoriteProducts.any((product) => currentNormalizedText.contains(product));

    return Theme(
      data: Theme.of(context).copyWith(textTheme: GoogleFonts.montserratTextTheme(Theme.of(context).textTheme)),
      child: Scaffold(
        backgroundColor: _bgColor, 
        
        // ÜST BÖLÜM (APP BAR)
        appBar: AppBar(
          elevation: 0, 
          backgroundColor: Colors.transparent, 
          title: Text(
            _userName.isNotEmpty ? "${'hello'.tr}, ${_userName.split(' ')[0]}" : "NutriScan", 
            style: GoogleFonts.montserrat(color: _textColor, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5)
          ), 
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded, color: Colors.black87), 
              onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage())); }
            ),
            const SizedBox(width: 8)
          ]
        ),
        
        // --- DAHA ESTETİK YENİ ALT MENÜ BÖLÜMÜ (İSİMLERİ ÇEVRİLDİ) ---
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: BottomNavigationBar(
              backgroundColor: Colors.white,
              elevation: 0,
              selectedItemColor: _primaryColor,
              unselectedItemColor: Colors.grey.shade400,
              selectedLabelStyle: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600),
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              currentIndex: 0, 
              onTap: (index) {
                if (index == 1) _openChatDialog();
                if (index == 2) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())).then((_) {
                    _loadUserData(); 
                    setState((){}); 
                  });
                }
                if (index == 3 && _isAdmin) {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPage()));
                }
              },
              items: [
                BottomNavigationBarItem(
                  icon: const Padding(padding: EdgeInsets.only(bottom: 6, top: 8), child: Icon(Icons.document_scanner_outlined, size: 24)),
                  activeIcon: const Padding(padding: EdgeInsets.only(bottom: 6, top: 8), child: Icon(Icons.document_scanner_rounded, size: 26)),
                  label: 'scan_tab'.tr, // DİNAMİK ÇEVİRİ EKLENDİ
                ),
                BottomNavigationBarItem(
                  icon: const Padding(padding: EdgeInsets.only(bottom: 6, top: 8), child: Icon(Icons.chat_bubble_outline_rounded, size: 24)),
                  activeIcon: const Padding(padding: EdgeInsets.only(bottom: 6, top: 8), child: Icon(Icons.chat_bubble_rounded, size: 26)),
                  label: 'assistant_tab'.tr, // DİNAMİK ÇEVİRİ EKLENDİ
                ),
                BottomNavigationBarItem(
                  icon: const Padding(padding: EdgeInsets.only(bottom: 6, top: 8), child: Icon(Icons.person_outline_rounded, size: 24)),
                  activeIcon: const Padding(padding: EdgeInsets.only(bottom: 6, top: 8), child: Icon(Icons.person_rounded, size: 26)),
                  label: 'profile'.tr,
                ),
                if (_isAdmin) BottomNavigationBarItem(
                  icon: const Padding(padding: EdgeInsets.only(bottom: 6, top: 8), child: Icon(Icons.admin_panel_settings_outlined, size: 24)),
                  activeIcon: const Padding(padding: EdgeInsets.only(bottom: 6, top: 8), child: Icon(Icons.admin_panel_settings_rounded, size: 26)),
                  label: 'admin_tab'.tr, // DİNAMİK ÇEVİRİ EKLENDİ
                ),
              ],
            ),
          ),
        ),
        
        // KAYAN BUTON (TARAMA BUTONU)
        floatingActionButton: FloatingActionButton.extended(
          elevation: 2, 
          onPressed: _showOptions, 
          backgroundColor: _primaryColor, 
          icon: const Icon(Icons.document_scanner_rounded, color: Colors.white), 
          label: Text('scan_label'.tr, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
        ),
        
        body: isLoading 
          ? Center(child: CircularProgressIndicator(color: _primaryColor)) 
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100), 
              physics: const BouncingScrollPhysics(), 
              child: Column(
                children: [
                  
                  // --- KARA LİSTE UYARISI ---
                  if (result != null && isBlack) 
                    Container(
                      width: double.infinity, 
                      padding: const EdgeInsets.all(12), 
                      margin: const EdgeInsets.only(bottom: 12), 
                      decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(16)), 
                      child: Row(
                        children: [
                          const Icon(Icons.gavel_rounded, color: Colors.white), 
                          const SizedBox(width: 10), 
                          Expanded(child: Text('warning_black_list'.tr, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)))
                        ]
                      )
                    ),
                  
                  // --- 1. ÜRÜN HAFIZA BİLGİSİ ---
                  if (_firstProductResult != null) 
                    Container(
                      width: double.infinity, 
                      padding: const EdgeInsets.all(12), 
                      margin: const EdgeInsets.only(bottom: 12), 
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.withOpacity(0.2))), 
                      child: Row(
                        children: [
                          const Icon(Icons.layers_outlined, color: Colors.blue), 
                          const SizedBox(width: 10), 
                          Expanded(child: Text('product_saved_1'.tr, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue))), 
                          TextButton(
                            onPressed: () => setState(() => _firstProductResult = null), 
                            child: Text('clear'.tr, style: GoogleFonts.montserrat(color: Colors.red, fontWeight: FontWeight.bold))
                          )
                        ]
                      )
                    ),
                  
                  // --- FOTOĞRAF ALANI ---
                  Container(
                    height: 180, 
                    width: double.infinity, 
                    decoration: BoxDecoration(
                      color: _cardColor, 
                      borderRadius: BorderRadius.circular(24), 
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))], 
                      image: _image != null ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover) : null
                    ), 
                    child: _image == null 
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center, 
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16), 
                              decoration: BoxDecoration(color: _bgColor, shape: BoxShape.circle), 
                              child: Icon(Icons.camera_alt_rounded, size: 32, color: _subTextColor)
                            ), 
                            const SizedBox(height: 12), 
                            Text('take_photo'.tr, style: GoogleFonts.montserrat(color: _subTextColor, fontSize: 14))
                          ]
                        ) 
                      : null
                  ),
                  
                  // --- SONUÇLAR VARSA GÖSTERİLECEK ALAN ---
                  if (result != null) ...[
                    const SizedBox(height: 16),
                    
                    // FAVORİ / KARA LİSTE BUTONLARI
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openNameInputDialog('favorites', isFav), 
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: isFav ? Colors.red : Colors.grey.shade300), 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                            ), 
                            icon: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: Colors.red), 
                            label: Text(
                              isFav ? 'fav_in'.tr : 'fav_add'.tr, 
                              style: GoogleFonts.montserrat(color: isFav ? Colors.red : _textColor, fontWeight: FontWeight.bold, fontSize: 12)
                            )
                          )
                        ), 
                        const SizedBox(width: 8), 
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openNameInputDialog('blacklist', isBlack), 
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: isBlack ? Colors.black : Colors.grey.shade300), 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                            ), 
                            icon: Icon(Icons.gavel_rounded, color: isBlack ? Colors.red : Colors.grey), 
                            label: Text(
                              isBlack ? 'black_in'.tr : 'black_add'.tr, 
                              style: GoogleFonts.montserrat(color: isBlack ? Colors.red : _textColor, fontWeight: FontWeight.bold, fontSize: 12)
                            )
                          )
                        )
                      ]
                    ), 
                    const SizedBox(height: 12),
                    
                    // KARŞILAŞTIRMA BUTONU
                    Row(
                      children: [
                        if (_firstProductResult == null) 
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () { 
                                setState(() { 
                                  _firstProductResult = result; 
                                  result = null; 
                                  _image = null; 
                                  ocrText = null; 
                                }); 
                              }, 
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue, 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                              ), 
                              icon: const Icon(Icons.add_to_photos_rounded, color: Colors.white), 
                              label: Text('compare_add'.tr, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold))
                            )
                          ) 
                        else 
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () { 
                                Navigator.push(context, MaterialPageRoute(builder: (context) => ComparePage(product1: _firstProductResult!, product2: result!))); 
                              }, 
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green, 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                              ), 
                              icon: const Icon(Icons.compare_arrows_rounded, color: Colors.white), 
                              label: Text('compare_now'.tr, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold))
                            )
                          )
                      ]
                    ), 
                    const SizedBox(height: 16),
                    
                    // AI ALTERNATİF ÖNERİSİ
                    if (result!["alternatif"].toString().isNotEmpty) ...[
                      Container(
                        width: double.infinity, 
                        padding: const EdgeInsets.all(16), 
                        decoration: BoxDecoration(
                          color: Colors.green.shade50, 
                          borderRadius: BorderRadius.circular(24), 
                          border: Border.all(color: Colors.green.withOpacity(0.2))
                        ), 
                        child: Row(
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded, color: Colors.green, size: 28), 
                            const SizedBox(width: 12), 
                            Expanded(
                              child: Text(
                                result!["alternatif"].toString(), 
                                style: GoogleFonts.montserrat(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.green.shade900)
                              )
                            )
                          ]
                        )
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // BEBEK MODU UYARISI
                    if (_bebekModuAktif && result!["bebek_uyarisi"].toString().isNotEmpty) ...[
                      Container(
                        width: double.infinity, 
                        padding: const EdgeInsets.all(16), 
                        decoration: BoxDecoration(
                          color: result!["bebek_uyarisi"].toString().contains("🚫") || result!["bebek_uyarisi"].toString().contains("Risk") ? Colors.pink.shade50 : Colors.green.shade50, 
                          borderRadius: BorderRadius.circular(24), 
                          border: Border.all(color: Colors.pink.withOpacity(0.2))
                        ), 
                        child: Row(
                          children: [
                            const Icon(Icons.child_care_rounded, color: Colors.pinkAccent, size: 30), 
                            const SizedBox(width: 12), 
                            Expanded(
                              child: Text(
                                result!["bebek_uyarisi"], 
                                style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.pink.shade900)
                              )
                            )
                          ]
                        )
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // HASSASİYET UYARILARI
                    if (result!["hassasiyet_detaylari"] != null && (result!["hassasiyet_detaylari"] as List).isNotEmpty) ...[
                      Container(
                        width: double.infinity, 
                        padding: const EdgeInsets.all(16), 
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50, 
                          borderRadius: BorderRadius.circular(24), 
                          border: Border.all(color: Colors.amber.withOpacity(0.3))
                        ), 
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: (result!["hassasiyet_detaylari"] as List).map((log) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0), 
                            child: Text(log.toString(), style: GoogleFonts.montserrat(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 13))
                          )).toList()
                        )
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // GENEL ANALİZ SONUCU DİNAMİK BAŞLIK DÜZELTİLDİ
                    Container(
                      width: double.infinity, 
                      padding: const EdgeInsets.all(20), 
                      decoration: BoxDecoration(
                        color: _getColor(result!["color"]).withOpacity(0.05), 
                        borderRadius: BorderRadius.circular(24), 
                        border: Border.all(color: _getColor(result!["color"]).withOpacity(0.2), width: 1)
                      ), 
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12), 
                            decoration: BoxDecoration(
                              color: _getColor(result!["color"]).withOpacity(0.15), 
                              shape: BoxShape.circle
                            ), 
                            child: Icon(
                              result!["color"] == "green" ? Icons.check_rounded : result!["color"] == "yellow" ? Icons.warning_rounded : Icons.priority_high_rounded, 
                              size: 28, 
                              color: _getColor(result!["color"])
                            )
                          ), 
                          const SizedBox(width: 16), 
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, 
                              children: [
                                Text('analysis_result'.tr, style: GoogleFonts.montserrat(color: _subTextColor, fontSize: 13)), 
                                const SizedBox(height: 4), 
                                Text(
                                  result!["level"].toString().tr, // DİNAMİK ÇEVİRİ NOKTASI
                                  style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, color: _textColor)
                                )
                              ]
                            )
                          )
                        ]
                      )
                    ),
                    const SizedBox(height: 16),
                    
                    // İÇERİK LİSTELERİ
                    if (result!["user_risk"].isNotEmpty) 
                      _buildList('profile_allergy_warning'.tr, result!["user_risk"], Colors.red, isAlert: true),
                    
                    _buildList('allergens'.tr, result!["alerjen"], Colors.red), 
                    _buildList('additives'.tr, result!["katki"], Colors.orange), 
                    _buildList('high_risk'.tr, result!["risk"], Colors.purple),
                    
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.black12, height: 1)),
                    
                    // TARANAN METİN
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                      children: [
                        Text('scanned_text'.tr, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 16, color: _textColor)), 
                        Row(
                          children: [
                            Icon(Icons.text_decrease_rounded, size: 18, color: _subTextColor), 
                            SizedBox(
                              width: 100, 
                              child: Slider(
                                value: _ocrFontSize, 
                                min: 12.0, max: 22.0, 
                                activeColor: _primaryColor, 
                                inactiveColor: _primaryColor.withOpacity(0.2), 
                                onChanged: (value) => setState(() => _ocrFontSize = value)
                              )
                            )
                          ]
                        )
                      ]
                    ),
                    const SizedBox(height: 12),
                    
                    Container(
                      padding: const EdgeInsets.all(20), 
                      width: double.infinity, 
                      decoration: BoxDecoration(
                        color: _cardColor, 
                        borderRadius: BorderRadius.circular(24), 
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
                      ), 
                      child: ocrText == null 
                        ? Text(ocrText ?? "", style: GoogleFonts.montserrat(fontSize: _ocrFontSize, color: _textColor)) 
                        : Builder(builder: (context) { 
                            List<String> allRisks = []; 
                            allRisks.addAll(List<String>.from(result!["alerjen"] ?? [])); 
                            allRisks.addAll(List<String>.from(result!["katki"] ?? [])); 
                            allRisks.addAll(List<String>.from(result!["risk"] ?? [])); 
                            allRisks.addAll(List<String>.from(result!["user_risk"] ?? [])); 
                            List<String> words = ocrText!.split(RegExp(r'\s+')); 
                            
                            return RichText(
                              text: TextSpan(
                                style: GoogleFonts.montserrat(fontSize: _ocrFontSize, color: _textColor, height: 1.6, letterSpacing: 0.2), 
                                children: words.map((word) { 
                                  String cleanWord = service.normalize(word.replaceAll(RegExp(r'[^a-zA-ZçğıöşüÇĞİÖŞÜ]'), '')); 
                                  bool isHighlighted = allRisks.any((risk) => service.isFuzzyMatch(cleanWord, service.normalize(risk))); 
                                  return TextSpan(
                                    text: "$word ", 
                                    style: isHighlighted ? TextStyle(backgroundColor: Colors.red.shade50, color: Colors.red.shade700, fontWeight: FontWeight.bold) : null
                                  ); 
                                }).toList()
                              )
                            ); 
                          })
                    ),
                    
                    // TIBBİ TAVSİYE DEĞİLDİR UYARISI
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text('medical_disclaimer'.tr, style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ], 
                ], 
              ), 
            ), 
      ),
    );
  }

  Color _getColor(String colorName) { 
    if (colorName == "green") return const Color(0xFF4CAF50); 
    if (colorName == "yellow") return const Color(0xFFFF9800); 
    return const Color(0xFFE53935); 
  }

  Widget _buildList(String title, List items, MaterialColor color, {bool isAlert = false}) { 
    if (items.isEmpty) return const SizedBox.shrink(); 
    return Padding(
      padding: const EdgeInsets.only(bottom: 12), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14, color: isAlert ? Colors.red : _subTextColor)), 
          const SizedBox(height: 8), 
          Wrap(
            spacing: 8, 
            runSpacing: 8, 
            children: items.map((e) => GestureDetector(
              onTap: () => _showAiExplanation(e), 
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                decoration: BoxDecoration(
                  color: isAlert ? Colors.red.shade50 : color.withOpacity(0.08), 
                  borderRadius: BorderRadius.circular(12), 
                  border: Border.all(color: isAlert ? Colors.red.shade100 : color.withOpacity(0.2))
                ), 
                child: Row(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    Text(e, style: GoogleFonts.montserrat(color: isAlert ? Colors.red.shade700 : color.shade700, fontWeight: FontWeight.w600, fontSize: 13)), 
                    const SizedBox(width: 4), 
                    Icon(Icons.info_outline, size: 12, color: color.shade700)
                  ]
                )
              )
            )).toList()
          )
        ]
      )
    ); 
  }
}