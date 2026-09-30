--!strict
-- Küçük Instance yardımcıları (saf mantık; oyun servislerine bağlanmaz).

local InstanceUtil = {}

-- `parent` altında `name` adlı çocuk varsa onu, yoksa yeni bir Folder oluşturup döndürür.
function InstanceUtil.getOrCreateFolder(parent: Instance, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

return InstanceUtil
