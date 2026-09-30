# Ses listesi (üretim ve bağlama rehberi)

Oyun ses yuvalarını `src/shared/Config.luau` içinde hazır tutar; `id` boşsa o ses çalınmaz.
Yüklenen her ses için `rbxassetid://NUMARA` kimliğini aşağıdaki yuvaya yaz.

Genel kurallar: mono ya da stereo `.wav`/`.mp3`, en fazla 7 dakika (Roblox sınırı); kısa efektler 0,2-1,5 sn,
döngüler 20-40 sn ve başı-sonu dikişsiz. Sessizlikle başlayıp bitmesin (kırpılmış olsun). Ortam döngülerini
ayrı ayrı yükle, oyun katmanları karıştırır.

## Arayüz ve geri bildirim (`Config.SOUNDS`)
| Yuva | Ne zaman | İstek (prompt) örneği | Süre |
|---|---|---|---|
| click | her tuş | "soft wooden UI click, cozy farm game, dry" | 0,1-0,2 sn |
| coin | para toplama | "bright coin pickup chime, cartoon, sparkly, short" | 0,4-0,7 sn |
| success | satın alma/ödül | "cheerful two-note success chime, warm, cartoon" | 0,6-1 sn |
| error | yetersiz para/hata | "soft low error blip, gentle, not harsh" | 0,3-0,5 sn |
| build | yeni yapı | "construction pop with wood and sparkles, triumphant short jingle" | 1-1,5 sn |

## Ortam döngüleri (`Config.AMBIENCE`, döngü)
| Yuva | İstek örneği |
|---|---|
| birds | "peaceful spring meadow ambience, gentle birdsong, soft breeze, seamless loop" |
| wind | "cold autumn wind over open field, soft, slow gusts, seamless loop" |
| rain | "steady light rain on grass and wood roofs, calm, seamless loop" |
| storm | "heavy rain with distant rolling thunder, wind, seamless loop" |
| night | "summer night crickets and soft frogs, quiet countryside, seamless loop" |

## Hayvanlar (`Config.ANIMAL_SOUNDS`, 0,6-1,5 sn, yumuşak ve sevimli)
cow (yumuşak böğürme), chicken (kısa gıdaklama), horse (kısa kişneme), goat (melemek), duck (vak vak),
sheep (mee), pig (hafif homurtu). İstek kalıbı: "friendly cartoon {hayvan} sound, gentle, short, no background".

## Su altı (henüz bağlı değil; istersen `Config.SOUNDS`'a eklenir)
| Önerilen yuva | İstek örneği |
|---|---|
| splash | "small water splash, soft, cartoon, short" |
| bubbles | "underwater bubbles rising, calm, short loop" |
| underwaterAmbience | "muffled deep underwater ambience, soft hum, seamless loop" |

## Müzik (isteğe bağlı, henüz yuva yok)
"relaxing acoustic farm tycoon background music, light guitar and strings, warm, loopable, 90 BPM" (1-2 dk döngü).
