--!strict
-- ClientState modülünü FarmHud'dan önce yükler; yükleme ekranı snapshot'ı kaçırmaz.
require(script.Parent:WaitForChild("ClientState"))
