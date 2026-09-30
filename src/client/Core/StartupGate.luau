--!strict
-- Açılış yükünü yaymak: süs efektleri (kuşlar, balıklar, deniz dibi, kıyı buzu) yükleme ekranı kalkana kadar beklemez
-- ama kalkınca da hepsi aynı anda başlamaz; her biri kendi gecikmesiyle sırayla kurulur (tek karede büyük takılma olmasın).
-- Yükleme ekranı (ReplicatedFirst/LoadingScreen) kalkarken oyuncuya "LoadingDone" özniteliğini koyar.

local Players = game:GetService("Players")

local StartupGate = {}

local MAX_WAIT = 45

function StartupGate.wait(extraSeconds: number)
	local player = Players.LocalPlayer
	local deadline = os.clock() + MAX_WAIT
	while player:GetAttribute("LoadingDone") ~= true and os.clock() < deadline do
		task.wait(0.25)
	end
	task.wait(extraSeconds)
end

return StartupGate
