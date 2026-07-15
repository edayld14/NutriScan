import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img; 
import 'package:path_provider/path_provider.dart';

import 'firebase_service.dart'; 

class IngredientAnalysisService {
  List<dynamic> dataset = [];
  final FirebaseService _firebaseService = FirebaseService(); 

  Future<void> loadDataset() async {
    try {
      final jsonStr = await rootBundle.loadString("assets/ingredients.json");
      List<dynamic> localData = json.decode(jsonStr);
      List<dynamic> dynamicData = await _firebaseService.getDynamicIngredients();
      dataset = [...localData, ...dynamicData]; 
    } catch (e) {
      dataset = []; 
    }
  }

  Future<String> preprocessImage(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return imagePath;

      if (originalImage.width > 1200) {
        originalImage = img.copyResize(originalImage, width: 1200);
      }

      img.grayscale(originalImage);
      img.gaussianBlur(originalImage, radius: 1); 
      img.adjustColor(originalImage, contrast: 2.0, brightness: 1.2); 

      final directory = await getTemporaryDirectory();
      final tempPath = '${directory.path}/optimized_ocr.jpg';
      await File(tempPath).writeAsBytes(img.encodeJpg(originalImage));
      return tempPath;
    } catch (e) { return imagePath; }
  }

  Future<String> runOcr(String imagePath) async {
    final processedImagePath = await preprocessImage(imagePath);
    final inputImage = InputImage.fromFilePath(processedImagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final result = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();
    
    // Noktalamaları temizle ama kelime boşluklarını koru
    String cleanText = result.text.replaceAll(RegExp(r'[^a-zA-ZçğıöşüÇĞİÖŞÜ0-9\s]'), ' ');
    return cleanText.toLowerCase();
  }

  String normalize(String text) {
    return text.toLowerCase()
      .replaceAll('ç', 'c').replaceAll('ğ', 'g')
      .replaceAll('ı', 'i').replaceAll('i', 'i')
      .replaceAll('ö', 'o').replaceAll('ş', 's').replaceAll('ü', 'u');
  }

  int levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);
    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce(min);
      }
      for (int j = 0; j < v0.length; j++) v0[j] = v1[j];
    }
    return v1[t.length];
  }

  // --- KUSURSUZ EŞLEŞTİRME (KAFEİN/KAZEİN ve GLİKOZ/GLUKOZ KORUMASI) ---
  bool isFuzzyMatch(String text, String target) {
    if (target.isEmpty) return false;
    
    String cleanTextFull = normalize(text);
    String cleanTargetFull = normalize(target);
    
    // 1. KESİN KELİME EŞLEŞMESİ (\b sayesinde "paket" içindeki "et"i atlar)
    if (RegExp(r'\b' + RegExp.escape(cleanTargetFull) + r'\b').hasMatch(cleanTextFull)) return true;

    // 2. KAYAN PENCERE (Sliding Window) ve BULANIK EŞLEŞME
    List<String> textWords = cleanTextFull.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    List<String> targetWords = cleanTargetFull.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (targetWords.isEmpty || textWords.isEmpty) return false;
    
    int windowSize = targetWords.length;
    String targetClean = targetWords.join(' ');
    
    for (int i = 0; i <= textWords.length - windowSize; i++) {
      String windowText = textWords.sublist(i, i + windowSize).join(' ');

      // --- DÜZELTİLEN YANLIŞ POZİTİF KORUMALARI ---
      // Kafein ve Kazein birbirini tetiklemesin
      if (targetClean.contains("kazein") && windowText.contains("kafein")) continue;
      if (targetClean.contains("kafein") && windowText.contains("kazein")) continue;
      
      // Glukoz ve Glikoz birbirini tetikleyip ekrana ikisini birden basmasın
      if (targetClean.contains("glukoz") && windowText.contains("glikoz")) continue;
      if (targetClean.contains("glikoz") && windowText.contains("glukoz")) continue;

      int distance = levenshteinDistance(windowText, targetClean);
      int maxLen = max(windowText.length, targetClean.length);
      
      double similarity = (1.0 - (distance / maxLen)) * 100;

      if (similarity >= 82.0) {
         // KISA KELİME KORUMASI: "gam" veya "et" gibi kelimelerin hatasız tam eşleşmesini şart koşar
         if (targetClean.length <= 5 && distance > 0) continue;
         
         return true; 
      }
    }
    return false;
  }

  // --- MAKRO ÇIKARMA ---
  Map<String, String> extractMacros(String text) {
    String cleanText = normalize(text).replaceAll('\n', ' ');

    String? findNextNumber(String keyword, {bool skipDoymus = false, bool isEnergy = false}) {
      int startIndex = 0;
      while (true) {
        int idx = cleanText.indexOf(keyword, startIndex);
        if (idx == -1) break;

        if (skipDoymus) {
          int checkIdx = max(0, idx - 15);
          String preceding = cleanText.substring(checkIdx, idx);
          if (preceding.contains("doymus") || preceding.contains("doymuş")) {
            startIndex = idx + keyword.length;
            continue;
          }
        }

        String afterText = cleanText.substring(idx + keyword.length, min(cleanText.length, idx + keyword.length + 40));
        Iterable<Match> matches = RegExp(r'(<)?(\d+(?:[\.,]\d+)?)').allMatches(afterText);
        
        if (matches.isNotEmpty) {
          if (isEnergy) {
            List<double> energyVals = [];
            for (var m in matches) {
              double? val = double.tryParse(m.group(2)!.replaceAll(',', '.'));
              if (val != null && val > 0 && val < 1000) energyVals.add(val);
            }
            if (energyVals.isNotEmpty) {
              return "${energyVals.reduce(min).toInt()} kcal";
            }
          } else {
            for (var m in matches) {
               String prefix = m.group(1) ?? ""; 
               String numStr = m.group(2)!;
               double? val = double.tryParse(numStr.replaceAll(',', '.'));
               if (val != null && val <= 100) {
                 return "$prefix$numStr g";
               }
            }
          }
        }
        startIndex = idx + keyword.length; 
      }
      return null;
    }

    String kalori = findNextNumber("enerji", isEnergy: true) ?? findNextNumber("kcal", isEnergy: true) ?? "Bulunamadı";
    String yag = findNextNumber("yag", skipDoymus: true) ?? findNextNumber("yağ", skipDoymus: true) ?? "Bulunamadı";
    String karbonhidrat = findNextNumber("karbonhidrat") ?? findNextNumber("karb") ?? "Bulunamadı";
    String protein = findNextNumber("protein") ?? "Bulunamadı";

    if (kalori == "Bulunamadı") {
      Match? m = RegExp(r'(\d{2,3})\s*kcal').firstMatch(cleanText);
      if (m != null) kalori = "${m.group(1)} kcal";
    }

    return {"kalori": kalori, "protein": protein, "karbonhidrat": karbonhidrat, "yağ": yag};
  }

  // --- ANA ANALİZ MANTIĞI ---
  Map<String, dynamic> analyze(
    String text, {
    List<String> userAllergies = const [],
    bool sekerHassasiyeti = false,
    bool glutenHassasiyeti = false,
    bool tuzHassasiyeti = false,
    bool bebekModuAktif = false,
    int bebekAyi = 6,
    bool vegan = false,
    bool vejetaryen = false,
    bool koruyucuIstemiyor = false,
    String lang = 'tr',
  }) {
    List<String> foundAlerjen = []; List<String> foundKatki = []; List<String> foundRisk = [];
    List<String> userSpecificAllergies = []; List<String> customHassasiyetUyarilari = [];
    String cleanText = normalize(text);

    if (dataset.isEmpty) return { "level": "Veri Yüklenemedi", "score": 0, "color": "grey", "alerjen": [], "katki": [], "risk": [], "user_risk": [], "macros": {}, "bebek_uyarisi": "", "detectedCategory": "" };

    // ÇİFT DİLLİ UYARI MESAJLARI
    if (vegan) {
      List<String> veganYasak = ["et", "tavuk", "balik", "sut", "peynir", "yumurta", "bal", "jelatin", "karmin", "peyniralti", "laktoz", "kazein", "whey"];
      for (var terim in veganYasak) { 
        if (isFuzzyMatch(cleanText, terim)) { customHassasiyetUyarilari.add(lang == 'en' ? "🌱 Vegan Alert: Animal-derived ingredient detected (${terim.toUpperCase()})." : "🌱 Vegan Uyarısı: Hayvansal kaynaklı bileşen tespit edildi (${terim.toUpperCase()})."); break; } 
      }
    } else if (vejetaryen) { 
      List<String> vejetaryenYasak = ["et", "tavuk", "balik", "kiyma", "salam", "sosis", "sucuk", "jelatin", "karmin"];
      for (var terim in vejetaryenYasak) { 
        if (isFuzzyMatch(cleanText, terim)) { customHassasiyetUyarilari.add(lang == 'en' ? "🌿 Vegetarian Alert: Meat/animal tissue ingredient detected (${terim.toUpperCase()})." : "🌿 Vejetaryen Uyarısı: Et/Hayvansal doku bileşeni tespit edildi (${terim.toUpperCase()})."); break; } 
      }
    }

    if (koruyucuIstemiyor) {
      List<String> koruyucuYasak = ["koruyucu", "benzoat", "sorbat", "nitrit", "nitrat", "sulfit", "e2", "e3"];
      for (var terim in koruyucuYasak) { 
        if (isFuzzyMatch(cleanText, terim)) { customHassasiyetUyarilari.add(lang == 'en' ? "🛡️ Preservative Alert: Shelf-life extending chemical detected (${terim.toUpperCase()})." : "🛡️ Koruyucu Uyarısı: Raf ömrü uzatıcı kimyasal tespit edildi (${terim.toUpperCase()})."); break; } 
      }
    }

    if (sekerHassasiyeti) {
      List<String> sekerTerimleri = ["glukoz", "fruktoz", "sakkaroz", "seker", "surup", "tatlandirici", "aspartam", "sukraloz", "maltodextrin"];
      for (var terim in sekerTerimleri) { 
        if (isFuzzyMatch(cleanText, terim)) { customHassasiyetUyarilari.add(lang == 'en' ? "⚠️ Sugar Sensitivity: Sugary/sweetener ingredient detected (${terim.toUpperCase()})." : "⚠️ Şeker Hassasiyeti: Şekerli/Tatlandırıcılı bileşen tespit edildi (${terim.toUpperCase()})."); break; } 
      }
    }

    if (glutenHassasiyeti) {
      List<String> glutenTerimleri = ["bugday", "un", "gluten", "arpa", "cavdar", "nisasta"];
      for (var terim in glutenTerimleri) { 
        if (isFuzzyMatch(cleanText, terim)) { customHassasiyetUyarilari.add(lang == 'en' ? "⚠️ Gluten Intolerance: Gluten/wheat derived ingredient detected (${terim.toUpperCase()})." : "⚠️ Gluten Duyarlılığı: Gluten/Buğday türevi bileşen tespit edildi (${terim.toUpperCase()})."); break; } 
      }
    }

    if (tuzHassasiyeti) {
      List<String> tuzTerimleri = ["sodyum", "sodium", "tuz", "msg", "glutamat"];
      for (var terim in tuzTerimleri) { 
        if (isFuzzyMatch(cleanText, terim)) { customHassasiyetUyarilari.add(lang == 'en' ? "⚠️ High Salt / BP: Sodium or salt source detected (${terim.toUpperCase()})." : "⚠️ Yüksek Tuz / Tansiyon: Sodyum veya tuz kaynağı tespit edildi (${terim.toUpperCase()})."); break; } 
      }
    }

    String bebekUyarisi = "";
    if (bebekModuAktif) {
      if (bebekAyi < 6) {
        bebekUyarisi = lang == 'en' ? "🚫 Your baby is under 6 months old. Only breast milk or doctor-approved formula!" : "🚫 Bebeğiniz henüz ilk 6 ayında. Bu dönemde sadece anne sütü veya doktor onaylı devam sütü verilmelidir!";
      } else {
        List<String> bebekYasaklari = [];
        if (isFuzzyMatch(cleanText, "bal")) bebekYasaklari.add(lang == 'en' ? "Honey (botulism risk under 1 year!)" : "Bal (1 yaş altı botulizm riski!)");
        if (isFuzzyMatch(cleanText, "seker") || isFuzzyMatch(cleanText, "surup") || isFuzzyMatch(cleanText, "tatlandirici")) bebekYasaklari.add(lang == 'en' ? "Added Sugar/Sweetener" : "İlave Şeker/Tatlandırıcı");
        if (isFuzzyMatch(cleanText, "tuz") || isFuzzyMatch(cleanText, "sodyum")) bebekYasaklari.add(lang == 'en' ? "Added Salt/Sodium" : "İlave Tuz/Sodyum");
        
        if (bebekYasaklari.isNotEmpty) bebekUyarisi = lang == 'en' ? "👶 Risky Ingredients for $bebekAyi Month Old Baby: ${bebekYasaklari.join(', ')}. Not recommended." : "👶 $bebekAyi Aylık Bebek İçin Riskli Bileşenler: ${bebekYasaklari.join(', ')}. Tüketilmesi önerilmez.";
        else bebekUyarisi = lang == 'en' ? "👶 Ingredients analyzed. No acute risk substances found for a $bebekAyi month old baby." : "👶 İçerik incelendi. $bebekAyi aylık bebek için belirgin bir yerel akut risk maddesine rastlanmadı.";
      }
    }

    String detectedCategory = lang == 'en' ? "Packaged food product" : "Paketli gıda ürünü"; 
    if (isFuzzyMatch(cleanText, "cikolata") || isFuzzyMatch(cleanText, "kakaolu") || isFuzzyMatch(cleanText, "kakao kitlesi") || isFuzzyMatch(cleanText, "meyveli bar")) {
      detectedCategory = lang == 'en' ? "Chocolate / Sweet Snack / Bar" : "Çikolata / Tatlı Atıştırmalık / Bar";
    } 
    else if (isFuzzyMatch(cleanText, "margarin") || isFuzzyMatch(cleanText, "palm") || isFuzzyMatch(cleanText, "hidrojenize")) {
      detectedCategory = lang == 'en' ? "Margarine / Packaged Fat" : "Margarin / Paketli Yağ";
    } 
    else if (RegExp(r'\bkola\b').hasMatch(cleanText) || isFuzzyMatch(cleanText, "gazli") || isFuzzyMatch(cleanText, "asitli icecek")) {
      detectedCategory = lang == 'en' ? "Carbonated Drink / Cola" : "Gazlı İçecek / Kola";
    } 
    else if (isFuzzyMatch(cleanText, "biskuvi") || isFuzzyMatch(cleanText, "gofret") || isFuzzyMatch(cleanText, "kek") || isFuzzyMatch(cleanText, "kraker")) {
      detectedCategory = lang == 'en' ? "Packaged Biscuit / Wafer" : "Paketli Bisküvi / Gofret";
    } 
    else if (isFuzzyMatch(cleanText, "cips") || isFuzzyMatch(cleanText, "kizartma") || isFuzzyMatch(cleanText, "patates")) {
      detectedCategory = lang == 'en' ? "Packaged Chips / Snack" : "Paketli Cips / Çerez";
    }

    for (var item in dataset) {
      final nameTr = normalize((item["name_tr"] ?? "").toString());
      final nameEn = normalize((item["name_en"] ?? "").toString());
      final eCode = normalize((item["e_code"] ?? "").toString());

      bool isMatch = false;
      
      if (nameTr.isNotEmpty && isFuzzyMatch(cleanText, nameTr)) isMatch = true;
      else if (nameEn.isNotEmpty && isFuzzyMatch(cleanText, nameEn)) isMatch = true;
      else if (eCode.isNotEmpty) {
         String eCodeSpaced = eCode.replaceAll('e', 'e ');
         if (RegExp(r'\b' + eCode + r'\b').hasMatch(cleanText) || RegExp(r'\b' + eCodeSpaced + r'\b').hasMatch(cleanText)) {
            isMatch = true;
         }
      }

      if (isMatch) {
        List<String> cats = [];
        if (item["categories"] != null && item["categories"] is List) cats = List<String>.from(item["categories"]);
        
        String displayName = "";
        if (lang == 'en') {
           displayName = (item["name_en"] != null && item["name_en"].toString().isNotEmpty) ? item["name_en"].toString() : (item["name_tr"] ?? eCode).toString();
        } else {
           displayName = (item["name_tr"] != null && item["name_tr"].toString().isNotEmpty) ? item["name_tr"].toString() : (item["name_en"] ?? eCode).toString();
        }

        if (userAllergies.contains(displayName)) userSpecificAllergies.add(displayName);
        if (cats.contains("alerjen")) foundAlerjen.add(displayName);
        if (cats.contains("katki") || item["type"] == "additive") {
          foundKatki.add(displayName);
          if (koruyucuIstemiyor && !customHassasiyetUyarilari.any((e)=>e.contains("Koruyucu Uyarısı") || e.contains("Preservative Alert"))) {
             customHassasiyetUyarilari.add(lang == 'en' ? "🛡️ Preservative/Additive Alert: Additive detected ($displayName)." : "🛡️ Koruyucu/Katkı Uyarısı: Katkı maddesi tespit edildi ($displayName).");
          }
        }
        final riskLevel = (item["risk_level"] ?? "").toString();
        if (cats.contains("yuksek_risk") || riskLevel == "yuksek") foundRisk.add(displayName);
      }
    }

    foundAlerjen = foundAlerjen.toSet().toList(); foundKatki = foundKatki.toSet().toList();
    foundRisk = foundRisk.toSet().toList(); userSpecificAllergies = userSpecificAllergies.toSet().toList();

    String level; String color;
    if (userSpecificAllergies.isNotEmpty || customHassasiyetUyarilari.isNotEmpty) { level = "🚨 PROFİL / HASSASİYET UYARISI!"; color = "red"; } 
    else if (foundRisk.isNotEmpty) { level = "Yüksek Riskli İçerik!"; color = "red"; } 
    else if (foundAlerjen.isNotEmpty) { level = "Dikkat: Alerjen İçeriyor"; color = "yellow"; } 
    else if (foundKatki.isNotEmpty) { level = "Orta Düzey (Katkı Maddesi)"; color = "yellow"; } 
    else { level = "Temiz İçerik / Risk Bulunamadı"; color = "green"; }

    return {
      "alerjen": foundAlerjen, "katki": foundKatki, "risk": foundRisk, "user_risk": userSpecificAllergies,
      "score": 0, "level": level, "color": color, "macros": extractMacros(text), 
      "bebek_uyarisi": bebekUyarisi, "hassasiyet_detaylari": customHassasiyetUyarilari, 
      "detectedCategory": detectedCategory,
      "alternatif": "" 
    };
  }
}