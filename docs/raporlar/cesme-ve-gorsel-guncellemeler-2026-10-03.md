# Çeşme ve görsel güncellemeleri — 2026-10-03

- Meydan çeşmesi: `assets/HubProps/Fountain.rbxmx`, 31 sabit parça, mesh yok; zemin pivotu ve meydandaki (0,4,0) konumu korundu.
- Taş havuz, sekiz kenarlı duvar/başlık, üst hazne ve dört su ağzı eklendi. Studio'daki yalnız çeşme kopyası yenilendi.
- `Effects/Fountain.client.luau`: dört kalıcı Beam ve bir püskürtme efekti; model yeniden kurulmaz. Kalite, 180 stud mesafe ve ReducedMotion uygulanır.
- `HubNpcs`: çeşme Atomic yüklenir; parçaları ayrı ayrı gelmez.
- `ExtensionVisualService`: indirim/iş değişiminde ana model, tabela ve prompt korunur; kapasite değişiminde yalnız kapasite dekoru güncellenir.
- `UpgradeLevelProps`: hayvan ırkı anıtları tür başına, yem/büyüme süsleri bölge başına, pet yuvası slot başına güncellenir.
- `UpgradeSites`: fiyat değişiminde mevcut tabela yazısı güncellenir; model/prompt yeniden kurulmaz.
- `InventoryService`: yalnız değişen veya hasarlı eşya slotu yeniden giydirilir; diğer takılı eşya modelleri korunur.
- Hayvan/bölge/ahır servisleri ve para yığını zaten ilgili görünüm durumuna göre korunuyor; gereksiz değişiklik yapılmadı.
- Önceki su altı, buz, pet rota ve depo dekoru düzeltmeleri aynı dalda duruyor.

## Tek toplu kontrol

- Model kontrolü: 745 görünüm, 0 eksik, 0 bozuk.
- Selene: 0 hata/uyarı; mimari, AI rehber ve 1199 anahtarlı çeviri kontrolü geçti.
- Saf Luau regresyon paketi ve gerçek dört görsel servisin referans kimliği testleri geçti.
- Yükseltme süsü/site testleri: tek öğe değişimi diğer model/prompt referanslarını koruyor; aynı fiyat tekrar yazılmıyor.
- Tip kontrolü: 0 yeni bulgu; 230 bilinen, tabana göre 5 azalma. Rojo derlemesi başarılı.
- Studio çeşme testi: 31 aynı parça ve dört akış; kalite 32→5, hareket azaltma ve mesafede kapatma başarılı; konsolda hata yok.
- MCP ekran görüntüsü yine boş 3B alan verdi; görsel görünüm ekran görüntüsüyle doğrulanamadı.
- Test Play kapatıldı; Studio Edit modunda. Geçici sahne modeli bırakılmadı.
- Terrain, ada yerleşimi, MAP_VERSION ve Haritayı Kur değiştirilmedi; save/publish/commit/push yapılmadı.
- Çeşmenin kayıtlı sahne kopyasını kalıcı tutmak için kullanıcı Ctrl+S yapmalı; kod/asset değişiklikleri repoda hazır.
