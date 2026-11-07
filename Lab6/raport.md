# Utworzenie baz danych

## 9.

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ora-rbd2
spec:
  serviceName: ora-rbd2-service
  selector:
    matchLabels:
      app: ora-rbd2
  replicas: 1
  template:
    metadata:
      labels:
        app: ora-rbd2
    spec:
      containers:
        - name: ora-rbd2
          image: container-registry.oracle.com/database/express:latest
          volumeMounts:
            - name: ora-rbd2-disk
              mountPath: /opt/oracle/oradata
          env:
            - name: ORACLE_PWD
              value: rbd2
  volumeClaimTemplates:
    - metadata:
        name: ora-rbd2-disk
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: ora-rbd2-lb
spec:
  type: LoadBalancer
  ports:
    - port: 1522
      targetPort: 1521
  selector:
    app: ora-rbd2
```

# Transparentny dostęp do zdalnych danych

## 7.

```sql
CREATE DATABASE LINK RBD@RBD1 CONNECT to rbd IDENTIFIED BY "RBD#7102" USING 'rbd1';

SELECT * FROM pracownicy@RBD@RBD1;

CREATE SYNONYM pracownicy FOR pracownicy@RBD@RBD1;

SELECT nazwisko, nazwa FROM pracownicy natural join zespoly;
```

# Rozproszona transakcja zakończona sukcesem

Przed update:

```
SQL> select * from zespoly where id_zesp=10;

   ID_ZESP NAZWA                ADRES
---------- -------------------- --------------------
        10 ADMINISTRACJA        PIOTROWO 3A

SQL> select * from pracownicy where id_prac=100;

   ID_PRAC NAZWISKO        ETAT         ID_SZEFA ZATRUDNIO  PLACA_POD  PLACA_DOD    ID_ZESP
---------- --------------- ---------- ---------- --------- ---------- ---------- ----------
       100 WEGLARZ         DYREKTOR              01-JAN-68       1730      420.5         10
```

Po update:

```
SQL> select * from zespoly where id_zesp=10;

   ID_ZESP NAZWA                ADRES
---------- -------------------- --------------------
        10 ADMINISTRACJA        PIOTROWO 1

SQL> select * from pracownicy where id_prac=100;

   ID_PRAC NAZWISKO        ETAT         ID_SZEFA ZATRUDNIO  PLACA_POD  PLACA_DOD    ID_ZESP
---------- --------------- ---------- ---------- --------- ---------- ---------- ----------
       100 WEGLARZ         DYREKTOR              01-JAN-68        999      420.5         10
```

Zmiany zostały wprowadzone.

# Rozproszona transakcja zakończona awarią

Tabele w bazie danych RBD2 nie posiadają zmian wprowadzonych przez nieudaną transakcję z komentarzem `ORA-2PC-CRASH-TEST-4` (crash after prepare (non-commit point site)). Posiadają jednak zmiany wprowadzone przez nieudaną transakcję z komentarzem `ORA-2PC-CRASH-TEST-6` (crash commit point site after commit).

Wynika to z tego że węzeł commit point site jako jedyny nie przechodzi przez stan "prepared" transakcji, a jego decyzja o zatwierdzeniu jest decyzją całej transakcji.

W scenariuszu pierwszym awaria występuje na węźle non-commit point po tym jak ten wszedł w stan prepared, ale zanim commit point site zatwierdził transakcję - więc transakcja nie jest globalnie zatwierdzona, zmiany są wstrzymane i zablokowane (w stanie in-doubt). Gdy po zakończeniu awarii węzeł non-commit point odpyta się commit-point o transakcję, dowie się że nie została zatwierdzona i wycofa wszelkie zmiany.

W scenariuszu drugim commit point site zatwierdził transakcję, a awaria nastąpiła potem. Decyzja jest podjęta i nieodwracalna - transakcja jest zatwierdzona globalnie. Węzeł non-commit point w stanie in-doubt odpytuje commit-point po awarii i dowiaduje się że transakcja została zatwierdzona, więc zatwierdza zmiany u siebie.

# Ręczne odtwarzanie

## 6.

Będzie to baza RBD2. Wynika to z tego że Oracle wybiera commit point site na podstawie parametru `COMMIT_POINT_STRENGTH`, który to jest wyższy na bazie RBD2 (20 > 10).

## 10.

```
SQL> select * from zespoly where id_zesp=10;

   ID_ZESP NAZWA                ADRES
---------- -------------------- --------------------
        10 ADMINISTRACJA        PIOTROWO 3
```

Nie doszło do zmiany.

## 11.

```
SQL> update pracownicy set placa_pod=666 where id_prac=100;
update pracownicy set placa_pod=666 where id_prac=100
*
ERROR at line 1:
ORA-01591: lock held by in-doubt distributed transaction 10.25.621
```

Poprzednia transakcja zakończyła się awarią po fazie prepare na wężle nie-commit czyli RBD1, który przeszedł w stan prepared ale nastąpiła awaria zanim RBD2 zatwierdził transakcje, więc ta nie została wykonana. Jako że wyłączyliśmy automatyczne odtwarzania, transakcja pozostała w zawieszeniu i nie została rozwiązana sama.

Po próbie modyfikacji pracownika wystąpił błąd "lock held by in-doubt distributed transaction". Powodem jest to, że RDB1 jest nadal w stanie prepared i czeka na rozstrzygnięcie transakcji, a dopóki to się nie stanie trzyma blokadę na zmodyfikowanych wierszach. Próba modyfikacji tych samych wierszy zakończyła się błędem (żeby nie czekać w nieskończoność na zablokowanym wierszu).

## 15.

```
SQL> select LOCAL_TRAN_ID, GLOBAL_TRAN_ID, STATE from DBA_2PC_PENDING;

LOCAL_TRAN_ID
----------------------
GLOBAL_TRAN_ID
--------------------------------------------------------------------------------
STATE
----------------
7.23.596
XEPDB1.b3fd2914.7.23.596
prepared

LOCAL_TRAN_ID
----------------------
GLOBAL_TRAN_ID
--------------------------------------------------------------------------------
STATE
----------------


SQL> select LOCAL_TRAN_ID, INTERFACE, DATABASE from DBA_2PC_NEIGHBORS;

LOCAL_TRAN_ID          I
---------------------- -
DATABASE
--------------------------------------------------------------------------------

7.23.596               N

7.23.596               C
RBD@RBD2
```

Kolumna INTERFACE określa czy wpis opisuje pochodzenie przychodzące czy wychodzące względem tego węzła.
- N - wpis dotyczy połączenia przychodzącego (węzła od którego nadeszło żądanie), nie wychodzącego. Pole `DATABASE` jest puste bo sesja jest lokalna.
- C - wpis dotyczy połączenia wychodzącego (database link do węzła do którego ten węzeł wysłał żądanie). Pole `DATABASE` zawiera `RBD@RBD2` czyli link do RBD2.

## 17.

O wyniku transakcji decyduje commit point site (RBD2). Ponieważ awaria wystąpiła na węźle non-commit, wedle wiedzy RBD2 transakcja nie została zatwierdzona globalnie i nie doszło do zmiany danych. Próba zatwierdzenia transakcji na non-commit site skutkowałaby niespójnym stanem bazy danych. Jedynym wyjściem z tej sytuacji jest ręczne podjęcie decyzji wycofania na RBD1. Dopóki tego nie zrobimy, RBD1 nadal będzie trzymał blokady na wierszach i blokował innych.

## 20.

Operacja wykonała się bez błędu. Ponieważ transakcja została ręcznie wycofana, blokady trzymane przez RDB1 na wierszu zostały zwolnione, co pozwala na wykonanie zmian.

## 21.

Nie, ponieważ RBD2 jest commit point site i nie przechodzi przez stan prepared. Z zapytania z polecenia 19 wynika, że nie ma na niej żadnej transakcji in doubt, nie są trzymane żadne blokady, więc nie ma czego wycofywać.

## 22.

RBD1:
```
SQL> update zespoly set adres='PIOTROWO 5' where id_zesp=10;

1 row updated.

SQL> update pracownicy set placa_pod=555 where id_prac=100;

1 row updated.

SQL> commit comment 'ORA-2PC-CRASH-TEST-6';
commit comment 'ORA-2PC-CRASH-TEST-6'
*
ERROR at line 1:
ORA-02054: transaction 10.3.620 in-doubt
ORA-02053: transaction 1.1.629 committed, some remote DBs may be in-doubt
ORA-02059: ORA-2PC-CRASH-TEST-6 in commit comment
ORA-02063: preceding 2 lines from RBD@RBD2


SQL> select * from zespoly where id_zesp=10;

   ID_ZESP NAZWA                ADRES
---------- -------------------- --------------------
        10 ADMINISTRACJA        PIOTROWO 5
```

RBD2:
```
SQL> select * from zespoly where id_zesp=10;

   ID_ZESP NAZWA                ADRES
---------- -------------------- --------------------
        10 ADMINISTRACJA        PIOTROWO 5
```

Zmiany zostały zatwierdzone, bo do błędu doszło na commit point site. Transakcja została zatwierdzona, więc zmiany zostały wprowadzone zarówno w RBD1 jak i w RBD2. Jednakże w przypadku RBD1 wynika to z tego że są to lokalne zmiany, a transakcja nadal jest w stanie in-doubt.

RBD1:
```
SQL> select LOCAL_TRAN_ID, GLOBAL_TRAN_ID, STATE from DBA_2PC_PENDING;

LOCAL_TRAN_ID
----------------------
GLOBAL_TRAN_ID
--------------------------------------------------------------------------------
STATE
----------------

10.3.620
XEPDB1.b3fd2914.10.3.620
prepared


SQL> select LOCAL_TRAN_ID, INTERFACE, DATABASE from DBA_2PC_NEIGHBORS;

LOCAL_TRAN_ID          I
---------------------- -
DATABASE
--------------------------------------------------------------------------------

10.3.620               N


10.3.620               C
RBD@RBD2

6 rows selected.
```

(wyciąłem pozostałe transakcje)

RBD2:
```
SQL> select LOCAL_TRAN_ID, GLOBAL_TRAN_ID, STATE from DBA_2PC_PENDING;

LOCAL_TRAN_ID
----------------------
GLOBAL_TRAN_ID
--------------------------------------------------------------------------------
STATE
----------------
1.1.629
XEPDB1.b3fd2914.10.3.620
committed


SQL> select LOCAL_TRAN_ID, INTERFACE, DATABASE from DBA_2PC_NEIGHBORS;

LOCAL_TRAN_ID          I
---------------------- -
DATABASE
--------------------------------------------------------------------------------
1.1.629                C
XEPDB1
```

Na RBD2 transakcje się zatwierdziły lokalnie, jako że nie wchodzi w stan prepared (jako commit point) a awaria nastąpiła po globalnym zatwierdzeniu. Na RBD1 transakcja nadal jest trzymana, ale jako że jej rezultaty i tak są zatwierdzone to należy wyłącznie wywołać:

```sql
commit force '10.3.620';
```

`ROLLBACK_FORCE` byłoby błędem - RBD2 już zatwierdził zmiany, więc wycofanie w RBD1 spowodowałoby niespójność danych na obu węzłach.
