# 0001 Mimari: batch, streaming ve tablo formatı

Durum: Önerildi
Tarih: 23 Kasım 2026

## Bağlam

İstanbul mobilite veri platformunda aylık toplu ulaşım (`toplu_ulasim_2024_01.csv.gz`, `toplu_ulasim_2024_02.csv.gz`) ve trafik (`trafik_2024_01.csv.gz`) kaynak dosyaları DuckDB ve Apache Iceberg (`lake` kataloğu) üzerinde bronze katmanına aktarılmaktadır. Kaynak satırlar değiştirilmeden saklanır ve her satıra `_kaynak_dosya` ile `_yukleme_zamani` izlenebilirlik kolonları eklenir. Gerçek zamanlı streaming gecikme hedefleri, ekip kapasitesi ve bütçe kısıtları henüz tanımlanmamıştır (bilinmiyor).

## Karar

Ham aylık toplu ulaşım ve trafik verilerini değişiklik yapmadan `lake.bronze` altındaki Apache Iceberg tablolarına `month(...)` partition tanımıyla batch olarak yükleyip, gerçek zamanlı streaming bileşenini ihtiyaç netleşene kadar erteleyeceğiz.

## Gerekçe

- Toplu ulaşım için 2 dosya, 34.241.461 satır ve 2 snapshot; trafik için 957.453 satır ve 2 snapshot oluştuğu `make odev-kontrol N=01` ve Iceberg snapshot sorgularıyla sınanabilir.
- DuckDB-Iceberg eklentisi `CREATE OR REPLACE` yerine ayrı `DROP TABLE` ve `CREATE TABLE` ifadelerini gerektirdiğinden tablo kurulumu bu adımlarla tekrarlanabilir biçimde doğrulanabilir.
- `month(transition_date)` ve `month(DATE_TIME)` partition seçimi, aylık gelen dosyalarda partition sayısını sınırlar ve ay bazlı sorgularda taranan veri miktarını azaltır.
- **Elenen seçenek 1 — Bronze katmanında veri temizleme veya tekilleştirme:** Ham veriyi değiştirmek, tekrar gönderilen gün veya bozuk karakter (`Ã`, `Å`, `Ä`) gibi kaynak sorunlarının sonradan incelenmesini engeller.
- **Elenen seçenek 2 — Tüm kaynakları ilk aşamada streaming ile işlemek:** Mevcut kaynaklar aylık toplu CSV.GZ dosyaları olarak geldiği için ilk aşamada streaming karmaşıklığı eklemek ölçülebilir bir gecikme avantajı sağlamaz.

## Sonuçlar

- **İş:** Bronze yükleme SQL betiklerinin (`oturumlar/01/...`) ve `docs/kararlar/0001-mimari.md` kaydının repoda korunması, her yükleme sonrası satır ve snapshot sayılarının denetlenmesi gerekir.
- **Maliyet:** Depolama ve sorgu maliyeti veri hacmine ve snapshot sayısına bağlıdır; kesin altyapı maliyeti bilinmiyor.
- **Risk:** Kaynakta tekrarlanan gün veya kayıtlar bronze katmanında ham kalacağı için sonraki katmanlarda tekilleştirme yapılmazsa metrikler şişebilir.
