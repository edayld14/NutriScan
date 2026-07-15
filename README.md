# 🍏 NutriScan: AI-Powered Food Ingredient Analyzer

NutriScan, market alışverişlerinde kullanıcıların sağlık profillerine uygun kararlar almasını sağlayan yapay zeka (AI) ve görüntü işleme (OCR) destekli bir akıllı etiket okuma asistanıdır.

## 🚀 Özellikler
* **Gelişmiş OCR Taraması:** Ürün paketlerindeki içindekiler kısmını saniyeler içinde okur ve metne dönüştürür.
* **Akıllı Fuzzy Matching (Bulanık Eşleşme):** E-kodları ve içerikleri %82 benzerlik oranı ile analiz eder; alerjenleri ve katkı maddelerini hatasız yakalar.
* **Kişiselleştirilmiş Sağlık Profili:** Kullanıcının (Vegan, Çölyak, Şeker/Tuz hassasiyeti vb.) profiline göre anlık risk uyarıları verir.
* **Bebek Modu:** Taranan ürünün bebeğinizin ayına uygunluğunu analiz eder (Örn: Bal veya Şeker uyarısı).
* **Groq API & Llama-3.3 Entegrasyonu:** Riskli bulunan ürünler için sağlıklı, doğal alternatifleri anında üretir ve içeriklerin bilimsel zararlarını açıklar.

## 🛠️ Kullanılan Teknolojiler
* **Mobil Geliştirme:** Flutter, Dart
* **Backend:** Firebase (Firestore)
* **Görüntü İşleme:** Google ML Kit (Text Recognition), Image Cropper
* **Yapay Zeka:** Groq API (Llama-3.3-70b-versatile)
