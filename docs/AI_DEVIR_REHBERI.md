# AI devir rehberi

Bu belge yeni bir AI oturumunun kısa başlangıç kapısıdır. Temel kaynak `AGENTS.md`; mimari `docs/MIMARI.md`. Tüm kuralları/raporları peşinen okumak yerine görevle ilgili kaynak, tüketici ve testten ilerle.

## Başlangıç

Devralırken `docs/DEVIR_DURUMU.md` içindeki güncel dal, doğrulama ve açık riskleri de oku. Yerel `.cleanup-archive/` tarihsel belgeleri saklar; aktif kaynak değildir.

0. **İlk komut:** `python scripts/triage.py` (salt okunur): dal, değişen dosyalar, doctor/hijyen özeti, ilgili kural + skill ve çalıştırılacak en küçük kontroller. `--run` ucuz olanları çalıştırır, `--json` makine çıktısıdır; görev→komut yemek kitabı `docs/HIZLI_AKSIYON.md`. Hızlı spec alt kümesi: `python scripts/smoke-quick.py --only <ad>`.
1. Kullanıcının son isteğini ve oturumda verilmiş yayın/git/veri yetkisini belirle. Çalışan yerin doğru depo olduğunu doğrula: `git branch --show-current`, `git status --short`, `git diff --stat`. Mevcut kullanıcı değişikliklerini bir başlangıç notunda işaretle; temizlemek için reset/stash yapma.
2. `python scripts/doctor.py` ile kurulu araç/yerel durum teşhisini al. Teşhis tek başına test değildir; kurulum ve ağ mutasyonu yapmaz.
3. `AGENTS.md` tablosundan yalnız ilgili kuralları aç. Dosya eklemeden veya katman sınırı değişmeden önce MIMARI'nin ilgili bölümünü oku. Ekonomi/model işinde yalnız ilgili sözleşmeyi yükle.
4. `.cursor/skills/roblox-verify/SKILL.md` hızlı döngüsünü başlangıçta çalıştır (depo hijyeni dahil). Bir dosyayı silince/yeniden adlandırınca veya yeni belge/betik eklenince `python scripts/check-repo-hygiene.py` ile hemen doğrula. Önceden var olan başarısızlıkları kendi değişikliğinle ayır; eksik aracı veya atlanan kontrolü başarı sayma.
5. Güvenle kanıtlanmış sorunu küçük değişiklikle çöz, gerçek davranış testini güncelle. Para/ödül/bekleme dengesi değiştiyse aynı koşullu önce/sonra ölçümünü kaydet. Sonunda gerekli Full ve Studio kanıtını topla.

## Hangi kaynak neyi söyler?

| Soru | İlk kaynak |
|---|---|
| Kod nerede; kim kime bağlanabilir? | MIMARI + ilgili kaynak require'ları |
| Fiyat, süre, ödül, rebirth hedefi nedir? | Config + FarmMath/Progression; ilgili spec/sim |
| UI ve çeviri nasıl kurulur? | client-ui/localization + UiKit/Localizer |
| Model/harita sözleşmesi nedir? | MODEL_SOZLESMESI + check-assets + MapBuilder.validate |
| Kayıt/makbuz/aktarımı güvenle nasıl değiştiririm? | save-schema skill + SaveCodec/SaveStore/PlayerDataService testleri |
| Araçlar/testler nasıl çalışır? | roblox-verify skill; CLI `--help`; verify.ps1 |

Tarihsel `docs/*RAPOR*`, optimizasyon ve denge analizleri, yazıldıkları ref/koşulun kanıtıdır. Güncel kaynakla karşılaştırmadan oradaki açık sorunları tekrar uygulama veya eski taslağı canlı ekonomi sanma. Rapor süresi/model sayısı/locale sayısı çalıştırılmış yeni çıktı yerine geçmez.

## Konu belgeleri dizini

Her `docs/` dosyası burada anılır (`scripts/check-repo-hygiene.py` anılmayan belgeyi hata sayar). Tarihsel olanlar kanıttır, güncel davranış yerine geçmez.

| Konu | Belge |
|---|---|
| Mimari, katmanlar, dosya yeri | `MIMARI.md`, `LOBI_VE_ADA_MIMARISI.md` |
| Güncel devir, açık riskler | `DEVIR_DURUMU.md` |
| Görev -> dosya -> komut yemek kitabı | `HIZLI_AKSIYON.md` |
| Fiyat/zorluk, üretim, tüccar dengesi | `ZORLUK_VE_FIYAT.md`, `URETIM_VE_UZMAN_ADALAR.md` |
| Rebirth, altın ve Robux | `REBIRTH_PLANI.md`, `ROBUX_VE_ALTIN_PLANI.md` |
| Ada ve çiftlik tasarımı | `ADA_TASARIMI.md`, `ANA_CIFTLIKLER.md`, `MEVSIM_GORSELLERI.md` |
| Model sözleşmesi ve iş akışı | `MODEL_SOZLESMESI.md`, `MODEL_IS_PLANI.md`, `GPT_MODEL_IS_LISTESI.md`, `ANIMAL_LINEAGE_MODELLERI.md`, `ANIMAL_LINEAGE_MODELLERI.csv`, `ITEM_MODEL_TESLIMI.csv`, üreticiler `model-ureticileri/` |
| Ses ve telemetri | `SESLER.md`, `TELEMETRI.md` |
| Yayın ve arkadaş testi (elle Studio/Roblox paneli) | `YAYIN_VE_ARKADAS_TESTI.md` |

## Studio senaryolarını kullanırken

Komutlar ve başlangıç akışı `roblox-verify` skill'indedir. `command` çıktısı yalnızca kod üretir; Studio Server Play bağlamında çalıştırılması gerekir. İstekten sonra `inspect --side server` çıktısıyla `LastResult.status` değerini kontrol et; isteği göndermek başarı kanıtı değildir. Her istekte artan `--request-id` kullan. Hazır olmayan oyuncu ve eski istekler tekrar uygulanmaz.

`--rebirth-level 0..30` desteklenir. `fresh` hayvansız başlangıç profili; `merchant` test bütçesi ve geçici tüccar ziyareti; `production` ilk çiftliğin açılmış tesis/hayvanları ve bir otomatik tekrar; `rebirth-ready` altı çiftliğin tamamlanmış profilidir. Rebirth puanları geçerli kayıt oluşturmak için alfabetik perk sırasıyla dağıtılır; bu, önerilen oyuncu stratejisi veya gerçek 30 tur oynanış simülasyonu değildir. R30 terminal seviyedir.

Client inspect yalnızca o anda görünen arayüzün metin sığmasını ve buton yollarını bildirir. Kapalı pencereleri açmaz, satın alma yapmaz; sıfır boyutlu geçici nesneleri atlar. Görsel inceleme, tıklama akışı ve cihaz testi ayrıca yapılmalıdır. Araçların bu geliştirmedeki kanıtları ve sınırları `docs/DEVIR_DURUMU.md` içindedir.

## Çalışma ve teslim kaydı

Kapsam çok aşamalıysa görev için tek kalıcı rapor tut; eski raporu değiştirmek yerine tarih/ref ve durumunu belirt. Kısa devir kaydı şu bilgileri taşımalı:

- Amaç ve kapsam; aktif dal/ref; başlanırken mevcut değişiklikler.
- Değişen dosyalar, kanıtlı davranış düzeltmesi ve varsa bilinçli sözleşme değişikliği.
- Çalıştırılan komut/sonuç, koşullar, `.test-build/` ölçüm/QA artifact yolları; artifact git dışında ise alıcının yeniden üretme komutu.
- Kalan gerçek hata/belirsizlik, Studio'da görülmeyen davranış ve somut sonraki adım.
- Commit/push/publish veya veri sıfırlama için verilmiş/henüz verilmemiş yetki; sırlar ve tam oyuncu kayıtları kayda konmaz.

Doğrulama, yayın yetkisi vermez. QA place canlıya yayınlanmaz; yönetici reset düğmesi duman testi değildir. Son kullanıcıya, çalışan sistem ile sim/mock/derleme kanıtını açıkça ayırarak kısa Türkçe sonuç ver.
