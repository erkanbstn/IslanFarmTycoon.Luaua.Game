# Server/World

Statik harita (Studio eklentisiyle bir kez kurulup place'e kaydedilir). Oyun servislerine bağlanmaz; yalnızca Shared ve bu klasör.
Harita düzeni değişince `MapBuilder.luau` içindeki `MAP_VERSION` artırılır (düzen: `MapLayout`, yapı taşları: `MapParts`, adalar: `IslandBuilder`/`SatelliteBuilder`, meydan: `HubBuilder`). Kurallar: docs/MIMARI.md.
