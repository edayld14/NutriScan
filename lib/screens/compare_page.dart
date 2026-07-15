import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/translations.dart'; 

class ComparePage extends StatelessWidget {
  final Map<String, dynamic> product1;
  final Map<String, dynamic> product2;

  const ComparePage({super.key, required this.product1, required this.product2});

  @override
  Widget build(BuildContext context) {
    final Color textColor = const Color(0xFF2D3142);

    int score1 = product1["risk"].length + product1["user_risk"].length + product1["alerjen"].length;
    int score2 = product2["risk"].length + product2["user_risk"].length + product2["alerjen"].length;

    String winnerMessage = "";
    if (score1 < score2) {
      winnerMessage = "🏆 1. Ürün, profil hassasiyetlerinize ve risk analizine göre DAHA SAĞLIKLI görünüyor.";
    } else if (score2 < score1) {
      winnerMessage = "🏆 2. Ürün, profil hassasiyetlerinize ve risk analizine göre DAHA SAĞLIKLI görünüyor.";
    } else {
      winnerMessage = "⚖️ Her iki ürünün de risk profili benzer düzeyde.";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text('compare_now'.tr, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.withOpacity(0.3))),
              child: Text(winnerMessage.tr, style: GoogleFonts.montserrat(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 13, height: 1.4)),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. ÜRÜN SÜTUNU
                Expanded(child: _buildProductCompareCard('1. ÜRÜN'.tr, product1, Colors.blue)),
                const SizedBox(width: 12),
                // 2. ÜRÜN SÜTUNU
                Expanded(child: _buildProductCompareCard('2. ÜRÜN'.tr, product2, Colors.purple)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCompareCard(String title, Map<String, dynamic> pData, MaterialColor themeColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        border: Border.all(color: themeColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Chip(label: Text(title, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: themeColor.shade400)),
          const SizedBox(height: 8),
          
          // EKLENEN KISIM 1: Ne tarattığını hatırlatan Kategori Etiketi
          Center(
            child: Text(
              pData["detectedCategory"]?.toString().toUpperCase() ?? "BİLİNMEYEN ÜRÜN", 
              textAlign: TextAlign.center, 
              style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w700)
            )
          ),
          const Divider(height: 20),
          
          Text('📊 Analiz Seviyesi:'.tr, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(pData["level"].toString().tr, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: pData["color"] == "red" ? Colors.red : Colors.green)),
          
          const Divider(height: 20),
          
          // EKLENEN KISIM 2: Sadece sayı veren listeler yerine detaylı Açılır Kapanır / Görünür Liste mantığı
          _buildDetailSection('🚨 Alerjen Sayısı:'.tr, pData["alerjen"] ?? [], Colors.red),
          _buildDetailSection('🧪 Katkı Maddesi:'.tr, pData["katki"] ?? [], Colors.orange),
          _buildDetailSection('⚠️ Yüksek Risk:'.tr, pData["risk"] ?? [], Colors.purple),
          _buildDetailSection('👤 Profil Uyarısı:'.tr, pData["user_risk"] ?? [], Colors.pink),
        ],
      ),
    );
  }

  // Bu yeni widget sayesinde hem sayıları görüyoruz hem de maddelerin isimlerini minik etiketlerle listeliyoruz!
  Widget _buildDetailSection(String label, List items, MaterialColor color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: GoogleFonts.montserrat(fontSize: 11, color: const Color(0xFF2D3142), fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), 
                child: Text("${items.length}", style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, color: color.shade700))
              ),
            ],
          ),
          
          // Eğer içinde madde varsa (sayı > 0 ise) bu maddelerin isimlerini minik şık etiketlerle ekrana bas
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4, runSpacing: 4,
              children: items.map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: color.shade50, 
                  borderRadius: BorderRadius.circular(6), 
                  border: Border.all(color: color.shade200)
                ),
                child: Text(e.toString(), style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.bold, color: color.shade800)),
              )).toList(),
            )
          ]
        ],
      ),
    );
  }
}