# E — Entegrasyon raporu

Dokuz dalın dokuzu da `entegrasyon` dalında birleştirildi ve `main`'e ff-merge edildi. `verify.ps1` temiz, tip tabanına yeni bulgu yok.
Plan sırası korundu. Çakışma çıkan altı birleştirme elle çözüldü, hiçbir dal atlanmadı.
Ana klasördeki yarım mobil değişiklikler `git stash` içinde duruyor (`yarim-mobil-artiklari`); `feat/onboarding` silinmedi (aşağıda).

## Alınan / atlanan dallar

| Dal | Karar kaynağı | Sonuç |
|---|---|---|
| `feat/telemetri` | D-P1 Birleştirilebilir | alındı |
| `refactor/kalite` | P8 Birleştirilebilir | alındı |
| `feat/sim-genislet` | D-P2 Birleştirilebilir | alındı |
| `perf/sunucu-ag` | D-P4 Birleştirilebilir | alındı |
| `perf/istemci` | P5 Birleştirilebilir | alındı |
| `feat/mobil-ses` | D-P6 Birleştirilebilir | alındı |
| `feat/onboarding-paketi` | D-P7 Birleştirilebilir | alındı |
| `balance/gec-oyun` | D-P10 Birleştirilebilir (ırk ayarı geri alınmış) | alındı |
| `feat/tema-sablonlari` | D-P11 Birleştirilebilir | alındı |

Atlanan dal yok. `feat/onboarding` silinmedi: 3 commit'ten ikisi `perf/istemci`'dekilerle aynı yama (patch-id eşit), ama `9ec7eb0`
(FarmHud) aynı değil. İçinde `UiScale`, `Kit/Screen`, `Tokens` ve `ui-scale.spec` gibi mobil işine ait ek var; bunlar
`feat/mobil-ses`'te farklı biçimde uygulandı. Planın "değilse dokunma" kuralı gereği duruyor. Silmeyi sen karar ver.

## Çözülen çakışmalar

| Birleştirme | Dosya | Çözüm |
|---|---|---|
| `refactor/kalite` | `docs/MIMARI.md` | Kalite tablosu esas alındı; telemetri (`TelemetryLogic`, `TelemetryService`) satırlara eklendi |
| `refactor/kalite` | `scripts/run-tests.py` | İki taraf da tutuldu. Kalite servis testleri ve telemetri harness'i birlikte. `AnimalService`/`UpgradeService` harness bağımlılıklarına `TelemetryService` eklendi (kod gövdesi telemetriyi çağırıyor, harness'te etkisiz sahte nesne var) |
| `perf/sunucu-ag` | `AnimalService.luau` | Kalitenin `respond` yerel fonksiyonu (RequestGuard'a taşınmıştı) silindi. Sunucu-ağın `updateGrowth(player, farmId)` ve park edilmiş çiftlikte yalnızca kendi adasını yenileme mantığı alındı |
| `feat/mobil-ses` | `PlayerDataService.luau`, `run-tests.py` | `Preferences` ve `TelemetryService` require'ları birlikte; harness bağımlılık kümesi ve test çağrıları birleştirildi (contract spec `RequestGuardFactory` argümanı korundu) |
| `feat/onboarding-paketi` | `FarmHud.client.luau` | `hudRoot` (UiScale güvenli alan) + onboarding'in `toastRelay`/`storeForSale`/4 hedefli `Onboarding.create`. Tembel pencere kapıları (`isOpen`) ve rozet güncellemesi korundu; `updateStore` artık nil olabilir, kapı `updateStore and storeWindow.isOpen()`. Gamepad DPad bloğu korundu |
| `feat/onboarding-paketi` | `MenuBar.luau` | `create(screenGui: Instance, onUnlocked)`; açılış bildirimi parametreli `setMenuTile` ile gamepad `linkSelection` zinciri birlikte. `sideOrder` listesine yeni `storeButton` (Destek karosu) eklendi, yoksa gamepad gezintisinde atlanırdı |
| `feat/tema-sablonlari` | `MapBuilder.luau` | Tema şablonu için `RunService`/`ServerStorage` alındı, kalitenin `SharedRef` yolu korundu, kullanılmayan `ReplicatedStorage` kaldırıldı. `MAP_VERSION` 50 (yalnızca tema dalı artırmıştı) |

## Entegrasyon düzeltmeleri (commit)
- `fix: entegrasyon harness (simulate-economy Preferences) ve MIMARI satırları`
  - `scripts/simulate-economy.py` SaveCodec harness'ine `Preferences` eklendi (verify'daki "--json parses" smoke kırmızıydı).
  - `docs/MIMARI.md`: `Preferences` (sunucu ve istemci) ve `TutorialMarker` satırları eklendi (check-ai-docs kırmızıydı).
- Telemetri `reason/sku` taşıma notu (D-P1): RequestGuard'a geçen handler'larda `addCash`/`trySpend` çağrılarının hepsinde `reason` (ve uygun yerde `sku`) mevcut. Ek değişiklik gerekmedi.

## Doğrulama
`verify.ps1` son satırı: `All automated checks passed. Studio multiplayer, DataStore fault and device tests remain separate.`
Tip analizi: yeni bulgu yok (284 bilinen bulgu, tabandan 0 azalma). Locale: 949 anahtar en/de/ru eşit. Mimari kurallar tamam.

## Simülasyon (`simulate-economy.py --days 7`)

**Varsayılan (ideal):** 50/69 yükseltme, 106 hayvan, gelir 6764,6/sn, kasa $4B. Tüm yükseltmeler 305 dk (hedef 240-300), ırk Sv.60 321 dk.
Alan genişletme toplam Sv.80 ($19,2M); ırk geliştirme toplam Sv.60 ($5,1M); ırk geri dönüş en kötü 1,67 sa (seabass Sv.10).
Depo dolu geçen süre %0; gelir %100 hayvan.

**Casual (20 dk × 3 oturum/gün):** 6 çiftlik, 40/69 yükseltme, kasa $7,4B (gelir toplamı $7,7B). Gelir kaynakları: %91 çevrimdışı, %4,8 park edilmiş çiftlik,
%2 üretim, %1,8 hayvan, %0,2 günlük ödül, %0,1 mevsim, ~%0 sipariş ve altın hayvan.
Alan genişletme Sv.427 ($112M); ırk Sv.120 ($10,8M); ırk geri dönüş en kötü 1,67 sa.
Çiftlik başına gelir: Ç1 2187, Ç2 3846, Ç3 3272, Ç4 1609, Ç5 7550, Ç6 7984 /sn.

Not (P3 için): casual oyuncuda 7 günde gelirin %91'i çevrimdışı ve 6 çiftlik alınıyor; hepsi 'otomatik' (toplayıcılı) durumda. P3'ün çiftlik çarpanı ve çevrimdışı tavan ayarları bu rakamlarla başlamalı.
İlk 7 günde ideal oyuncunun gelir eğrisi düz kalıyor (gün 1'den itibaren aynı); ayarlamaya konu olan "geç oyun tavanı" bu.

## Eklenti / harita notu
- `MAP_VERSION` 50 (tema şablonları). Kayıtlı place 49'da kaldıysa oyun sürüm uyuşmazlığı verir.
- Eklentiyi yeniden derle: `rojo build plugin.project.json --plugin IslandFarmTycoonHarita.rbxm`, Studio'da yeniden aç.
- Edit modunda "Haritayı Kur", sonra place'i kaydet.
- Edit modunda `tests/map-structure.spec` çalıştır; sonunda `ServerStorage.ThemeTemplates` temizlenmiş olmalı.

## Birleşik Studio test listesi (öncelik sırasıyla)

**A. Harita ve eklenti (önce bunlar; diğerleri haritaya bağlı)**
1. Eklentiyi yeniden derle, "Haritayı Kur", kaydet (MAP_VERSION 50). `SharedRef` + eklenti yolunda `World` dosyaları `Shared`'ı bulabiliyor mu.
2. Edit modunda `map-structure.spec` yeşil, `ServerStorage.ThemeTemplates` temizlenmiş.
3. Play: 6 `Theme<n>` şablonu, **açılış süresini ölç** (O11-2: tek seferde 6 tema kuruluyor; uzunsa 1. tema eşzamanlı, kalanlar `task.defer` ile).
4. Tema döngüsü 1→6→1, Plot1 ve döndürülmüş ada (3/5): yapı noktaları, uzman ada `AreaCFrame`/`PathStart/End`.
5. İki istemci: A farklı temayla çıkar, B girer; B'nin giriş sonrası tema değişiminde BuyPads yeni temanın yuvalarında, `RevealGate` süsleri doğru.
6. Gece lambaları/pencereleri, çarpışma ve ışın sorguları şablon kopyasında korunmuş.
7. Çiftlik toplayıcı görseli (Collector) açılışta hatasız kuruluyor (tembel require).

**B. Çok çiftlikli oyuncu ve ağ (sunucu-ağ + kalite)**
8. 2+ çiftlikli hesapta Envanter/Üretim depo kapasitesi sunucuyla aynı, Sipariş Panosu teklifleri, GoalCard önerileri.
9. Hızlı satın alma/üretim sırasında istemci fazladan `RequestPlayerState` atıyor mu (boşluk kalktı mı); satın alma yanıtında 0,25 sn gecikme hissi.
10. Park edilmiş çiftlikte hayvan büyümesi: ada görseli güncelleniyor, etkin çiftlikte takılma yok. Çıkıp 1 saat sonra girince iki çiftliğin çevrimdışı kazancı toplanıyor.
11. Uzak adalar 448 stud'da görünüyor, adalar arası pop-in, uzak adada evcil hayvanlar. Yeni hayvanın yuvası çakışmıyor.
12. Hayvan al/sat, gezgin tüccar, hamsi→levrek: normal, hızlı spam ("Çok hızlı…" en fazla 0,5 sn'de bir), çiftlik değiştirirken tıklama ("Etkin çiftlik değişti"). Yükseltme/ırk/bölge, sipariş, günlük/başarım/mevsim/altın ödülü, envanter yanıtları.
13. pushState paket boyutu önce/sonra (MicroProfiler).

**C. Mobil, ses ve gamepad**
14. Device Emulator: telefon (dikey/yatay, çentikli), tablet, 1440p+. HUD çentiğe taşmıyor, pencereler sığıyor.
15. Stats paneli aç/kapat her ölçekte: sekme panele yapışık, 44 px, kasa metni taşmıyor.
16. Ayarlar: üç ses sürgüsü + "Hareketi azalt"; çık-gir kayıtlı değer geliyor, yeni hesapta varsayılan 0,5/0,7/0,5, Output'ta gereksiz tekrar remote yok. en/de/ru.
17. Ses kimlikleri hâlâ boş: `Config/Audio.luau`'ya bir kimlik gir (`MUSIC.main`) ve ortam/efekt sürgülerini dene.
18. Gamepad: veri gelmeden DPad bir şey açmıyor; yön tuşları menü gezintisi **ve yeni Destek karosu dahil** sağ sütun sırası, B ile kapatma ve seçimin geri gelmesi.
19. Koşu ile zıplama düğmesi çakışmıyor.

**D. Onboarding ve HUD (en çok birleşme riski burada)**
20. Yeni oyuncu: yalnızca Pazar/Ödüller/Ayarlar, "Destek" karosu yok, hedef kartı "İLK ADIMLAR 1/6".
21. Adım 1-6 akışı: Pazar nabzı + altın "Buraya gel" ışını (12 stud'da kaybolur), hayvan al → 2/6, 3/6 Yükseltmeler karosu ve "Yeni menü açıldı" bildirimi, 4/6 Yol Haritası, 5/6 genişletme, 6/6 Üretim; sonunda Adalar karosu.
22. Aynı bildirim hızlı tekrar: tek kart "×N"; dar ekran ve ru'da rozet taşması.
23. en/de/ru: adım başlıkları (1-3'te yanlış x/3 çıkmasın). Kıdemli kayıt 1.500–20.000 kazanç: her girişte 4. adım **çıkmamalı** (yeni hesaba özel). 20.000+ hiç çıkmamalı.
24. `Config/Shop`'ta bir kimliği 0 dışı yap: Destek karosu görünür, pencere açılır.
25. Kapalı Ödüller/Pano/Destek pencereleri çizilmiyor ama Ödüller rozet sayısı güncel; pencereyi açınca içerik taze.

**E. Telemetri**
26. `Workspace.TelemetryPrint = true`: ilk toplama, hayvan, yükseltme, ada, Ahır 2 satırları bir kez; çıkıp girince tekrar yok. Para harcayınca `Source/Sink`; toplama 60 sn'de tek satır; çevrimdışı dönüşte `Offline`/`OfflineSeconds`; çıkışta `SessionSeconds`.
27. Studio'da gerçek analitik gitmiyor (`TelemetryStudioSkipped` artar). DataStore kapalıyken kırmızı `[Data] …` satırı, oyun çökmüyor.

**F. Ekonomi, istemci performansı ve ek**
28. Pazar ırk düğmesi Sv.0→10 ve maliyet metni (3 anlamlı basamak); eski kayıtta (Sv.10) düğme yeniden aktif ve gelir değişimi makul. HUD gelir/sn sunucuyla aynı. Rozet kademeleri. Elmas çekiç 2,5M.
29. Çocuk hayvan hareketi (`AnimalAnimator` BulkMoveTo), düşük kalitede hayvan sınırı (20 hayvan / 50 stud), parça sonradan eklenince hareket ediyor mu (P5-1).
30. Gece/gündüz: düşük kalitede gerçek ışıklar kapalı, görünüm bozulmuyor; kalite değişince ışıklar tazeleniyor. SeabedLife yüksek kamerada 15 Hz.
31. Localizer: tabelalar yeni dilde çevrildi, Workspace'e eklenen/taşınan tabelalar çift izlenmiyor (P5-4).

## Açık sorular
1. `feat/onboarding` silinsin mi? Yarım `UiScale`/`Kit/Screen` işi var; `feat/mobil-ses` aynı konuyu kendi biçiminde çözdü, ama iki uygulamayı satır satır karşılaştırmadım.
2. `git stash`'teki `yarim-mobil-artiklari` (16 dosya, yarım mobil UI) atılsın mı? `feat/mobil-ses` zaten birleşti, büyük olasılıkla artık gereksiz.
3. P5-1 (`AnimalAnimator` parça listesi bayatlaması) ve P5 Localization testi isteğe bağlı olarak yapılmadı.
4. O11-2 açılış süresi ölçümü bekliyor (A3).
5. K1-K3 kararların hâlâ senin.

## Kapanış
`main` = `entegrasyon` (ff). Birleşen 9 dal ve `entegrasyon` silindi; 9 worktree (hepsi temizdi) kaldırıldı. Kalan dallar: `feat/onboarding`, `fix/analiz-hafta1`. Stash `yarim-mobil-artiklari` duruyor.
