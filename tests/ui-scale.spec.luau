--!strict
-- Kök arayüz ölçeği kademeleri (saf).
return function(UiScale: any)
	assert(UiScale.forViewport(800, 360) == 0.85, "phone landscape shrinks")
	assert(UiScale.forViewport(360, 800) == 0.85, "phone portrait uses the short side")
	assert(UiScale.forViewport(1024, 768) == 1, "tablet stays 1")
	assert(UiScale.forViewport(1920, 1080) == 1, "1080p stays 1")
	assert(UiScale.forViewport(2560, 1440) > 1, "1440p grows")
	assert(UiScale.forViewport(3840, 2160) > UiScale.forViewport(2560, 1440), "4K grows further")
	assert(UiScale.forViewport(0, 0) == 1 and UiScale.forViewport(0 / 0, 100) == 1, "bad sizes fall back to 1")
	print("PASS ui scale: phone shrinks, 1440p+ grows, bad sizes fall back")
end
