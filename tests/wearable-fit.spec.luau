--!strict
return function(WearableFit: any)
	assert(WearableFit.backOffset(0.5) == 0, "Normal avatar görünümü korunmalı")
	assert(
		math.abs(WearableFit.backOffset(1.2) - 0.7) < 1e-9,
		"Kalın gövde için sırt eşyası dışarı taşınmalı"
	)
	assert(WearableFit.backOffset(0.3) == 0, "İnce gövdede eşya içeri taşınmamalı")
	print("Wearable fit checks passed")
end
