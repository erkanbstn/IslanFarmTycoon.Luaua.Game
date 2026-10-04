# Yayınlama ve arkadaşlarla test

Otomatik kontrollerin kapsamı ve kalan gerçek ortam testleri DEVIR_DURUMU.md içindedir. Aşağıdakiler Studio/Roblox
panelinde elle yapılır; kod bunları değiştiremez.

## Yayınlamadan önce (Studio)
1. `rojo serve` ile bağlan, **Haritayı Kur → Doğrula → Ctrl+S** (MAP_VERSION değişince şart; doğrulama geçmeden yayınlama).
2. **Game Settings → Basic Info → Max Players = `Config.MAP_PLOT_COUNT`** (şu an 6; haritadaki ada sayısı; fazlası "boş ada kalmadı" ile reddedilir).
3. **Game Settings → Security → Enable Studio Access to API Services** açık olsun (Studio'da DataStore testi için; yayında gerekmez).
4. `Config.DEBUG = false` (varsayılan) ve Workspace'te `StudioNonPersistentData` özniteliği yok.
5. Tek başına çık-gir turu: para/hayvan al, çık, tekrar gir; `ServerStorage.Diagnostics` ve oyuncunun `DataBytes`/`DataBackupAt` değerlerine bak.
6. **Test → Clients → 2 oyuncu** ile yerel sunucu dene: iki oyuncu farklı ada alır, biri çiftlik değiştirince diğerinin adası etkilenmez.

## Yayınlama
1. **File → Publish to Roblox** (yeni deneyim oluştur). Haritanın place içinde kayıtlı olduğundan emin ol.
2. Deneyim sayfası **Settings → Privacy: Private** (ya da yalnızca arkadaşlara): arkadaşlarını **Permissions** ile ekle,
   ya da **Public** yapıp bağlantıyı yalnızca onlarla paylaş. Yayın **Save to Roblox** ile kaydedilmeden arkadaşlar son sürümü görmez.
3. Kayıt DataStore'u yayınlanmış deneyimde otomatik çalışır (anahtar: `IslandFarmTycoon_v2`; Studio `_Studio` ekli ayrı depo kullanır).
4. `AdminPolicy` yalnızca sabit UserId'ye yetki verir (`OWNER_USER_ID`). Kendi UserId'nle eşleştiğini kontrol et;
   arkadaşların yönetici paneline erişemez.

## Arkadaşlar girdiğinde
- Herkes boş adalardan rastgele birini alır ve Çiftlik 1 ile başlar; başkasının adasına ziyaret edebilir ama müdahale edemez.
- 6 kişiden fazlası "Sunucuda boş ada kalmadı" mesajıyla düşer; başka sunucuya yönlendir.
- Gerçek parayla (Robux) satın alma ürünleri, kimlikleri (`Config.PRODUCTS`) 0 iken kapalıdır.

## Para gönderme politikası (PolicyService)
Studio'da otomatik test edilemez; ayrı test place'inde elle doğrula:
1. Tek oyuncuyla Para gönder penceresi açılınca birkaç saniye "Hesap izinlerin kontrol ediliyor" görünür, sonra izin durumuna göre açılır/kapanır. Output'ta `[TradePolicy]` uyarısı olmamalı.
2. İki oyuncu (Test → Clients): ikisi de izinliyse aktarım tamamlanır. Studio bayrağı oyuncu yaşına/bölgeye bağlı olduğundan kısıtlı hesabı yalnız yayındaki sürümde ya da kısıtlı test hesabıyla görebilirsin.
3. Gönderen kısıtlıysa pencere devre dışı ve gerekçeli; alıcı kısıtlıysa gönderen yalnız "şu anda para gönderilemiyor" görür.
4. **Creator Dashboard politika anketi:** "Policy API'ye uyuyor → Yes" yalnızca bu sürüm yayına alınıp yukarıdaki adımlar yayındaki oyunda doğrulandıktan sonra seçilir; kodda ya da bu belgede bir seçim yapılmaz.

## Sorun olursa
- Çökme/kayıp şüphesi: Output'ta `[Data]` satırları (`SaveRetry`, `ProfileRecovered`, `SaveSize...`), `Diagnostics` sayaçları.
- Bozuk kayıt yedekten açılır; bozulan kayıt `player_<id>_quarantine` anahtarında durur (silinmez).

## Yayındaki oyunu güncelleme
1. Studio'da **Rojo ile bağlan** (`rojo serve` + eklenti Connect), kod değişikliklerini senkronla.
2. Harita/yerleşim değiştiyse (MAP_VERSION arttıysa) **Haritayı Kur → Doğrula**; kodla harita uyumsuzsa oyun yeni sürümde oyuncuyu atar.
3. Tek başına bir deneme yap (Test), sonra **Dosya → Roblox'a Yayınla** (Publish to Roblox). Kayıt şeması uyumluluğunu ve mali hakları ayrı test ortamında doğrula; sürüm değiştirmek otomatik göç garantisi vermez.
4. Açık sunucular eski sürümle çalışmaya devam eder. Yeni sürümü hemen görmek için Yaratıcı Merkezi'nde oyunun **Server management** (Sunucu yönetimi) bölümünden **Shut down all servers** de; oyuncular yeniden girer. Kapanışta kayıt denenir (`BindToClose`); kota, kesinti ve belirsiz yazım durumlarını izle, kayıpsızlık garantisi verme.
5. Arkadaşlarla oynarken büyük güncellemeyi, oyun boşken yap; kapanış 30 saniyeye kadar sürebilir.
