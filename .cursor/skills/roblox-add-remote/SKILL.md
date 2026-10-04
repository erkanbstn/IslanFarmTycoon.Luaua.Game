---
name: roblox-add-remote
description: Adds a new RemoteEvent end to end in this Roblox Luau project (Remotes.luau list, validated server handler with RateLimiter and request ids, client call, result/notify, tests). Use when the user wants a new client-to-server action, button that changes server state, or a new server-to-client message.
---

# Yeni remote ekleme

```
- [ ] 1. Remotes.luau: EventName tipine ve EVENTS listesine ekle (yorumda argümanlar)
- [ ] 2. Sunucu işleyicisi (ilgili Service.init içinde)
- [ ] 3. Client çağrısı
- [ ] 4. Metinler + çeviri
- [ ] 5. Test + doğrulama
```

## 1. Remotes.luau
```luau
export type EventName = ... | "RequestFeedAnimal"
local EVENTS = {
	"RequestFeedAnimal", -- Client -> Sunucu hayvanı besle (uid, requestId, expectedFarmId)
```
Ad kalıbı: istek `Request<Fiil><Nesne>`, sonuç `<Alan>Result`.

## 2. Sunucu işleyicisi (`src/server/Services/` içinde; AnimalService/UpgradeService kalıbı)
Remote argümanları `(değer, requestId, expectedFarmId, ekstra?)`. Etkin çiftlik kontrolü ve hız sınırı cevabı `Services/RequestGuard`'dadır; elle kopyalama.
Para girişi kazançsa `addCash`, iade/satışsa `PlayerDataService.addRefund` (başarım sayacına girmez); harekete kategori (`reason`) ver (telemetri: `docs/TELEMETRI.md`).
```luau
function FeedService.tryFeed(player: Player, uid: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "feed", 0.3) then
		return false, nil -- ok=false + mesaj nil = hız sınırı; RequestGuard.reply bunu sınırlı cevaplar
	end
	if not RateLimiter.validId(uid) then
		return false, "Geçersiz istek"
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return false, "Veri henüz yüklenmedi"
	end
	-- mantık doğrulaması: sahiplik, kilit, kapasite, fiyat Config/FarmMath'ten
	EconomyService.settlePlayer(player)
	-- durum değişikliği...
	FarmMath.applyDerived(data)
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	return true, nil
end

Remotes.get("RequestFeedAnimal").OnServerEvent:Connect(function(player: Player, uid: unknown, requestId: unknown, expectedFarmId: unknown)
	if not RateLimiter.acceptRequest(player, requestId) then -- requestId zorunlu; kimliksiz/tekrar istek reddedilir
		return
	end
	if not RequestGuard.activeFarm(player, requestId, expectedFarmId) then -- etkin çiftlik değiştiyse oyuncuya söyler, nil döner
		return
	end
	local ok, message = FeedService.tryFeed(player, uid)
	RequestGuard.reply(player, requestId, ok, message) -- kimlik varsa PurchaseResult, yoksa Notify
end)
```
`RateLimiter.acceptRequest`'in 3. argümanı (`allowMissing`) yalnızca sunucu içi ProximityPrompt çağrısı içindir; Remote işleyicisinde verme.
Seçenekler: `RequestGuard.activeFarm(player, requestId, expectedFarmId, { message = "...", notifyWithoutId = true, countRejected = true })`; ret sayacı için `RequestGuard.reply(..., true)`.
Client'ın gönderdiği konum/mesafe yerine sunucu ölçer (`PlotService.isNearPlot(player, radius)`).
Yeni servis dosyasıysa `src/server/Services/<Ad>Service.luau` olarak aç ve `src/server/init.server.luau` içinde `require` + `init()` sırasına ekle. Görsel sonuç gerekiyorsa `PlotService.refreshPlayerWorld` çağır (çizim `Presentation/`'da); `Presentation` para/kayıt yazmaz.

## 3. Client
- Satın alma/tekil işlem: `PurchaseController.submit("RequestFeedAnimal", uid, extra?)` — bekleyen istek,
  ortak artan kimlik, `expectedFarmId` (etkin çiftlik), zaman aşımı ve `PurchaseResult` eşleşmesini hazır yapar;
  sunucuya `(uid, requestId, expectedFarmId, extra)` gider.
- Basit tetik: `Remotes.get("X"):FireServer(...)`. Client gönderilen önizleme tutarı/adedi otorite sayılmaz; sunucu canlı hesabı ve izin verilen sınırı yeniden doğrular.

## 4. Metinler
Tüm ret/başarı mesajları tam Türkçe cümle, emojisiz; `src/shared/Locales/` altındaki tüm sözlüklere ekle
(bkz. `roblox-localize` skill'i).

## 5. Test
- Mantık saf fonksiyonsa `src/server/Modules/*Rules.luau`'ya koy ve spec yaz.
- Servis testi: `tests/animal-service.spec.luau` / `tests/upgrade-service.spec.luau` gibi, `tests/service-harness.luau` ile
  (gerçek servis + gerçek `RequestGuard`, sahte Roblox sınırları); `scripts/run-tests.py`'ye kaydet. Sahte oyuncuyla:
  geçersiz tip, kimliksiz/tekrar requestId, yanlış `expectedFarmId`, hız sınırı, veri yokken, başarı.
- Gerçek kaynak modülünün bağımlılığını `python scripts/check-test-dependencies.py` ile denetle; `roblox-verify` skill'iyle doğrula.
