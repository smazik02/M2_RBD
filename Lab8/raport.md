# Poziomy spójności odczytu i zapisu

cass0 - 10
cass1 - 9

## 7

```
cqlsh> select * from test.dist_tab;
NoHostAvailable: ('Unable to complete the operation against any hosts', {<Host: 127.0.0.1:9042 DC1-RBD>: Unavailable('Error from server: code=1000 [Unavailable exception] message="Cannot achieve consistency level ONE" info={\'consistency\': \'ONE\', \'required_replicas\': 1, \'alive_replicas\': 0}')})
```

Błąd wynika z tego że polecenie wymusza przeskanowanie całej tabeli na wszystkich węzłach, a ponieważ węzeł `rbd-cassandra-1` jest niedostępny to nie można spełnić warunku spójności `ONE` dla brakujących wierszy i zapytanie zakończy się błędem.

## 8

```
cqlsh> insert into test.dist_tab(id, tekst) values (9, 'x');
NoHostAvailable: ('Unable to complete the operation against any hosts', {<Host: 127.0.0.1:9042 DC1-RBD>: Unavailable('Error from server: code=1000 [Unavailable exception] message="Cannot achieve consistency level ONE" info={\'consistency\': \'ONE\', \'required_replicas\': 1, \'alive_replicas\': 0}')})
cqlsh> insert into test.dist_tab(id, tekst) values (10, 'y');
```

Pierwsza operacja się nie powiodła ponieważ wiersze o kluczu (id) 9 są przypisane do węzła `rbd-cassandra-1`, który nie działa. Wstawianie wiersza o kluczu przypisanym do nadal działającego węzła się wykona.

## 10

```
cqlsh> select * from test.dist_tab;
InvalidRequest: Error from server: code=2200 [Invalid query] message="ANY ConsistencyLevel is only supported for writes"
```

## 11

```
cqlsh> insert into test.dist_tab(id, tekst) values (9, 'x');
```

Operacja się powiodła

## 16

```
cqlsh> select * from test.dist_tab;

 id | tekst
----+-------
 10 |     y
  1 |     a
  2 |     b
  9 |     x

(4 rows)
```

Wiersz został zapisany ponieważ otrzymał po uruchomieniu tzw. hint od węzła `rbd-cassandra-0`.

## 18

```
cqlsh> consistency one;
Consistency level set to ONE.
cqlsh> select * from test.dist_tab;

 id | tekst
----+-------
 10 |     y
  1 |     a
  2 |     b
  9 |     x

(4 rows)
```

Tak jak wcześniej polecenie wymaga przeskanowania całej tabeli na wszystkich węzłach, ale ponieważ tym razem oba węzły działają to daje się spełnić warunek spójności `ONE` i operacja się powodzi.

# Odporność na awarie

## 6

```
cqlsh> insert into test2.dist_tab2(id, tekst) values (5, 'f');
```

Operacja się powiodła

## 7

```
cqlsh> select * from test2.dist_tab2;

 id | tekst
----+-------
  5 |     f
  4 |     e

(2 rows)
```

Obie operację się powiodły ponieważ keyspace `test2` ma współczynnik replikacji równy 2, co oznacza że cała przestrzeń kluczy jest replikowana na innym węźle. Tutaj oznacza to że wszystkie dane są na obu węzłach. Z tego powodu zarówno pierwsze polecenie (poziom spójności `ONE` wymaga by tylko wstawienia do jednego węzła, drugi odbierze tą operacje gdy ponownie wstanie - ten sam mechanizm hinted handoff), jak i drugie (oba węzły przechowują 100% danych, a ponieważ `ONE` wymaga odpowiedzi tylko od jednego to odpowiedź `rdb-cassandra-0` wystarczs) zakończyło się sukcesem. 

## 11

```
cqlsh> select * from test2.dist_tab2;

 id | tekst
----+-------
  5 |     f
  4 |     e

(2 rows)
```

# Dołączenie nowego węzła do klastra

## 5

```
cqlsh> select * from test2.dist_tab2;

 id | tekst
----+-------
  5 |     f
  4 |     e

(2 rows)
```

Z każdego węzła Cassandry możemy odpytać się o dane wszystkich innych węzłów i te dane zostaną dostarczone.

# Usunięcie węzła z klastra

## 6

```
cqlsh> select * from test2.dist_tab2;

 id | tekst
----+-------
  5 |     f
  4 |     e

(2 rows)
```

Wszystkie dane zostały przeniesione na 2 pozostałe węzły więc nadal się na nich znajdują.
