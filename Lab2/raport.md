# 2.14

```sql
SELECT create_distributed_table('measurements', 'me_or_id', colocate_with => 'organizations');
```

# 2.17

Nie. Fragmenty (shardy) są alokowane tylko w zarejestrowanych węzłach roboczych.

# 2.18

Nie. Poszczególne shardy mają nierównomierną ilość wierszy.

Wynika to z tego, że tabela measurements jest podzielona wg identyfikatora organizacji (me_or_id), i wszystkie wiersze są przydzielane do tych samych fragmentów po wartości tego klucza dystrybucji. Jeśli rozkład danych na takim kluczu jest nierównomierny, to nierównomierny będzie również ich podział między fragmenty (a konsekwentnie węzły).

# 3.2

Zapytanie zostało podzielone na 32 zadania. Szacowany koszt jednego wynosi 41.16 (koszt całkowity).

```
 Sort  (cost=20610.82..20860.82 rows=100000 width=258)
   Sort Key: remote_scan.me_time
   ->  Custom Scan (Citus Adaptive)  (cost=0.00..0.00 rows=100000 width=258)
         Task Count: 32
         Tasks Shown: One of 32
         ->  Task
               Node: host=pgsql-citus-sts-1.pgsql-rbd-citus port=5432 dbname=postgres
               ->  Hash Join  (cost=17.75..41.16 rows=86 width=232)
                     Hash Cond: ((measurements.me_lo_id = loggers.lo_id) AND (measurements.me_or_id = loggers.lo_or_id))
                     ->  Seq Scan on measurements_102072 measurements  (cost=0.00..22.95 rows=86 width=22)
                           Filter: ((me_time >= '2017-03-15 08:13:00'::timestamp without time zone) AND (me_time <= '2017-03-15 09:18:00'::timestamp without time zone))
                     ->  Hash  (cost=13.10..13.10 rows=310 width=226)
                           ->  Seq Scan on loggers_102040 loggers  (cost=0.00..13.10 rows=310 width=226)
```

# 3.4

```
 Sort  (cost=20610.82..20860.82 rows=100000 width=258)
   Sort Key: remote_scan.me_time
   ->  Custom Scan (Citus Adaptive)  (cost=0.00..0.00 rows=100000 width=258)
         Task Count: 32
         Tasks Shown: One of 32
         ->  Task
               Node: host=pgsql-citus-sts-1.pgsql-rbd-citus port=5432 dbname=postgres
               ->  Hash Join  (cost=22.91..32.65 rows=86 width=232)
                     Hash Cond: ((measurements.me_lo_id = loggers.lo_id) AND (measurements.me_or_id = loggers.lo_or_id))
                     ->  Bitmap Heap Scan on measurements_102072 measurements  (cost=5.16..14.45 rows=86 width=22)
                           Recheck Cond: ((me_time >= '2017-03-15 08:13:00'::timestamp without time zone) AND (me_time <= '2017-03-15 09:18:00'::timestamp without time zone))
                           ->  Bitmap Index Scan on me_time_idx_102072  (cost=0.00..5.14 rows=86 width=0)
                                 Index Cond: ((me_time >= '2017-03-15 08:13:00'::timestamp without time zone) AND (me_time <= '2017-03-15 09:18:00'::timestamp without time zone))
                     ->  Hash  (cost=13.10..13.10 rows=310 width=226)
                           ->  Seq Scan on loggers_102040 loggers  (cost=0.00..13.10 rows=310 width=226)
```

Indeks został wykorzystany w zapytaniach lokalnych (Bitmap Index Scan zamiast Seq Scan bez indeksu), co zmniejszyło szacowany koszt jednego zapytania z 41.16 do 32.65.

# 3.5

```
 Custom Scan (Citus Adaptive)  (cost=0.00..0.00 rows=0 width=0)
   Task Count: 1
   Tasks Shown: All
   ->  Task
         Node: host=pgsql-citus-sts-1.pgsql-rbd-citus port=5432 dbname=postgres
         ->  Sort  (cost=137.38..137.72 rows=135 width=232)
               Sort Key: measurements.me_time
               ->  Hash Join  (cost=14.98..132.60 rows=135 width=232)
                     Hash Cond: (measurements.me_lo_id = loggers.lo_id)
                     ->  Bitmap Heap Scan on measurements_102082 measurements  (cost=5.45..122.79 rows=105 width=22)
                           Recheck Cond: ((me_time >= '2017-03-15 08:13:00'::timestamp without time zone) AND (me_time <= '2017-03-15 09:18:00'::timestamp without time zone))
                           Filter: (me_or_id = 143)
                           ->  Bitmap Index Scan on me_time_idx_102082  (cost=0.00..5.43 rows=114 width=0)
                                 Index Cond: ((me_time >= '2017-03-15 08:13:00'::timestamp without time zone) AND (me_time <= '2017-03-15 09:18:00'::timestamp without time zone))
                     ->  Hash  (cost=9.50..9.50 rows=2 width=226)
                           ->  Bitmap Heap Scan on loggers_102050 loggers  (cost=4.16..9.50 rows=2 width=226)
                                 Recheck Cond: (lo_or_id = 143)
                                 ->  Bitmap Index Scan on loggers_pkey_102050  (cost=0.00..4.16 rows=2 width=0)
                                       Index Cond: (lo_or_id = 143)
```

Dodany warunek sprawił że zamiast wszystkie 32 fragmenty, zapytanie mogło odpytać tylko jeden fragment na jednym węźle, co drastycznie zmniejszyło koszt jego wykonania, przykładowo poprzez brak konieczności sortowania i scalania danych w bazie koordynacyjnej - zamiast tego wszystko można było wykonać na węźle roboczym.

# 4.4

Zawartość fragmentu (został stworzony jeden zreplikowany do obu węzłów roboczych) jest identyczna z zawartością całej tabeli `logger_types`.

# 4.6

Zmiany zostały przeniesione do obu węzłów roboczych.

# 4.7

```
 Custom Scan (Citus Adaptive)  (cost=0.00..0.00 rows=0 width=0)
   Task Count: 1
   Tasks Shown: All
   ->  Task
         Node: host=pgsql-citus-sts-1.pgsql-rbd-citus port=5432 dbname=postgres
         ->  Sort  (cost=153.85..154.19 rows=135 width=290)
               Sort Key: measurements.me_time
               ->  Hash Join  (cost=31.33..149.07 rows=135 width=290)
                     Hash Cond: (measurements.me_lo_id = loggers.lo_id)
                     ->  Bitmap Heap Scan on measurements_102082 measurements  (cost=5.45..122.79 rows=105 width=22)
                           Recheck Cond: ((me_time >= '2017-03-15 08:13:00'::timestamp without time zone) AND (me_time <= '2017-03-15 09:18:00'::timestamp without time zone))
                           Filter: (me_or_id = 143)
                           ->  Bitmap Index Scan on me_time_idx_102082  (cost=0.00..5.43 rows=114 width=0)
                                 Index Cond: ((me_time >= '2017-03-15 08:13:00'::timestamp without time zone) AND (me_time <= '2017-03-15 09:18:00'::timestamp without time zone))
                     ->  Hash  (cost=25.86..25.86 rows=2 width=284)
                           ->  Nested Loop  (cost=4.31..25.86 rows=2 width=284)
                                 ->  Bitmap Heap Scan on loggers_102050 loggers  (cost=4.16..9.50 rows=2 width=230)
                                       Recheck Cond: (lo_or_id = 143)
                                       ->  Bitmap Index Scan on loggers_pkey_102050  (cost=0.00..4.16 rows=2 width=0)
                                             Index Cond: (lo_or_id = 143)
                                 ->  Index Scan using logger_types_pkey_102104 on logger_types_102104 logger_types  (cost=0.15..8.17 rows=1 width=62)
                                       Index Cond: (lt_id = loggers.lo_lt_id)
```

Tylko jedna. Skoro każdy węzeł roboczy posiada identyczną kopię danych, zapytanie można wysłać do dowolnej jednej z nich.

# 5.8

Żadnych różnic nie stwierdzono niezależnie od tego do jakiego poda skierował LoadBalancer. Ponieważ metadane są replikowane na wszystkich węzłach roboczych, worker potrafi przekierować operacje DML na inny węzeł jeśli modyfikowany wiersz leży w shardzie na innym węźle.

# 6.3

Nie zostały utworzone żadne. Domyślnie przy dodaniu węzła roboczego Citus przenosi jedynie metadane klastra, ale żadne fragmenty nie są tworzone ani przenoszone z innych węzłów.

# 6.8

Rozproszenie shardów jest równomierne. Wynika to z użycia opcji kolokacji z tabelą organization (`colocate with => 'organizations'`). Rebalancer przenosi te same grupy shardów dla wszystkich tabel jednocześnie. O ile liczba shardów jest równomierna, to ilość wierszy w shardach już być taka nie musi, co wynika z 2.18.
