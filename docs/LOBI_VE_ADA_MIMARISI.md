# Lobi ve ada haritası mimarisi

Karar (kullanıcıdan): oyun iki ayrı haritadan oluşur.

## 1. Ada haritası (şu anki proje)
- Oyuncuya özeldir: girişte gelen bütün ada kümeleri (Papatya, Kiraz, Lale... = 6 ana çiftlik alanı ve
  her birinin küçük adaları) o oyuncunundur. "6 ada = 6 oyuncu" mantığı yoktur.
- Hangi adanın/alanın açık olduğu kişisel ilerlemedir (`PlayerSave`); harita herkes için aynıdır.
- Yayında bu place'in Maximum Players değeri 1'dir (ziyaretçi özelliği gelince sahip + ziyaretçi sayısı).
- Mevcut kod bu haritayı zaten tek oyuncu için kullanıyor: `PlotService`, oyuncuya boş bir alan verir,
  "Ana çiftlik satın al" ile diğer alanlar açılır. Studio'da birden fazla oyuncu denemek için kapasite
  1'den büyükse `PlotService.init` bilgilendirme uyarısı verir; oyun çalışmaya devam eder.

## 2. Lobi (henüz yok, sonra yapılacak)
- Ayrı bir place. Oyun lobide açılır.
- Lobide oyuncuların ada sıralamasındaki durumu görünür (skor tablosu; kalıcı sıralama için
  OrderedDataStore önerilir).
- "Adama git": `TeleportService` ile oyuncunun özel ada sunucusuna (ReserveServer) ışınlar.
- "Ziyaret": başka oyuncunun ada sunucusuna misafir olarak ışınlar. Bu iş yapılırken ada haritasındaki
  `PlotService` misafirlere plot vermemeli (yalnızca sahip plot alır); şu an ilk giren herkes plot alır.

## Ada haritasında lobiye hazırlık için yapılacaklar (sonraya)
1. Sahip kimliği: ada sunucusu açılırken `TeleportData`/reserved server ile sahibi belirle; misafirleri ayır.
2. Lobiye dönüş düğmesi ("Lobiye git").
3. Sıralama puanı: gelir, açık ada sayısı, toplam hayvan gibi bir skoru lobiye yayınlama.
4. `Config.MAP_PLOT_COUNT` yalnızca haritadaki fiziksel ana çiftlik alanı sayısıdır (oyuncu sayısı değil).
