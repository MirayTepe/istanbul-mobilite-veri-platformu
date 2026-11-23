-- Oturum 1 | U1.2 Bronze Iceberg tablosu (partition + Ocak/Şubat yükleme + snapshot kontrolleri)
-- make sql ile açılan DuckDB oturumunda çalışır: .read oturumlar/01/u1_2_bronze.sql
DROP TABLE IF EXISTS lake.bronze.toplu_ulasim;

-- 1. Ocak dosyasıyla bronze tablosunu oluştur (1. snapshot)
CREATE TABLE lake.bronze.toplu_ulasim
PARTITIONED BY (month(transition_date)) AS
SELECT * EXCLUDE (filename),
       parse_filename(filename) AS _kaynak_dosya,
       now() AS _yukleme_zamani
FROM read_csv('veri/toplu_ulasim_2024_01.csv.gz',
              filename = true);

-- 2. Şubat dosyasını ekle (2. snapshot)
INSERT INTO lake.bronze.toplu_ulasim
SELECT * EXCLUDE (filename),
       parse_filename(filename) AS _kaynak_dosya,
       now() AS _yukleme_zamani
FROM read_csv('veri/toplu_ulasim_2024_02.csv.gz',
              filename = true);

-- 3. Güncel toplam satır ve kaynak dosya kırılımı
SELECT count(*) AS guncel
FROM lake.bronze.toplu_ulasim;

SELECT _kaynak_dosya,
       count(*) AS satir
FROM lake.bronze.toplu_ulasim
GROUP BY _kaynak_dosya
ORDER BY 1;

-- 4. Snapshot sayısı ve snapshot listesi
SELECT count(*) AS snapshot_sayisi
FROM iceberg_snapshots('lake.bronze.toplu_ulasim');

SELECT snapshot_id,
       operation
FROM iceberg_snapshots('lake.bronze.toplu_ulasim');

SELECT sequence_number,
       snapshot_id,
       operation,
       summary
FROM iceberg_snapshots('lake.bronze.toplu_ulasim')
ORDER BY sequence_number;

-- 5. İlk snapshot (Ocak sonrası) satır sayısı doğrulaması
SET VARIABLE ilk = (
  SELECT snapshot_id
  FROM iceberg_snapshots('lake.bronze.toplu_ulasim')
  WHERE sequence_number = 1
);

SELECT count(*) AS ocak_sonrasi
FROM lake.bronze.toplu_ulasim
AT (VERSION => getvariable('ilk'));