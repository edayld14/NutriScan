import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GroqService {
  static const String _apiKey = "buraya-api-key-gelecek";
  static const String _model = "llama-3.3-70b-versatile";
  static const String _endpoint = "https://api.api.groq.com/openai/v1/chat/completions";

  static const String _systemPrompt = """
  Sen NutriScan uygulamasının uzman gıda içerik analiz asistanısın. 
  Kullanıcıların gıda bileşenleri, alerjenler, katkı maddeleri, e-kodları veya 
  gıdaların sağlığa etkileri hakkındaki sorularını net, kısa, doğru ve bilgilendirici bir şekilde yanıtla.
  """;

  Future<String> askAi(String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": _model,
          "temperature": 0.3,
          "messages": [
            {"role": "system", "content": _systemPrompt},
            {"role": "user", "content": userMessage},
          ],
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data["choices"][0]["message"]["content"].toString().trim();
      } else {
        return "Hata: Sunucu ${response.statusCode} koduyla yanıt verdi.";
      }
    } catch (e) {
      return "Bağlantı hatası oluştu. Lütfen internetinizi kontrol edin.";
    }
  }

  // --- DİNAMİK VE ÇİFT DİLLİ ALTERNATİF MOTORU ---
  Future<String> getHealthyAlternative(String category, String userProfile, String lang) async {
    String prompt;

    if (lang == 'en') {
      prompt = """
      The user scanned a package containing a product category: '$category'.
      The user's health profile and preferences are: $userProfile.
      
      You are an expert dietitian. Suggest 2 specific, much healthier, and natural alternatives 
      that can replace this '$category' and are suitable for the user's health profile (allergies/preferences).
      
      RULES:
      1. Start directly with the suggestion prefix: "💡 Alternative Suggestion: ".
      2. Never use introductory phrases like "Hello" or "I understand".
      3. Keep the sentences very short and clear (Maximum 2 sentences).
      4. Respond ONLY in English.
      """;
    } else {
      prompt = """
      Kullanıcı bir ürün kategorisi olan '$category' içeren bir ambalaj tarattı.
      Kullanıcının sağlık profili ve tercihleri şunlar: $userProfile.
      
      Sen uzman bir diyetisyensin. Kullanıcıya bu '$category' yerine geçebilecek, onun sağlık profiline (alerjilerine/tercihlerine) uygun, 
      çok daha sağlıklı ve doğal 2 spesifik alternatif öner. 
      
      KURALLAR:
      1. Sadece doğrudan öneriyi yaz (Örn: "💡 Alternatif Öneri: ..."). 
      2. Asla "Merhaba", "Anladım" gibi giriş cümleleri kullanma.
      3. Cümle çok kısa ve net olsun (Maksimum 2 cümle).
      4. Sadece Türkçe yanıt ver.
      """;
    }

    try {
      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": _model,
          "temperature": 0.5, // Biraz daha yaratıcı olması için sıcaklığı artırdık
          "messages": [
            {"role": "user", "content": prompt},
          ],
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data["choices"][0]["message"]["content"].toString().trim();
      } else {
        return ""; // Hata olursa boş dönsün, UI'da görünmesin
      }
    } catch (e) {
      return "";
    }
  }
}