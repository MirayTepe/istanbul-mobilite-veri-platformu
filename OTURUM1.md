# ADR-01: Oturum 1 Ham Veri Alımı ve Bronze Katmanı Depolama Yaklaşımı

## Durum
Taslak / Kabul edildi

## Tarih
2026-11-23

## Bağlam
İstanbul mobilite veri platformu kapsamında toplu ulaşım (`toplu_ulasim_2024_01.csv.gz`, `toplu_ulasim_2024_02.csv.gz`) ve trafik (`trafik_2024_01.csv.gz`, `trafik_2024_02.csv.gz`) CSV.GZ kaynak dosyaları DuckDB ve Apache Iceberg tabanlı bir göl evi (`lake`) yapısına aktarılmaktadır[cite: 1, 4]. Kaynak satırlar değiştirilmeden `_kaynak_dosya` ve `_yukleme_zamani` izlenebilirlik kolonlarıyla bronze katmanına alınmaktadır[cite: 1, 4]. Tüketici gecikme hedefi, tam bütçe ve ekip büyüklüğü repo girdilerinde henüz tanımlanmamıştır (bilinmiyor).

## Karar
Ham CSV.GZ verilerini değişiklik yapmadan `lake.bronze` altında Apache Iceberg tablolarına `month(...)` partition tanımıyla ve `CREATE TABLE ... AS SELECT` / `INSERT INTO` akışıyla yükleyeceğiz[cite: 1, 4].

## Gerekçe
- Ocak ve Şubat toplu ulaşım yüklemeleri toplam 34.241.461 satır ve 2 Iceberg snapshot üreterek zaman yolculuğu ve dosya bazlı sayım doğrulamasına olanak tanımıştır.
- DuckDB-Iceberg eklentisi `CREATE OR REPLACE` yerine ayrı `DROP TABLE` ve `CREATE TABLE` ifadelerini gerektirdiğinden bu akışın `make sql` ve `.read` ile tekrarlanabilir çalıştırılması doğrulanabilir.
- `month(transition_date)` ve `month(DATE_TIME)` partition seçimi, aylık gelen kaynak dosyalar için partition sayısını sınırlar ve aylık filtrelerde okunan veriyi daraltır[cite: 1, 4].
- **Elenen seçenek 1 — Veriyi bronze aşamasında doğrudan temizleme veya filtreleme:** Ham kaynak satırların değiştirilmesi, tekrarlanan gün veya bozuk karakter (`Ã`, `Å`, `Ä`) gibi kaynak anomalilerinin sonradan denetlenmesini zorlaştırır[cite: 1, 2].
- **Elenen seçenek 2 — Günlük (`day` / tarih) partition veya tekilleştirmeden doğrudan silver/mart yükleme:** Aylık dosyalar için gün bazlı partition dosya/metadata sayısını artırabilir; tekilleştirme yapılmadan doğrudan tüketim katmanına çıkmak tekrarlanan kayıtların toplamları şişirme riskini taşır[cite: 1, 2].

## Sonuçlar
- **İş:** Bronze yükleme SQL betiklerinin (`oturumlar/01/...`) ve ADR kaydının repoda tutulması, her yükleme sonrası satır ve snapshot sayılarının kontrol edilmesi gerekir[cite: 1].
- **Maliyet:** Depolama ve işlem maliyeti kaynak dosyaların boyutuna ve snapshot/veri dosyası birikimine bağlıdır; kesin altyapı/bulut maliyeti bilinmiyor[cite: 1].
- **Risk:** Kaynakta tekrar gönderilen günler veya kopya kayıtlar bronze katmanında ham haliyle kalacağı için sonraki dönüşüm katmanlarında tekilleştirme/grain kontrolü yapılmazsa metrikler hatalı hesaplanabilir[cite: 1, 2].

### Varsayımlar
- Kaynak CSV.GZ dosyaları `veri/` dizininde yer almakta ve `read_csv(..., filename = true)` ile okunabilmektedir[cite: 4].
- DuckDB oturumunda `lake` Iceberg kataloğu `.lab/baglan.sql` üzerinden hazır bağlanmaktadır.
- Tüketici gecikme eşiği ve bütçe kısıtları ileriki oturumlarda netleştirilecektir ("bilinmiyor")[cite: 1].