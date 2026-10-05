# Lobi ve ada haritası mimarisi

Karar (kullanıcıdan): oyun iki ayrı haritadan oluşur.

## 1. Ada haritası (şu anki proje)
- 6 oyunculu sunucu: her oyuncuya bir fiziksel ada verilir (hepsi aynı düzende); etkin ana çiftliğin teması o adaya
  çalışma anında giydirilir, diğer çiftlikler park edilir (ayrıntı: [Ana çiftlikler](ANA_CIFTLIKLER.md)).
- Hangi çiftliklerin/adaların açık olduğu kişisel ilerlemedir (`PlayerSave`); harita herkes için aynıdır.
- `Players.MaxPlayers` en fazla `Config.MAP_PLOT_COUNT` olmalıdır; fazlası için `PlotService.init` uyarı verir.

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
3. Sıralama puanı: gelir, açık ada sayısı, toplam hayvan gibi bir skoru lobiye yayınlama. (Meydanda `HubBoardService` üç pano gösterir: sunucu içi "Sunucu Sıralaması" (kasa, ada, rebirth), genel "En Çok Rebirth" ve "En Çok Tamamlanan Çiftlik". Genel tablolar `SaveStore.publishRank/readTopRank` ile OrderedDataStore kullanır; yalnız bilgi amaçlıdır, ödül/gerçek para bağlanmaz. Sunucu panosu yerel kalır.)
4. `Config.MAP_PLOT_COUNT` haritadaki fiziksel ada sayısıdır ve sunucudaki en fazla oyuncu sayısını belirler.
