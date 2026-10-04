# Model iş akışı (Studio MCP ajanıyla model üretimi)

Yüzey birleşimi bakımı: `python tools/models/refine_surface_joins.py` tavus kuşunun kuyruk katmanlarını ayırır ve pencere köşelerini yan duvarlara çakışmadan birleştirir. Betik tekrar çalıştırılabilir; yalnız bu geometriyi değiştirir. Hayvan/üretim binası modelleri çalışma anında kurulur, harita sürümü veya yeniden kurulum gerekmez. `check-assets.py` bu köşe ve kuyruk sözleşmelerini doğrular.

Kurallar `docs/MODEL_SOZLESMESI.md`'dedir; bu belge yalnız modeli repoya alma yolunu ve riskleri anlatır. 2 Ekim 2026'daki pilot
planı (P0 dışa aktarma denemesi, `duck_packer` pilotu, K1–K5 kod kararları, Sonnet/Haiku şablonları) tamamlandı ve arşivlendi
(`git log -p -- docs/MODEL_IS_PLANI.md`); sonuç: bütün görünür geometri `assets/` altındaki `.rbxmx` dosyalarındadır.

## Repoya alma yolu

| Yol | Durum |
|---|---|
| **`.rbxmx` (Studio → Save to File) veya Python üreticisiyle XML yazma** | Kullanılan yol. XML olduğu için diff ve `check-assets.py` denetimi çalışır; pivot, PrimaryPart, etiket ve öznitelik korunur. |
| `.model.json`, `rojo syncback`, SerializationService | Kullanılmıyor: pivot/öznitelik desteği Rojo 7.4.4'te doğrulanmadı, syncback Rojo 7.7 ister (`rokit.toml` pini 7.4.4). |

- Studio'da çalışırken tezgâh `Workspace.ModelBench`'tir. `ServerStorage.Assets` `$path: "assets"` ile eşlidir; `rojo serve` bağlanınca orada kurulan model silinir, ajan oraya yazmaz. Dosya tek kaynaktır.
- Parça kuralı: yalnız `Part`/`WedgePart`; elips için `Block` + `SpecialMesh` (`Sphere`). `MeshPart` ve Rojo'nun canlı eşleyemediği ikili tipler yok.
- Yeni model sonrası `python scripts/check-assets.py` temiz olmalı; model yoksa görünüm çizilmez ve denetim kırmızı olur.

## Harita eklentisi ve `MAP_VERSION`

- Binalar/hayvanlar çalışma anında `Presentation/` tarafından kurulur: `MAP_VERSION` artmaz, eklenti yeniden derlenmez.
- Bölge zemini/çiti (`MapParts.buildZone`) veya `World/` dekoru modelle değişirse `MAP_VERSION` artırılır ve Studio haritası yeniden kurulur; yalnız `plugin/` değişirse eklenti yeniden derlenip Studio yeniden açılır (`roblox-map-change` skill'i).

## Modele çevrilmeyenler ve riskler

- Kodda kalır: model seçimi/yerleşimi/boyutlandırması, animasyon, görünmez işlev çapaları, gece lambası sözleşmesi, tabela yazıları (`WorldUi`) ve Terrain. Ayrıntı: `docs/GPT_MODEL_IS_LISTESI.md` §2.
- MCP istemcisi açık place'i değiştirebilir; yalnız güvenilir istemci bağla, ajan oturumundan önce place yedeği al (repo dışı).
- Ad kimliktir: dosya/Model adı yanlışsa oyunda görünmez; `check-assets.py` ilk adımda yakalar.
- Geri alma: dosyayı Git geçmişinden getir.
