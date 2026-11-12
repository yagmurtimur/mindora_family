# Tek Çocuk–Tek Ebeveyn Migration Hazırlığı

Durum: hazırlık ve emulator doğrulaması. Bu belge bir canlı migration yetkisi
vermez. Araç, yalnızca `FIRESTORE_EMULATOR_HOST` localhost adresine ayarlıysa
çalışır; üretim Firebase projesine bağlanmayı reddeder ve hiçbir yazma modu
barındırmaz.

## Şema ve doğrulanan kaynaklar

Migration denetimi şu kayıtları karşılaştırır:

- `relationships/{relationshipId}`: `status == "accepted"`, `parentId`,
  `childId` kanonik ilişki kaydıdır.
- `children/{childId}/guardians/{parentUid}`: accepted ilişki için çocuk
  tarafındaki erişim aynasıdır.
- `parents/{parentUid}/children/{childId}`: ebeveyn listeleme aynasıdır.
- `children/{childId}/guardianState/active`: tek aktif ebeveyn kilididir;
  `parentUid`, `childId`, `relationshipId` alanları tek accepted adayla birebir
  eşleşmelidir.

`relationships` içindeki her accepted kayıt taranır. Araç şunları raporlar:

- toplam çocuk ve accepted ilişki sayısı;
- tam olarak bir accepted ilişkisi olan aktif ilişki adayları;
- birden fazla accepted ilişkisi olan çocuklar (otomatik seçim yapılmaz);
- eksik veya ilişkisiyle eşleşmeyen guardian ve parent mirror belgeleri;
- eksik, hatalı veya çoklu adayla çelişen active lock belgeleri;
- child belgesi olmayan ilişki/mirror/lock referansları.

## Salt-okuma kullanım

Yalnızca emulator için:

```sh
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
GCLOUD_PROJECT=mindora-migration-audit \
node functions/migrations/audit-single-parent.js --dry-run
```

Rapor standart çıktıya JSON olarak yazılır; dosya veya Firestore yazısı
oluşturmaz. `--apply` dahil tanınmayan tüm parametreler reddedilir.

## İdempotency ve gelecekteki yazma kapısı

Hazırlanan araç yazmaz; dolayısıyla tekrar çalıştırmak veri üretemez. Gelecekte
yazma için ayrı yetkili bir değişiklikte aşağıdaki kapılar zorunlu olmalıdır:

1. Sadece onaylı, sürümlenmiş dry-run raporunun SHA-256 plan özeti verilir.
2. `--apply`, `--confirm-plan-sha256=<özet>` ve ortam için ayrı açık onay
   birlikte zorunlu tutulur.
3. Her çocuk transaction içinde yeniden okunur. Yalnızca tek accepted ilişki,
   doğru guardian/mirror ve boş veya aynı active lock varsa yazılır.
4. Hedef yol sabittir: `guardianState/active`. Aynı doğru kilit varsa no-op;
   farklı kilit, eksik mirror/guardian veya çoklu accepted ilişki varsa işlem
   durur ve manuel incelemeye gider.
5. Her uygulanan çocuk için append-only migration audit kaydı tutulur. Çakışma
   veya önkoşul hatasında geri kalan çocuklara geçmeden operasyon durdurulur.

Bu kurallar, aynı planın tekrarında yeni belge çoğaltılmamasını sağlar.

## Canlıya geçiş sırası

1. Firestore export/backup ve bekleyen davet/ilişki sayımlarını alın.
2. Uygulama tarafında davet oluşturma, kabul ve iptal akışlarını bakım moduna
   alın; migration boyunca eski ve yeni ilişki akışları birlikte çalışmamalıdır.
3. Production için salt-okuma denetimini ayrı, onaylı erişim sürecinde çalıştırın
   ve raporu saklayın. Bu repodaki araç production erişimini bilerek reddeder.
4. Çoklu accepted ilişki, bozuk guardian/mirror ve lock çakışmalarını manuel
   olarak çözün. Bir çocuk için ebeveyn seçimini araç yapmaz.
5. Onaylı çocuklarda tek aktif kilidi transaction ile backfill edin; eski veya
   seçilmeyen accepted ilişkileri açık bir iş kararı ve denetim iziyle kapatın.
6. Backfill sonrası her aday için guardian, parent mirror ve active lock eşleşme
   raporunu yeniden çalıştırın. Tüm eksik ve çelişki sayıları sıfır olmalıdır.
7. Yeni Functions kodunu, sonra Firestore Rules'u kademeli olarak yayınlayın.
   Yayın sonrası tekrar salt-okuma doğrulaması yapın.

## Öncesi/sonrası doğrulama

Öncesi: accepted ilişki sayısı, guardian sayısı, parent mirror sayısı, active
lock sayısı ve bekleyen davet sayısı export/raporla kaydedilir. Çoklu accepted
ilişki veya alan eşleşmezliği bulunan çocuklar yazma planından dışarıda kalır.

Sonrası: her accepted aktif çocuk için bir guardian, bir parent mirror ve bir
active lock bulunmalı; bu üç belgede `parentUid`, `childId`, `relationshipId`
eşleşmelidir. Revoked ilişkilerin guardian/mirror belgeleri bulunmamalıdır.
Fonksiyon ve Rules emulator testleri ayrıca tekrar çalıştırılmalıdır.

## Rollback

Kilit ekleme işlemi hedef belge yolunda idempotent olduğu için rollback, yalnızca
uygulanan migration audit kaydındaki çocuklar üzerinde transaction ile active
lock silme işlemidir. Bu işlem, mevcut lock'ın migration'ın yazdığı aynı
`relationshipId` değerini hâlâ taşıdığını doğrulamalıdır; kullanıcı tarafından
sonradan oluşturulmuş yeni bir kilit asla silinmemelidir. Export/backup, geniş
çaplı bir hata halinde esas geri dönüş kaynağıdır.

Rules yayınlandıktan sonra yalnızca lock silmek eski guardian erişimini geri
getirmez; önce guardian/mirror/lock tutarlılığı yeniden kurulmalı, sonra kural
geri alma kararı kontrollü verilmelidir.
