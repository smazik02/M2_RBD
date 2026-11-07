# 2.14

Tak, wszystkie wiersze wstawione do bazy `provider-1` zostały zreplikowane w bazie `subscriber-1`

# 2.15

```sql
ALTER PUBLICATION meas_publication ADD TABLE loggers;
```

# 2.17

Nie, żadne wiersze wstawione do `provider-1` się nie zreplikowały.

# 2.18

```
postgres=# select subname as substription_name, relname as table_name,
case srsubstate
when 'i' then 'initialize'
when 'd' then 'data is being copied'
when 's' then 'synchronized'
when 'r' then 'ready (normal replication)'
end
from pg_subscription_rel r join pg_subscription s on
r.srsubid=s.oid
join pg_class c on r.srrelid=c.oid;
 substription_name |  table_name   |            case
-------------------+---------------+----------------------------
 meas_subscription | organizations | ready (normal replication)
```
Nie, nie znajdują się.

# 2.21

`provider-1`
```
postgres=# insert into organizations (or_id, or_name, or_type) values (336, 'Organization336', 'OPERATOR');
INSERT 0 1
postgres=# select * from organizations where or_id = 336;
 or_id |     or_name     | or_type
-------+-----------------+----------
   336 | Organization336 | OPERATOR
```
`subscriber-1`
```
postgres=# select * from organizations where or_id = 336;
 or_id |     or_name     | or_type
-------+-----------------+----------
   336 | Organization336 | OPERATOR
```

`provider-1`
```
postgres=# update organizations set or_type = 'CLIENT' where or_id = 336;
UPDATE 1
postgres=# select * from organizations where or_id = 336;
 or_id |     or_name     | or_type
-------+-----------------+---------
   336 | Organization336 | CLIENT
(1 row)
```
`subscriber-1`
```
postgres=# select * from organizations where or_id = 336;
 or_id |     or_name     | or_type
-------+-----------------+---------
   336 | Organization336 | CLIENT
```

`provider-1`
```
postgres=# delete from organizations where or_id = 336;
DELETE 1
postgres=# select * from organizations where or_id = 336;
 or_id | or_name | or_type
-------+---------+---------
(0 rows)
```
`subscriber-1`
```
postgres=# select * from organizations where or_id = 336;
 or_id | or_name | or_type
-------+---------+---------
(0 rows)
```

# 2.22

`provider-1`
```
postgres=# insert into organizations (or_id, or_name, or_type) values (336, 'Organization336', 'OPERATOR');
INSERT 0 1
postgres=# select * from organizations where or_id = 336;
 or_id |     or_name     | or_type
-------+-----------------+----------
   336 | Organization336 | OPERATOR
```

```sh
$ kubectl scale sts pgsql-rbd2 --replicas 0
statefulset.apps/pgsql-rbd2 scaled
$ kubectl get sts
NAME         READY   AGE
pgsql-rbd1   1/1     36m
pgsql-rbd2   0/0     36m
```

`provider-1`
```
postgres=# update organizations set or_type = 'CLIENT' where or_id = 336;
UPDATE 1
postgres=# select * from organizations where or_id = 336;
 or_id |     or_name     | or_type
-------+-----------------+---------
   336 | Organization336 | CLIENT
```

```sh
$ kubectl scale sts pgsql-rbd2 --replicas 1
statefulset.apps/pgsql-rbd2 scaled
$ kubectl get sts
NAME         READY   AGE
pgsql-rbd1   1/1     37m
pgsql-rbd2   1/1     37m
```

`subscriber-1`
```
postgres=# select * from organizations where or_id = 336;
FATAL:  terminating connection due to administrator command
server closed the connection unexpectedly
        This probably means the server terminated abnormally
        before or while processing the request.
The connection to the server was lost. Attempting reset: Succeeded.
psql (18.6, server 18.0 (Debian 18.0-1.pgdg13+3))
postgres=# select * from organizations where or_id = 336;
 or_id |     or_name     | or_type
-------+-----------------+---------
   336 | Organization336 | CLIENT
```

Tak, dane zostały zreplikowane po restarcie subskrybenta.

# 2.23

Parametr `wal_keep_size` wpływa na minimalny rozmiar archiwalnych segmentów WAL przetrzymywanych na wypadek potrzeby nadrobienia naległości przez subkrybenta (w wyniku np. restartu albo awarii). Zbyt mała wartość parametru spowoduje, że jeśli w czasie niedostępności `subscriber-1` wygenerowano za dużo danych, to baza `provider-1` usunie stare pliki WAL. Wówczas po starcie bazy `subscriber-1` nie będzie ona w stanie pobrać brakujących transakcji.

# 3.7

Zmiany się przepropagowały. Baza `subscriber-1` nasłuchuje na obydwu providerów.

# 3.9

`subscriber-1`
```
postgres=# select * from organizations where or_id = 50;
 or_id |    or_name     | or_type
-------+----------------+---------
    50 | Organization50 | CLIENT
(1 row)
```

`provider-2`
```
postgres=# insert into organizations values(50, 'Konflitowa', 'CLIENT');
INSERT 0 1
postgres=# select pg_current_wal_lsn ();
 pg_current_wal_lsn
--------------------
 0/1822D30
(1 row)

postgres=# insert into organizations values(-50, 'Nie Konflitowa', 'CLIENT');
INSERT 0 1
postgres=# select * from organizations where or_id = 50;
 or_id |  or_name   | or_type
-------+------------+---------
    50 | Konflitowa | CLIENT
(1 row)
```

`subscriber-1`
```
postgres=# select * from organizations where or_id = 50;
 or_id |    or_name     | or_type
-------+----------------+---------
    50 | Organization50 | CLIENT
(1 row)

postgres=# select * from organizations where or_id = -50;
 or_id | or_name | or_type
-------+---------+---------
(0 rows)
```

Obie operacje się nie przepropagowały.

# 3.14

Przed wykonaniem `pg_replication_origin_advance`
```
2026-10-17 20:43:55.590 UTC [133] LOG:  logical replication apply worker for subscription "meas2_subscription" has started
2026-10-17 20:43:55.600 UTC [133] ERROR:  conflict detected on relation "public.organizations": conflict=insert_exists
2026-10-17 20:43:55.600 UTC [133] DETAIL:  Key already exists in unique index "organizations_pkey", modified in transaction 779.
        Key (or_id)=(50); existing local row (50, Organization50, CLIENT); remote row (50, Konflitowa, CLIENT).
2026-10-17 20:43:55.600 UTC [133] CONTEXT:  processing remote data for replication origin "pg_16427" during message type "INSERT" for replication target relation "public.organizations" in transaction 778, finished at 0/1822D00
2026-10-17 20:43:55.602 UTC [1] LOG:  background worker "logical replication apply worker" (PID 133) exited with exit code 1
```

Po wykonaniu
```
2026-10-17 20:44:00.595 UTC [134] LOG:  logical replication apply worker for subscription "meas2_subscription" has started
2026-10-17 20:44:15.754 UTC [30] LOG:  checkpoint starting: time
2026-10-17 20:44:16.083 UTC [30] LOG:  checkpoint complete: wrote 3 buffers (0.0%), wrote 1 SLRU buffers; 0 WAL file(s) added, 0 removed, 0 recycled; write=0.304 s, sync=0.007 s, total=0.330 s; sync files=3, longest=0.003 s, average=0.003 s; distance=27 kB, estimate=27 kB; lsn=0/1893160, redo lsn=0/1893108
```

Replikacja się wznowiła

# 3.15

```
postgres=# select * from organizations where or_id = 50;
 or_id |    or_name     | or_type
-------+----------------+---------
    50 | Organization50 | CLIENT
(1 row)

postgres=# select * from organizations where or_id = -50;
 or_id |    or_name     | or_type
-------+----------------+---------
   -50 | Nie Konflitowa | CLIENT
(1 row)
```

Polecenie zastosowało wszystkie zmiany transakcji które są niekonfliktowe. Zmiana dla wiersza 50 nie została wprowadzona, ponieważ wywołała konflikt klucza głównego, który zablokował proces roboczy replikacji. Użycie funkcji 1pg_replication_origin_advance1 przesunęło wskaźnik pozycji LSN subskrybenta za transakcję powodującą błąd, w efekcie czego konfliktowa zmiana (or_id = 50) została całkowicie pominięta. Po odblokowaniu procesu replikacji pobrał on i zaaplikował kolejną transakcję z pliku WAL (or_id = -50), która nie powodowała konfliktu i pomyślnie zapisała się w bazie subskrybenta.
