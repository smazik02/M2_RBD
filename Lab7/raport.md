# 2.6

W celu zakończenia obu transakcji i zwolnienia blokad na wierszach, należy w obu sesjach wycofać (`ROLLBACK`) lub zatwierdzić (`COMMIT`) zmiany.

# 3.1.6

Jest to rozwiązanie mało wydajne, ponieważ pełne odświeżenie zmiaterializowanych perspektyw powoduje przesłanie zawartości całej tabeli między bazami danych i musi być wywołane ręcznie. Lepsze podejście przesyła między bazami danych jedynie same zmiany jakie wystąpiły od ostatniego odświeżenia.

# 3.2.3

Tuż po utworzeniu dziennika należy wykonać pełne odświeżenie, ponieważ dziennik rejestruje tylko nowe zmiany i potrzebuje pewien punkt startowy między tabelą źródłową a materializowaną perspektywą. Tylko od tego punktu startowego można zacząć aplikować zmiany zapisane w dzienniku.

# 3.2.6

Odświeżenie przyrostowe jest znacznie szybsze ponieważ zamiast zawartości całej tabeli, przesyłamy prez sieć tylko operacje modyfikacji (INSERT, UPDATE, DELETE) od ostatniego odświeżenia. Powoduje to znaczne zredukowanie ilości przesyłanych danych oraz mniejsze obciążenie serwerów.

# 3.3.6

```
SQL> select * from rep_place where id_prac=150;

   ID_PRAC NAZWISKO         PLACA_POD  PLACA_DOD ETAT
---------- --------------- ---------- ---------- ----------
       150 KROLIKOWSKI          645.5            ADIUNKT
```

Po minucie

```
SQL> select * from rep_place where id_prac=150;

   ID_PRAC NAZWISKO         PLACA_POD  PLACA_DOD ETAT
---------- --------------- ---------- ---------- ----------
       150 KROLIKOWSKI            777            ADIUNKT
```

Zmiany się zaciągnęły.

# 3.4.7

rbd1:

```
SQL> select id_prac, placa_pod from pracownicy where id_prac=100;

   ID_PRAC  PLACA_POD
---------- ----------
       100       1730

1 row selected.

SQL> select * from etaty;

NAZWA       PLACA_MIN  PLACA_MAX
---------- ---------- ----------
PROFESOR          800       1500
ADIUNKT           510        750
ASYSTENT          300        500
STAZYSTA          150        250
SEKRETARKA        270        450
DYREKTOR         1280       2100

6 rows selected.

SQL> update pracownicy set placa_pod=placa_pod+50 where id_prac=100;

1 row updated.

SQL> update etaty set placa_min=placa_min+50 where nazwa='ASYSTENT';

1 row updated.

SQL> commit;

Commit complete.
```

rbd2 tuż po commit:

```
SQL> select id_prac, placa_pod from rep_place where id_prac=100;

   ID_PRAC  PLACA_POD
---------- ----------
       100       1730

SQL> select * from rep_etaty where nazwa='ASYSTENT';

NAZWA       PLACA_MIN  PLACA_MAX
---------- ---------- ----------
ASYSTENT          300        500
```

rbd2 po 2 minutach:

```
SQL> select id_prac, placa_pod from rep_place where id_prac=100;

   ID_PRAC  PLACA_POD
---------- ----------
       100       1780

SQL> select * from rep_etaty where nazwa='ASYSTENT';

NAZWA       PLACA_MIN  PLACA_MAX
---------- ---------- ----------
ASYSTENT          350        500
```
