--!strict
-- Dönüş özeti ek satırları (saf, Roblox'a dokunmaz): günlük ödül, hazır sipariş, gezgin tüccar ve altın hayvan.
-- Her şey sunucuda kayıttan hesaplanır (istemciden hiçbir değer alınmaz); yeni kalıcı durum yoktur. Alanlar isteğe bağlıdır:
-- yalnızca ilgili olanlar yazılır, eski istemci üçüncü bağımsız değişkeni yok sayar, yeni istemci eksik alanı "yok" sayar.
-- Bağımlılıklar (Rewards, FarmMath, Merchant, Golden) çağıran tarafından verilir.

export type Brief = {
	daily: boolean?, -- günlük ödül şu an alınabilir
	orders: number?, -- teslime hazır sipariş sayısı (1+)
	merchant: boolean?, -- gezgin tüccar şu an meydanda (alınmamış teklifi var)
	golden: boolean?, -- altın hayvan şu an parlıyor
}

export type Deps = { Rewards: any, FarmMath: any, Merchant: any, Golden: any }

local OfflineBrief = {}

-- Sipariş sayısı küçük tutulur: mesaj kısa kalsın ve hesaplanan değer sınırlı olsun.
OfflineBrief.MAX_ORDERS = 99

-- Hata fırlatırsa özet yine de gider (ek satırlar süs): çağıran pcall ile sarar, burada tek tek korunur.
function OfflineBrief.build(data: any, userId: number, now: number, deps: Deps): Brief
	local brief: Brief = {}
	local okDaily, daily = pcall(function(): boolean
		return deps.Rewards.dailyStatus(data.daily, now).canClaim == true
	end)
	if okDaily and daily then
		brief.daily = true
	end
	local okOrders, orders = pcall(function(): number
		return deps.FarmMath.getReadyContractCount(data, now, 0)
	end)
	if okOrders and typeof(orders) == "number" and orders >= 1 then
		brief.orders = math.min(OfflineBrief.MAX_ORDERS, math.floor(orders))
	end
	local okMerchant, status = pcall(function(): any
		return deps.Merchant.status(data, userId, now)
	end)
	if okMerchant and status and status.visit and not status.bought and status.offer then
		brief.merchant = true
	end
	local okGolden, golden = pcall(function(): any
		return deps.Golden.current(data, userId, now)
	end)
	if okGolden and golden then
		brief.golden = true
	end
	return brief
end

return OfflineBrief
