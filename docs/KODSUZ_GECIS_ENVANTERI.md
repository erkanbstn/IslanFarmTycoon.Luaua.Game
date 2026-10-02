# Kodla üretilen görseller: modele geçiş (tamamlandı)

Bu belge 2026-10-02'ye kadar kodla çizilen görsellerin envanteriydi (dosya:satır listesi). Geçiş tamamlandı: görünen geometri `assets/` ve `client-assets/` modellerindedir,
kod kurucuları (`UpgradeBuilders*`, `ZoneBuilders*`, `ZoneParts`, `ZoneLevelDecor`, `AnimalModelsSpecies`, `IslandSiteBuilders`, `Home{Houses,Farmland,Market,Landmarks,Parts}` ve ağaç/eşya/kuş/deniz canlısı çizimleri) silinmiştir.
Eski satır numaralı envanter için git geçmişine bak (`git log -- docs/KODSUZ_GECIS_ENVANTERI.md`).

## Güncel kural
- Yeni görsel = `assets/<klasör>/<ad>.rbxmx` modeli + `scripts/check-assets.py` beklentisi + kodda `ModelAssets.clone/place` (`docs/MODEL_SOZLESMESI.md`, `.cursor/rules/world-map.mdc` "Model tabanlı görseller").
- Kodda bilerek kalan geometri: zemin plakaları (`Ground`), Terrain/kıyı/plaj, taş yollar, çim yamaları, dağ halkası, `SeasonalScenery` havuz parçaları (`SeasonFragment`, `WinterTwig`), `Bubble`/`Kelp` (animasyonlu, parça başına).
- Model işleri için ajan sözleşmesi `docs/GPT_MODEL_IS_LISTESI.md`, iş defteri `docs/GPT_ILETISIM.md`.
