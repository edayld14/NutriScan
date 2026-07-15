import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/analysis.dart';
import '../services/groq_service.dart';
import '../services/translations.dart'; // ÇEVİRİ EKLENTİSİ BURAYA DAHİL EDİLDİ

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final IngredientAnalysisService _analysisService = IngredientAnalysisService();
  final GroqService _groqService = GroqService();

  bool _isLoading = false;
  String _searchResultTitle = "";
  String _searchResultBody = "";
  Color _resultColor = const Color(0xFF4CAF50); // Yeni Yeşil

  @override
  void initState() {
    super.initState();
    _analysisService.loadDataset(); 
  }

  void _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() { _isLoading = true; _searchResultTitle = ""; _searchResultBody = ""; });

    String normalizedQuery = _analysisService.normalize(query);
    var localMatch;

    for (var item in _analysisService.dataset) {
      final nameTr = _analysisService.normalize((item["name_tr"] ?? "").toString());
      final nameEn = _analysisService.normalize((item["name_en"] ?? "").toString());
      final eCode = _analysisService.normalize((item["e_code"] ?? "").toString());

      if (nameTr == normalizedQuery || nameEn == normalizedQuery || eCode == normalizedQuery) {
        localMatch = item; break;
      }
    }

    if (localMatch != null) {
      setState(() {
        // İngilizce ise İngilizce ismini, değilse Türkçe ismini başlık yap
        _searchResultTitle = (AppTranslations.appLang.value == 'en' ? localMatch["name_en"] : localMatch["name_tr"]) ?? localMatch["name_tr"] ?? query;
        List<String> cats = List<String>.from(localMatch["categories"] ?? []);
        String risk = (localMatch["risk_level"] ?? "not_specified".tr).toString();
        
        _searchResultBody = "🏷️ ${'e_code_label'.tr}: ${localMatch["e_code"] ?? 'none'.tr}\n"
            "📊 ${'category_label'.tr}: ${cats.join(', ')}\n"
            "⚠️ ${'risk_level_label'.tr}: ${risk.tr}\n\n"
            "📝 ${'db_explanation'.tr}";
        
        _resultColor = risk == "yuksek" ? Colors.red : (cats.contains("alerjen") ? Colors.orange : const Color(0xFF4CAF50));
        _isLoading = false;
      });
      return;
    }

    try {
      // DİLE GÖRE YAPAY ZEKAYA PROMPT (KOMUT) GÖNDERME
      String langPrompt = AppTranslations.appLang.value == 'en' 
          ? 'Explain what it is and its harms in 3 short sentences as an expert in English.' 
          : 'Bu madde nedir, zararı var mıdır? 3 kısa cümleyle uzman dille Türkçe açıkla.';
          
      String aiResponse = await _groqService.askAi("Kullanıcı gıda paketinde '$query' maddesini gördü ve ne olduğunu merak ediyor. $langPrompt");
      
      setState(() {
        _searchResultTitle = query;
        _searchResultBody = aiResponse;
        _resultColor = const Color(0xFF4CAF50); 
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _searchResultTitle = 'error'.tr; _searchResultBody = 'error_fetching_info'.tr; _resultColor = Colors.grey; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text('search'.tr, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF2D3142),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('search_instruction'.tr, style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF2D3142))),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
              child: TextField(
                controller: _searchController, textInputAction: TextInputAction.search, onSubmitted: (_) => _handleSearch(),
                style: GoogleFonts.montserrat(),
                decoration: InputDecoration(
                  hintText: 'search_hint'.tr,
                  hintStyle: GoogleFonts.montserrat(color: Colors.grey, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF4CAF50)),
                  suffixIcon: IconButton(icon: const Icon(Icons.arrow_circle_right_rounded, color: Color(0xFF4CAF50), size: 30), onPressed: _handleSearch),
                  border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (_isLoading) const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator(color: Color(0xFF4CAF50))))
            else if (_searchResultTitle.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)], border: Border.all(color: _resultColor.withOpacity(0.2), width: 1)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [Icon(Icons.info_outline_rounded, color: _resultColor, size: 26), const SizedBox(width: 8), Expanded(child: Text(_searchResultTitle.toUpperCase(), style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: _resultColor)))]),
                        const Divider(height: 24),
                        Text(_searchResultBody, style: GoogleFonts.montserrat(fontSize: 15, height: 1.6, color: const Color(0xFF2D3142))),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_stories_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('search_ai_fallback'.tr, textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: Colors.grey.shade400, fontSize: 13)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}