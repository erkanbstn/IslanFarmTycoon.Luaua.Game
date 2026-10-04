# Hızlı aksiyon yemek kitabı

Görev -> dosyalar -> komut. Yalnız gerçek, bu depoda çalışan komutlar. Ayrıntı için ilgili skill (`.cursor/skills/<ad>/SKILL.md`) ve kural (`AGENTS.md` tablosu). Bu belge doğrulama yerine geçmez; Full ve Studio kanıtı `roblox-verify` skill'indedir.

## 0. Her işte: 10 saniyelik döngü

```
python scripts/triage.py                  # durum + kural + skill + en küçük kontrol listesi (salt okunur)
python scripts/triage.py --json           # aynısı makine okunur
python scripts/triage.py --run            # önerilen UCUZ hedefli kontrolleri çalıştır (+ --include-slow yavaşları)
python scripts/smoke-quick.py             # değişenlerin saf Luau spec'leri, bir kaç saniye (--all hepsi)
python scripts/smoke-quick.py --only hud-layout,admin   # elle seç; adlar: --list
python scripts/run-tests.py --list        # --only adları (aynı filtre: run-tests.py --only ad)
```

İş bitince: `powershell -ExecutionPolicy Bypass -File scripts/verify-fast.ps1`; yayın/denge/harita işlerinde Full (`verify.ps1 -Mode Full -RequireTypes`). Alt küme (`--only`) tam paket sayılmaz.

## 1. Yeni remote (istemci -> sunucu işlemi)

- Dosyalar: `src/shared/Remotes.luau` (EventName + EVENTS), ilgili `src/server/Services/*.luau` (işleyici, `RequestGuard`/RateLimiter), `src/client/**` çağrı, `tests/<servis>.spec.luau`.
- Skill: `roblox-add-remote`; kural: `server-security.mdc`.
- Komut: `python scripts/smoke-quick.py --only <servis-spec>` -> `python scripts/check-test-dependencies.py` -> `python scripts/check-locales.py --strict-literals`.

## 2. Ekran / pencere / HUD

- Dosyalar: `src/client/Ui/**` (UiKit bileşenleri), tema `src/shared/UiTheme.luau`, dünya yazıları `src/shared/WorldUi.luau`; test `tests/hud-layout.spec.luau`, `tests/ui-kit-layout.spec.luau`, `tests/market-ui.spec.luau`.
- Skill: `roblox-add-ui`; kural: `client-ui.mdc` (+ efekt/LocalScript ise `client-performance.mdc`).
- Komut: `python scripts/smoke-quick.py` -> `python scripts/check-locales.py --strict-literals` -> `python scripts/check-architecture.py`.
- Elle: telefon/masaüstü, uzun çeviri, gamepad Studio'da görülmeden "bitti" deme.

## 3. İçerik, fiyat, denge (hayvan, ada, yükseltme, tarif)

- Dosyalar: `src/shared/Config/**`, hesap `src/shared/Modules/FarmMath/**`; testler `tests/config.spec.luau`, `tests/economy.spec.luau`, `tests/golden.spec.luau`.
- Skill: `roblox-add-content`; kural: `economy-data.mdc`. Sayıları kodda sabitleme; Config/FarmMath tek kaynak.
- Komut: `python scripts/smoke-quick.py --all` -> `python scripts/check-config-locales.py` -> `python scripts/audit-economy.py --luau .tools/luau/luau.exe --check` -> `python scripts/simulate-tiers.py --luau .tools/luau/luau.exe --personas ideal,casual,idle --assert-monotonic`.

## 4. Çeviri / oyuncuya görünen metin

- Dosyalar: kaynak Türkçe metin kodda; sözlükler `src/shared/Locales/**` (en/de/ru/es/pt), `src/shared/Localization.luau`.
- Skill: `roblox-localize`; kural: `localization.mdc`.
- Komut: `python scripts/check-locales.py --strict-literals` ve `python scripts/check-config-locales.py`.

## 5. Harita, model, ışık

- Dosyalar: `src/server/World/**`, `src/server/Presentation/**`, `plugin/**`, modeller `assets/**` ve `client-assets/**`; sözleşme `docs/MODEL_SOZLESMESI.md`.
- Skill: `roblox-map-change`; kural: `world-map.mdc`.
- Komut: `python scripts/check-assets.py` -> `python scripts/test-check-assets.py`; plugin/ değiştiyse `rojo build plugin.project.json --plugin IslandFarmTycoonHarita.rbxm` (Studio'yu yeniden aç).
- Elle: Studio'da haritayı kur + doğrula (`MapToolRun=buildverify`), sonra place'i kaydet.

## 6. Kayıt şeması / mali veri

- Dosyalar: `src/shared/GameTypes.luau`, `src/server/Modules/SaveCodec/**`, `SessionLock.luau`, `src/server/Services/PlayerDataService.luau`, `SaveStore.luau`; testler `tests/data.spec.luau`, `tests/player-data-service.spec.luau`, `tests/save-store-transfer.spec.luau`, `tests/financial-rebirth.spec.luau`.
- Skill: `roblox-save-schema`; kural: `economy-data.mdc`. Geri alınamaz dönüşümde ve canlı veride açık onay iste.
- Komut: `python scripts/smoke-quick.py --only data,player-data-service,save-store-transfer,financial-rebirth,transfer-ledger`, sonra `--all`.
- Elle: ayrı test DataStore'unda yeniden giriş/makbuz/kapanış; QA fixture'ı kayıt yazmaz.

## 7. Ekonomi önce/sonra karşılaştırma

```
python scripts/compare-economy.py run --baseline-ref HEAD --repeats 2 --output-dir .test-build/economy-comparison -- --persona hardcore --session 0 --hours 6 --farm 1
python scripts/compare-economy.py compare --before .test-build/before.json --after .test-build/after.json --output-dir .test-build/economy-comparison
```

Aynı persona/ayar şart; çıktı `report.md`/`report.json`. Sim, oyuncu davranışı veya FPS kanıtı değildir.

## 8. Studio QA (izole place)

```
python scripts/studio-qa.py build --output .test-build/studio-qa.rbxlx
python scripts/studio-qa.py command --scenario production --user-id <UserId> --request-id <artan sayı>
python scripts/studio-qa.py inspect --side server      # sonra --side client
```

Senaryolar: `fresh`, `production`, `merchant`, `rebirth-ready`. Komut çıktısı Studio Server Play bağlamında çalıştırılır; `LastResult.status` okunmadan başarı sayma. QA place yayınlanmaz, yönetici reset düğmesi duman testi değildir.

## 9. Silme / yeniden adlandırma / yeni belge-betik sonrası

```
python scripts/check-repo-hygiene.py      # ölü yol, kırık bağlantı, yetim belge/betik/modül, izlenen çöp, 400 satır sınırı
python scripts/check-ai-docs.py           # rehber/kural/skill tutarlılığı
python scripts/check-test-dependencies.py # silinen/taşınan modül harness'te hâlâ anılıyorsa
python tests/tooling.spec.py              # araç/rehber regresyonları
```

Yeni `docs/*.md` `docs/AI_DEVIR_REHBERI.md` dizinine, yeni `scripts/*.py` bir belge/betikte adıyla anılmalı; aksi hijyen hatasıdır. Yeni spec: `scripts/run-tests.py` kaydı + `tests/*.spec.luau`; sonra `check-test-dependencies.py`.

## Kısa kural: neyi kanıtladın?

Her bildirimde: çalıştırılan komut, atlanan/eksik araç, Studio'da görülmeyen davranış. Commit/push/yayın/veri sıfırlama yalnız açık yetkiyle.
