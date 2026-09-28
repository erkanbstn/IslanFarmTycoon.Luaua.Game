# Birden fazla ana çiftlik

Bir **ana çiftlik**, büyük ana ada ve ona bağlı üç küçük uzman adanın tamamıdır.
Ada Yönetimi'nin üst bölümü ana çiftlikleri satın alma/seçme içindir; alt bölümü seçilen
çiftliğin küçük adalarını açar. Bu iki ilerleme seviyesi ayrıdır.

İlk çiftlik mevcut kayıttır. Sonraki beş çiftliğin fiyatları sırasıyla 5.000, 12.000,
25.000, 50.000 ve 100.000'dir (`Config.MAIN_FARM_PRICES`). Satın almak için haritada
sahipsiz bir ana ada bulunmalıdır. Başka oyuncuya ait alan satın alınamaz.

Para oyuncuya aittir ve ortaktır. Her çiftliğin hayvanları, küçük ada kilitleri,
yükseltmeleri, ahır seviyesi, deposu, üretim partileri ve siparişleri ayrıdır.
Yeni çiftlik başlangıç durumuyla açılır; mevcut çiftlikteki geliştirmeler kopyalanmaz.
Tüm sahip olunan çiftlikler kendi kazanç ve depo sınırlarıyla çalışır; otomatik toplama
olanların geliri ortak kasaya gider. Menü ve yatırımlar etkin çiftliği kullanır.

Kalıcı mantıksal çiftlik kimliği fiziksel harita alanından ayrıdır. Sunucuda altı fiziksel
takımada vardır; her çevrimiçi oyuncunun etkin çiftliği için en az bir alan ayrılır.
Yeni oyuncu girerken gerekli olursa başka oyuncunun etkin olmayan ek çiftliği görsel olarak
kaldırılır. Hayvanları ve ilerlemesi silinmez, gelir üretimi sürer. Yönetimden seçildiğinde
boş alana, boş alan yoksa kendi mevcut alanına yüklenir. Harita alanı boşalınca bekleyen
çiftlikler yeniden yerleştirilebilir.

Kayıt şeması 4'tür. Eski tek çiftlik kayıtları ilk çiftlik olarak taşınır. Kayıt tek
oturum kilidiyle, ortak cüzdan ve bütün çiftlikler birlikte yazılarak saklanır.
Gecikmiş satın alma/üretim istekleri başka çiftliğe uygulanmaması için hedef çiftlik
kimliğiyle doğrulanır.

Studio kontrolü: ikinci ana adayı satın al; ona hayvan/yükseltme al; ilkine dön ve iki
ilerlemenin ayrı kaldığını kontrol et. Çıkıp gir; ortak para ve iki çiftlik korunmalı.
İki oyuncu ile dolu haritada alanın geçici kaldırılması/seçilmesi ve başkasının alanını
satın alamama ayrıca denenmeli. Yağmur yuvarlak damla kullanır; önceki kar efekti korunur.
