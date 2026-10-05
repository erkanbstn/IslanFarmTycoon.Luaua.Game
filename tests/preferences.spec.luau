--!strict
-- Ses düzeyi ve hareket azaltma tercihleri: kayıt çözümü, doğrulama ve öznitelikler (saf).
return function(Preferences: any, SaveCodec: any, Config: any, FarmMath: any)
	assert(
		Preferences.isKind("sfx") and Preferences.isKind("ambience") and Preferences.isKind("music"),
		"known kinds are accepted"
	)
	assert(Preferences.isKind("reducedMotion") and Preferences.isKind("tutorialDone"), "boolean kinds are accepted")
	assert(
		not Preferences.isKind("master") and not Preferences.isKind(5) and not Preferences.isKind(nil),
		"unknown kinds are rejected"
	)

	assert(
		Preferences.volume(0.5) == 0.5 and Preferences.volume(2) == 1 and Preferences.volume(-1) == 0,
		"volume clamps to 0..1"
	)
	assert(Preferences.volume(0.123456) == 0.12, "volume rounds to 0.01")
	assert(Preferences.volume(0 / 0) == nil and Preferences.volume(math.huge) == nil, "non-finite is rejected")
	assert(
		Preferences.volume("0.5") == nil and Preferences.volume(nil) == nil and Preferences.volume(true) == nil,
		"non-number volumes are rejected"
	)

	-- apply: geçerli yazım, aynı değer değişiklik sayılmaz, geçersiz tür/değer atılır
	local data: any = {}
	assert(Preferences.apply(data, "sfx", 0.4) and data.audio.sfx == 0.4, "valid volume is written")
	assert(not Preferences.apply(data, "sfx", 0.4), "same value is not a change")
	assert(Preferences.apply(data, "music", 0) and data.audio.music == 0, "zero is a real value")
	assert(not Preferences.apply(data, "ambience", "loud") and data.audio.ambience == nil, "string volume is rejected")
	assert(not Preferences.apply(data, "sfx", 0 / 0) and data.audio.sfx == 0.4, "NaN volume is rejected")
	assert(
		not Preferences.apply(data, "master", 1) and not Preferences.apply(data, {}, 1) and data.audio.master == nil,
		"unknown or non-string kinds are rejected"
	)
	assert(
		Preferences.apply(data, "reducedMotion", true) and data.reducedMotion == true,
		"reducedMotion boolean is written"
	)
	assert(not Preferences.apply(data, "reducedMotion", true), "same reducedMotion value is not a change")
	assert(not Preferences.apply(data, "reducedMotion", 1) and data.reducedMotion == true, "wrong type is rejected")

	-- öğretici işareti: yalnızca mantıksal değer; false "yeniden göster" demektir
	assert(Preferences.apply(data, "tutorialDone", true) and data.tutorialDone == true, "tutorialDone is written")
	assert(not Preferences.apply(data, "tutorialDone", true), "same tutorialDone value is not a change")
	assert(Preferences.apply(data, "tutorialDone", false) and data.tutorialDone == false, "replay clears the flag")
	assert(
		not Preferences.apply(data, "tutorialDone", "yes") and not Preferences.apply(data, "tutorialDone", 1),
		"non-boolean tutorialDone is rejected"
	)
	assert(Preferences.attributes(data).SavedTutorialDone == false, "false tutorialDone is exposed")
	assert(Preferences.attributes({}).SavedTutorialDone == "", "unset tutorialDone is empty")
	Preferences.apply(data, "tutorialDone", true)

	-- öznitelikler: seçilmemiş = ""
	local attributes = Preferences.attributes({})
	assert(
		attributes.SavedSfxVolume == "" and attributes.SavedAmbienceVolume == "" and attributes.SavedMusicVolume == "",
		"unset volumes are empty strings"
	)
	assert(attributes.SavedReducedMotion == "", "reducedMotion unset is empty")
	attributes = Preferences.attributes(data)
	assert(
		attributes.SavedSfxVolume == 0.4 and attributes.SavedMusicVolume == 0 and attributes.SavedAmbienceVolume == "",
		"written volumes are exposed"
	)
	assert(attributes.SavedReducedMotion == true, "reducedMotion is exposed")

	-- decode: bozuk değerler yok sayılır, geçerliler korunur
	local audio, reduced =
		Preferences.decode({ audio = { sfx = 0.3, ambience = "x", music = 5 }, reducedMotion = "yes" })
	assert(
		audio and audio.sfx == 0.3 and audio.ambience == nil and audio.music == 1 and reduced == nil,
		"decode keeps valid volumes and drops bad ones"
	)
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
	assert(old.audio == nil and old.reducedMotion == nil and old.tutorialDone == nil, "old save has no preferences")
	old.audio = { sfx = 0.25, music = 0 }
	old.reducedMotion = true
	old.tutorialDone = true
	local reloaded = assert(SaveCodec.decode(SaveCodec.encode(old, now), Config, FarmMath, now, uid))
	assert(reloaded.audio and reloaded.audio.sfx == 0.25 and reloaded.audio.music == 0, "volumes survive saves")
	assert(
		reloaded.audio.ambience == nil and reloaded.reducedMotion == true,
		"unset volume and reducedMotion round trip"
	)
	assert(reloaded.tutorialDone == true, "tutorialDone survives saves")
	local corrupt = SaveCodec.encode(old, now)
	corrupt.audio = { sfx = "loud", ambience = 0 / 0, music = 0.7 }
	corrupt.reducedMotion = { true }
	corrupt.tutorialDone = "yes"
	local fixed = assert(SaveCodec.decode(corrupt, Config, FarmMath, now, uid))
	assert(
		fixed.audio and fixed.audio.sfx == nil and fixed.audio.ambience == nil and fixed.audio.music == 0.7,
		"corrupt volumes are dropped on decode"
	)
	assert(fixed.reducedMotion == nil, "reducedMotion must be a boolean")
	assert(fixed.tutorialDone == nil, "tutorialDone must be a boolean")
	print("PASS preferences: volume/reducedMotion validation, attributes and save round trip")
end
