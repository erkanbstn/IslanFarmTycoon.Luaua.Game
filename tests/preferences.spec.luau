--!strict
-- Ses düzeyi ve hareket azaltma tercihleri: kayıt çözümü, doğrulama ve öznitelikler (saf).
return function(Preferences: any, SaveCodec: any, Config: any, FarmMath: any)
	assert(Preferences.isKind("sfx") and Preferences.isKind("ambience") and Preferences.isKind("music"))
	assert(Preferences.isKind("reducedMotion"))
	assert(not Preferences.isKind("master") and not Preferences.isKind(5) and not Preferences.isKind(nil))

	assert(Preferences.volume(0.5) == 0.5 and Preferences.volume(2) == 1 and Preferences.volume(-1) == 0)
	assert(Preferences.volume(0.123456) == 0.12, "volume rounds to 0.01")
	assert(Preferences.volume(0 / 0) == nil and Preferences.volume(math.huge) == nil, "non-finite is rejected")
	assert(Preferences.volume("0.5") == nil and Preferences.volume(nil) == nil and Preferences.volume(true) == nil)

	-- apply: geçerli yazım, aynı değer değişiklik sayılmaz, geçersiz tür/değer atılır
	local data: any = {}
	assert(Preferences.apply(data, "sfx", 0.4) and data.audio.sfx == 0.4)
	assert(not Preferences.apply(data, "sfx", 0.4), "same value is not a change")
	assert(Preferences.apply(data, "music", 0) and data.audio.music == 0, "zero is a real value")
	assert(not Preferences.apply(data, "ambience", "loud") and data.audio.ambience == nil)
	assert(not Preferences.apply(data, "sfx", 0 / 0) and data.audio.sfx == 0.4)
	assert(not Preferences.apply(data, "master", 1) and not Preferences.apply(data, {}, 1) and data.audio.master == nil)
	assert(Preferences.apply(data, "reducedMotion", true) and data.reducedMotion == true)
	assert(not Preferences.apply(data, "reducedMotion", true))
	assert(not Preferences.apply(data, "reducedMotion", 1) and data.reducedMotion == true, "wrong type is rejected")

	-- öznitelikler: seçilmemiş = ""
	local attributes = Preferences.attributes({})
	assert(
		attributes.SavedSfxVolume == "" and attributes.SavedAmbienceVolume == "" and attributes.SavedMusicVolume == ""
	)
	assert(attributes.SavedReducedMotion == "")
	attributes = Preferences.attributes(data)
	assert(
		attributes.SavedSfxVolume == 0.4 and attributes.SavedMusicVolume == 0 and attributes.SavedAmbienceVolume == ""
	)
	assert(attributes.SavedReducedMotion == true)

	-- decode: bozuk değerler yok sayılır, geçerliler korunur
	local audio, reduced =
		Preferences.decode({ audio = { sfx = 0.3, ambience = "x", music = 5 }, reducedMotion = "yes" })
	assert(audio and audio.sfx == 0.3 and audio.ambience == nil and audio.music == 1 and reduced == nil)
	audio, reduced = Preferences.decode({})
	assert(audio == nil and reduced == nil, "unset stays unset")
	audio = Preferences.decode({ audio = "loud" })
	assert(audio == nil, "audio must be a table")

	-- Kayıt döngüsü: eski kayıt (alan yok) -> tercih yok; yazılan tercih kayıttan geri gelir
	local now = 2000000000
	local uid = function()
		return "u"
	end
	local old = assert(SaveCodec.decode(nil, Config, FarmMath, now, uid))
	assert(old.audio == nil and old.reducedMotion == nil, "old save has no preferences")
	old.audio = { sfx = 0.25, music = 0 }
	old.reducedMotion = true
	local reloaded = assert(SaveCodec.decode(SaveCodec.encode(old, now), Config, FarmMath, now, uid))
	assert(reloaded.audio and reloaded.audio.sfx == 0.25 and reloaded.audio.music == 0, "volumes survive saves")
	assert(reloaded.audio.ambience == nil and reloaded.reducedMotion == true)
	local corrupt = SaveCodec.encode(old, now)
	corrupt.audio = { sfx = "loud", ambience = 0 / 0, music = 0.7 }
	corrupt.reducedMotion = { true }
	local fixed = assert(SaveCodec.decode(corrupt, Config, FarmMath, now, uid))
	assert(fixed.audio and fixed.audio.sfx == nil and fixed.audio.ambience == nil and fixed.audio.music == 0.7)
	assert(fixed.reducedMotion == nil, "reducedMotion must be a boolean")
	print("PASS preferences: volume/reducedMotion validation, attributes and save round trip")
end
