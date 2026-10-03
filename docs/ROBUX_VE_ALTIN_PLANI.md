# Eşya, altın ve Robux marketi planı

Durum: **plan** (kod yok). `docs/REBIRTH_PLANI.md` ile birlikte okunur (rebirth'te neyin kaldığı orada). Sayılar taslaktır; `scripts/simulate-*.py` ile ayarlanır.

## 1. İlkeler (kullanıcı kararı)
1. **Etkisiz satın alınabilir şey kalmaz.** Her eşya bir etki kazandırır. Saf görünüm eşyaları (15 şapka/sırt) etkili hale getirilir.
2. **Her şey neredeyse Robux'lanabilir, mantıklı olmak şartıyla**: en üst seviye eşyalar Robux'la satılır; kolaylık ürünleri (otomatik toplayıcı, yardımcı) hem oyun parasıyla hem Robux'la alınabilir.
3. **Robux'la alınan kalıcıdır** (rebirth sıfırlamaz); oyun parasıyla alınan sıfırlanır.
4. **Yeni para birimi: altın** (yalnızca ada/çiftlik bitirince kazanılır). Bununla hızlı bitirilir ya da paraya çevrilir.
5. **Robux Marketi**: Robux'la doğrudan altın (ve gelire göre ölçülen anlık para paketi) satın alınır.

## 2. Eşyalar: görünüm eşyaları etkiye çevrilir
Mevcut durum (`Config/Items.luau`): 19 etkili eşya (çekiç, asa, tılsım) ve **15 etkisiz görünüm eşyası** (8 şapka, 7 sırt). Hepsine **mevcut etki anahtarlarıyla** (yeni motor kodu yok) etki verilir.
Slot rolü: **şapka = ticari** (satış, sipariş, ürün), **sırt = lojistik** (depo, çevrimdışı, büyüme). Bir slota tek eşya takılır, kademeler artar; değerler taslak.

| Slot | Eşya (fiyat) | Etki (taslak) | Satış |
|---|---|---|---|
| Şapka | Çiftçi Şapkası (10K) | sellBonus +%2 | nakit |
| | Bere (12K) | offlineBonus +%3 | nakit |
| | Kasket (15K) | contractBonus +%2 | nakit |
| | Hasır Şapka (20K) | storageBonus +%10 | nakit |
| | Tavuk Şapkası (30K) | goodsYield +%4 | nakit |
| | Çiçek Tacı (45K) | growthSpeed +%5 | nakit |
| | Kovboy Şapkası (60K) | sellBonus +%6, contractBonus +%3 | nakit |
| | **Altın Taç (400K)** | incomeBonus +%6, sellBonus +%5 | **Robux** |
| Sırt | Sırt Çantası (12K) | storageBonus +%8 | nakit |
| | Hasat Sepeti (25K) | goodsYield +%3 | nakit |
| | Kırmızı Pelerin (50K) | offlineBonus +%5 | nakit |
| | Yaprak Pelerin (90K) | growthSpeed +%10 | nakit |
| | Melek Kanatları (250K) | incomeBonus +%4 | nakit |
| | Tavus Kuyruğu (500K) | contractBonus +%8, goodsYield +%4 | nakit |
| | **Altın Kanatlar (1M)** | incomeBonus +%8, offlineBonus +%10 | **Robux** |

Fiyatlar eski ölçektir (Çiftlik 1 harcaması ~12M); nakitle alınan eşyalar rebirth'te sıfırlandığı için her turun başında ucuza alınır. Geç oyun gelirine (25M/saat) göre ucuz kalmaları sorun değil; tur başı hedefidir.

### Robux'la satılacak en üst seviyeler (kalıcı)
Her eşya hattının son kademesi: Elmas Çekiç, Mevsim Asası (sonsuz), Hava Asası (sonsuz), Gelir Tılsımı 3, Büyüme Tılsımı 2, Depo Tılsımı 2, Ambar Tılsımı 2, Sipariş Tılsımı 2, Altın Taç, Altın Kanatlar (**10 eşya**).
- Etkileri bugün küçük (en çok gelir +%10, indirim %20); bu yüzden kalıcı satmak güvenlidir.
- **Toplam tavan:** eşya + rebirth etkisi + Robux ürünü toplamı gelir artısı için knee/tavanla sınırlanır (`REBIRTH_PLANI` bölüm 6); her şey alınsa bile tur süresi tabanın altına inmez (sim denetler).
- Robux eşyası dükkânda "Robux ile al" düğmesiyle çıkar; sahip olunca takılır, rebirth'te takılı kalır.

## 3. Kolaylık ürünleri: oyun parası + Robux
Aynı ürün iki yoldan alınabilir ("almak isteyen alsın"):

| Ürün | Nakitle | Robux ile |
|---|---|---|
| Otomatik toplayıcı | yükseltme (sıfırlanır) | kalıcı (rebirth'te kalır) |
| Yardımcılar (`pet_cash`, `pet_goods`) | yükseltme (sıfırlanır) | kalıcı |
| Ekstra depo / diğer kolaylık yükseltmeler | yükseltme (sıfırlanır) | kalıcı (isteğe bağlı) |

Kural: Robux'la alınan sahiplik hesap düzeyinde `owned` işaretiyle tutulur (`MonetizationService` makbuz akışı); nakitle alınan çiftlik kaydındadır ve sıfırlanır. İkisi birden varsa etki bir kez uygulanır. Sıfırlanma sonrası otomatik toplayıcı gibi şeyler, Robux'la alanlarda tur başında hazırdır.

## 4. Altın (yeni para birimi)
- **Birim:** **1 altın ≈ 1 dakikalık bekleme/gelir.** Tek anlaşılır ölçü; her şey bu birimle fiyatlanır.
- **Kaynak (yalnızca ilerleme):** ada tamamlanınca (adanın tüm yükseltmeleri) **20**, çiftlik tamamlanınca **+50** (24 ada x 20 + 6 çiftlik x 50 = ~780 altın/tur, taslak). Tur başına sınırlıdır; rebirth sonrası ada ve çiftlikler yeniden bitirilince yine kazanılır.
- **Kullanım:**
  - **Hızlı bitir:** devam eden üretim partisi, hayvan büyümesi, eklenti bekleyişi (kalan dakika kadar altın; en az 1).
  - **Paraya çevir:** 1 altın = etkin çiftliğin **0,5 dakikalık gelirine** karşılık nakit (taslak). Çevirme oranı anlık gelire bağlı olduğundan erken/geç oyunda aynı "zaman değeri" verir.
  - **İsteğe bağlı:** altınla Robux eşyası alınmaz (Robux eşyaları yalnızca Robux).
- **Kalıcılık:** altın **rebirth'te kalır** (hesap düzeyi, Robux'la alınabilir). Kayıt: `gold` hesap alanı.
- **Koruma:** dönüşüm ve hızlı bitirme sunucuda, `RequestGuard` + hız sınırı + `requestId`; kazanım yalnızca sunucuda hesaplanan "ada tamamlandı" olayından, istemci miktar gönderemez.

## 5. Robux Marketi
Dükkândaki "Destek paketleri" bölümü **Robux Marketi** penceresine dönüşür (`StoreSection` genişler):
- **Altın paketleri** (örn. 100 / 500 / 1500 altın; fiyatları sen koyarsın).
- **Anlık para paketleri**: "N dakikalık gelir" biçiminde (mevcut `incomePack` mantığı); tutar etkin çiftliğin o anki gelirine göre hesaplanır, **sabit para miktarı satılmaz**.
- **Tur boyunca 2x gelir** ve **üretimi tamamla** (tur içi ürünler, `REBIRTH_PLANI` bölüm 9).
- Robux eşyaları ve kalıcı kolaylıklar için "Robux ile al" düğmeleri ilgili pencerelerde (Pazar/Envanter/Yükseltmeler) de görünür.

Neden altın ve gelire göre ölçülen para: **doğrudan sabit miktar para** erken oyunda tüm kademeleri atlatır (Çiftlik 2 = 590K), geç oyunda değersiz kalır. Altın tek bir dönüşüm noktasıdır (1 altın = 1 dk), gelir paketi ise gelirle ölçeklenir; ikisi de aşamadan bağımsız adil kalır ve tek yerden ayarlanır.

## 6. Rebirth ile etkileşim
| | Rebirth'te |
|---|---|
| Nakitle alınan eşya, yükseltme, yardımcı, toplayıcı | sıfırlanır |
| Robux'la alınan eşya, kalıcı kolaylık | **kalır** |
| Altın | **kalır** |
| Tur içi Robux ürünleri (2x gelir, üretimi bitir) | sıfırlanır (her turda tekrar alınır) |
| Rebirth etkileri, rebirth kozmetikleri | kalır |

`REBIRTH_PLANI.md` bölüm 5 tablosu buna göre okunur (envanterin Robux ile alınan kısmı istisna).

## 7. Uygulama sırası
1. **Eşya etkileri** (en az risk): `Config/Items.luau` görünüm eşyalarına etki, `tests/config.spec.luau`'ya "etkisiz eşya yok" değişmezi, çeviri (en/de/ru/es/pt), `ItemText` etki satırları.
2. **Altın:** `GameTypes` + `SaveCodec/Account` (`gold`), `SessionLock.VERSION`, ada/çiftlik tamamlama olayı (`FarmMath.isIslandComplete`), `GoldService` (hızlı bitir, çevir), HUD rozeti, testler.
3. **Robux sahipliği:** `Config/Shop.luau` Robux eşya/kalıcı kolaylık kimlikleri, `MonetizationService` yeni etkiler (`owned` kalıcı işaret), makbuz testleri.
4. **Market penceresi:** `StoreSection` genişletme, altın/gelir paketleri.
5. **Sim/denge:** `--rebirth`, eşya+etki toplam tavanı, altın kazanım/dönüşüm oranı; `audit-economy.py` ve `ECONOMY_LIMITS`'e eşya/altın sınırları.
6. Rebirth planı uygulamasıyla birleşir (`REBIRTH_PLANI.md` bölüm 10).

## 8. Açık noktalar
- Altın miktarları ve dönüşüm oranı sim ile ayarlanır (taslak: ada 20, çiftlik +50, 1 altın = 0,5 dk gelir).
- Robux fiyatları ve paket büyüklükleri sana ait karar.
- Görünüm eşyalarına verilen etkiler ve nakit fiyatlar tur süresi hedefini bozmamalı; toplam tavan sim ile doğrulanır.
- "Robux ile al" düğmesinin Pazar penceresinde nasıl görüneceği (kart başına ikinci düğme mi, ayrı sekme mi) arayüz kararı.
