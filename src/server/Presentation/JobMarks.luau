--!strict
-- Bina üstündeki iş ilerlemesi işaretleri (üretim tesisleri ve eklentiler).
-- Sunucu yalnızca Model'e öznitelik yazar ve "JobSite" etiketi koyar; ilerleme çubuğunu ve yeşil tik'i her oyuncunun
-- kendi ekranında client çizer (Interaction/JobProgress.client), böylece süre saniye saniye ağdan geçmez.
--   JobKind      "production" | "extension"
--   JobStartedAt / JobEndsAt   Workspace:GetServerTimeNow() ile aynı saat (saniye)
--   JobCount / JobCapacity     yalnızca eklenti: şu an duran / sığabilecek hayvan
local CollectionService = game:GetService("CollectionService")

local JobMarks = {}

local TAG = "JobSite"
local ATTRIBUTES = { "JobKind", "JobStartedAt", "JobEndsAt", "JobCount", "JobCapacity", "JobLabel" }

-- İlerleme çubuğunun bağlanacağı görünmez nokta: verilen parçanın (tabela) ya da modelin üstünde.
function JobMarks.ensureAnchor(model: Model, near: BasePart?, height: number?): Instance
	local existing = model:FindFirstChild("JobAnchor")
	if existing then
		return existing
	end
	local position: Vector3
	if near then
		position = near.Position + Vector3.new(0, near.Size.Y / 2 + (height or 2), 0)
	else
		local boxCf, boxSize = model:GetBoundingBox()
		position = Vector3.new(boxCf.Position.X, boxCf.Position.Y + boxSize.Y / 2 + (height or 3), boxCf.Position.Z)
	end
	local anchor = Instance.new("Part")
	anchor.Name = "JobAnchor"
	anchor.Size = Vector3.one * 0.2
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow = false, false, false, false
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = model
	if not CollectionService:HasTag(model, TAG) then
		CollectionService:AddTag(model, TAG)
	end
	return anchor
end

function JobMarks.clear(model: Instance)
	for _, name in ATTRIBUTES do
		if model:GetAttribute(name) ~= nil then
			model:SetAttribute(name, nil)
		end
	end
end

-- Üretim işi: çubuk startedAt..readyAt arasında dolar, bitince yeşil tik (teslim alınana kadar) görünür.
function JobMarks.setProduction(
	model: Instance,
	job: { readyAt: number, startedAt: number? }?,
	recipe: { duration: number, displayName: string? }
)
	if not job then
		JobMarks.clear(model)
		return
	end
	model:SetAttribute("JobKind", "production")
	model:SetAttribute("JobStartedAt", job.startedAt or (job.readyAt - recipe.duration))
	model:SetAttribute("JobEndsAt", job.readyAt)
	model:SetAttribute("JobLabel", recipe.displayName)
	model:SetAttribute("JobCount", nil)
	model:SetAttribute("JobCapacity", nil)
end

-- Eklenti: şu an duran hayvan sayısı ve ilk dönecek hayvanın süresi. Kimse yoksa işaret kalkar.
function JobMarks.setExtension(model: Instance, count: number, capacity: number, startedAt: number?, endsAt: number?)
	if count <= 0 or not startedAt or not endsAt then
		JobMarks.clear(model)
		return
	end
	model:SetAttribute("JobKind", "extension")
	model:SetAttribute("JobStartedAt", startedAt)
	model:SetAttribute("JobEndsAt", endsAt)
	model:SetAttribute("JobCount", count)
	model:SetAttribute("JobCapacity", capacity)
end

-- Eklentide duran hayvanlar: sayı ve en erken dönecek olanın süresi (kayıttan; görsel imzası için de kullanılır)
function JobMarks.extensionSummary(save: any, extensionId: string, now: number): (number, number?, number?)
	local count, startedAt, endsAt = 0, nil, nil
	for _, animal in save.animals do
		local task = animal.task
		if task and task.kind == "extension" and task.id == extensionId and now < task.endsAt then
			count += 1
			if endsAt == nil or task.endsAt < endsAt then
				startedAt, endsAt = task.startedAt, task.endsAt
			end
		end
	end
	return count, startedAt, endsAt
end

return JobMarks
