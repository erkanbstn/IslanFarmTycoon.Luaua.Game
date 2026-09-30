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

## 2. Sunucu işleyicisi (`src/server/Services/` içinde; UpgradeService/AnimalService kalıbı)
Para girişi kazançsa `addCash`, iade/satışsa `PlayerDataService.addRefund` (başarım sayacına girmez).
```luau
function FeedService.tryFeed(player: Player, uid: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "feed", 0.3) then
		return false, nil -- nil = sessiz ret; yanıtı ayrıca sınırla
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
	local data = PlayerDataService.tryGet(player)
	if not data or expectedFarmId ~= data.activeMainFarmId then
		return
	end
	if not RateLimiter.acceptRequest(player, requestId) then
		return
	end
	local ok, message = FeedService.tryFeed(player, uid)
	if typeof(requestId) == "number" and (message or ok) then
		Remotes.get("PurchaseResult"):FireClient(player, requestId, ok, message)
	end
end)
```
Yeni servis dosyasıysa `src/server/Services/<Ad>Service.luau` olarak aç ve `src/server/init.server.luau` içinde `require` + `init()` sırasına ekle. Görsel sonuç gerekiyorsa `PlotService.refreshPlayerWorld` çağır (çizim `Presentation/`'da); `Presentation` para/kayıt yazmaz.

## 3. Client
- Satın alma/tekil işlem: `PurchaseController.submit("RequestFeedAnimal", uid)` — bekleyen istek,
  artan kimlik, zaman aşımı ve `PurchaseResult` eşleşmesini hazır yapar.
- Basit tetik: `Remotes.get("X"):FireServer(...)`. Client hiçbir zaman fiyat/adet göndermez.

## 4. Metinler
Tüm ret/başarı mesajları tam Türkçe cümle, emojisiz; `en/de/ru.luau`'ya ekle
(bkz. `roblox-localize` skill'i).

## 5. Test
- Mantık saf fonksiyonsa `src/server/Modules/*Rules.luau`'ya koy ve spec yaz.
- Servis testi: mevcut `tests/production.spec.luau` gibi factory + sahte `Remotes`/`RateLimiter`;
  `scripts/run-tests.py`'ye kaydet. Sahte oyuncuyla: geçersiz tip, tekrar requestId, hız sınırı,
  veri yokken, başarı.
- `roblox-verify` skill'i ile doğrula.
