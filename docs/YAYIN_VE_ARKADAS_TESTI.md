# Yayınlama ve arkadaşlarla test

Kod tarafı hazırdır (kayıt, yedek, 6 oyunculu ada atama, yetki, satın alma kapalı ürünler). Aşağıdakiler Studio/Roblox
panelinde elle yapılır; kod bunları değiştiremez.

## Yayınlamadan önce (Studio)
1. `rojo serve` ile bağlan, **Haritayı Kur → Doğrula → Ctrl+S** (MAP_VERSION değişince şart; doğrulama geçmeden yayınlama).
2. **Game Settings → Basic Info → Max Players = 6** (haritada 6 ada var; fazlası "boş ada kalmadı" ile reddedilir).
3. **Game Settings → Security → Enable Studio Access to API Services** açık olsun (Studio'da DataStore testi için; yayında gerekmez).
4. `Config.DEBUG = false` (varsayılan) ve Workspace'te `StudioNonPersistentData` özniteliği yok.
5. Tek başına çık-gir turu: para/hayvan al, çık, tekrar gir; `ServerStorage.Diagnostics` ve oyuncunun `DataBytes`/`DataBackupAt` değerlerine bak.
6. **Test → Clients → 2 oyuncu** ile yerel sunucu dene: iki oyuncu farklı ada alır, biri çiftlik değiştirince diğerinin adası etkilenmez.

## Yayınlama
1. **File → Publish to Roblox** (yeni deneyim oluştur). Haritanın place içinde kayıtlı olduğundan emin ol.
2. Deneyim sayfası **Settings → Privacy: Private** (ya da yalnızca arkadaşlara): arkadaşlarını **Permissions** ile ekle,
   ya da **Public** yapıp bağlantıyı yalnızca onlarla paylaş. Yayın **Save to Roblox** ile kaydedilmeden arkadaşlar son sürümü görmez.
3. Kayıt DataStore'u yayınlanmış deneyimde otomatik çalışır (anahtar: `IslandFarmTycoon_v1`; Studio `_Studio` ekli ayrı depo kullanır).
4. `AdminPolicy` yalnızca sabit UserId'ye yetki verir (`OWNER_USER_ID`). Kendi UserId'nle eşleştiğini kontrol et;
   arkadaşların yönetici paneline erişemez.

## Arkadaşlar girdiğinde
- Herkes boş adalardan rastgele birini alır ve Çiftlik 1 ile başlar; başkasının adasına ziyaret edebilir ama müdahale edemez.
- 6 kişiden fazlası "Sunucuda boş ada kalmadı" mesajıyla düşer; başka sunucuya yönlendir.
- Gerçek parayla (Robux) satın alma ürünleri, kimlikleri (`Config.PRODUCTS`) 0 iken kapalıdır.

## Sorun olursa
- Çökme/kayıp şüphesi: Output'ta `[Data]` satırları (`SaveRetry`, `ProfileRecovered`, `SaveSize...`), `Diagnostics` sayaçları.
- Bozuk kayıt yedekten açılır; bozulan kayıt `player_<id>_quarantine` anahtarında durur (silinmez).

## Yayındaki oyunu güncelleme
1. Studio'da **Rojo ile bağlan** (`rojo serve` + eklenti Connect), kod değişikliklerini senkronla.
2. Harita/yerleşim değiştiyse (MAP_VERSION arttıysa) **Haritayı Kur → Doğrula**; kodla harita uyumsuzsa oyun yeni sürümde oyuncuyu atar.
3. Tek başına bir deneme yap (Test), sonra **Dosya → Roblox'a Yayınla** (Publish to Roblox). Kayıt şemasındaki eski kayıtlar otomatik göç eder.
4. Açık sunucular eski sürümle çalışmaya devam eder. Yeni sürümü hemen görmek için Yaratıcı Merkezi'nde oyunun **Server management** (Sunucu yönetimi) bölümünden **Shut down all servers** de; oyuncular yeniden girer. Kapanışta kayıtlar yazılır (`BindToClose`), ilerleme kaybolmaz.
5. Arkadaşlarla oynarken büyük güncellemeyi, oyun boşken yap; kapanış 30 saniyeye kadar sürebilir.
