# Tuzaklar

- `.test-build/` (~146 MB) ve `.tools/` (~114 MB) git dışı büyük klasörlerdir (`.gitignore`); Grep/Glob'u buraya yöneltme, `--glob '!.test-build'` ile dışla. Taranacak yer değil, araç/çıktı deposudur.
- `.test-build/run*.luau` geçici koşu dosyalarıdır ve birikir (şu an 13 tane). Öneri: işi bitince eskilerini kullanıcıya sorarak temizle; kendiliğinden SİLME.
- `assets/` (~23 MB) görünen dünya geometrisinin kaynağıdır (`.rbxmx` modeller); kodda geometri üretme, ayrıntı `docs/MODEL_SOZLESMESI.md`.
- Büyük dosyaları (Config/init, GameTypes, PlotService, DEVIR_DURUMU, Locales) baştan okuma: `.claude/docs/hot-files.md` satır haritasını kullan.
