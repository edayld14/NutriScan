class ComparisonService {
  // 2 ürünün verilerini alıp karşılaştırmalı bir rapor döndürür
  String generateComparisonReport(Map<String, dynamic> p1, Map<String, dynamic> p2) {
    int risk1 = (p1['risk'] as List).length + (p1['katki'] as List).length;
    int risk2 = (p2['risk'] as List).length + (p2['katki'] as List).length;

    String winner = risk1 < risk2 ? "1. Ürün" : "2. Ürün";
    
    return "Analiz tamamlandı: $winner daha güvenli görünüyor. "
           "1. Ürün toplam $risk1 riskli madde içerirken, "
           "2. Ürün toplam $risk2 riskli madde içermektedir.";
  }
}