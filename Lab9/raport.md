# 1. Przygotowanie środowiska

## 14

```
rbd-mongodb [direct: primary] test> rs.status().members.forEach(
...   function(z){
...     printjson(z.name);
...     printjson(z.stateStr);
...   }
... );
rbd-mongodb-0.rbd-mongodb-svc.default.svc.cluster.local:27017
PRIMARY
rbd-mongodb-1.rbd-mongodb-svc.default.svc.cluster.local:27017
SECONDARY
rbd-mongodb-2.rbd-mongodb-svc.default.svc.cluster.local:27017
SECONDARY
```

# 2. Testowanie mechanizmu replikacji danych

## 2

```
rbd-mongodb [direct: secondary] test> db.pracownicy.find()
[
  {
    _id: ObjectId('6af5fc5f828bab7e67284d0c'),
    nazwisko: 'Kowalski',
    etat: 'Stazysta',
    placa: 2222
  }
]
```

## 4

```
rbd-mongodb [direct: secondary] test> db.pracownicy.insertOne({nazwisko: "Zielinski", etat: "Adiunkt", placa: 2800})
MongoServerError[NotWritablePrimary]: not primary
```

MongoDB nie pozwala na zapis do węzła podrzędnego, jedynie odczyt.

## 5

```
bash-4.4$ mongosh "mongodb://rbd-user:rbd-mongo@rbd-mongodb-svc:27017/test?replicaSet=rbd-mongodb&authSource=admin"
Current Mongosh Log ID: 6af5fcd72aab58d204284d0b
Connecting to:          mongodb://<credentials>@rbd-mongodb-svc:27017/test?replicaSet=rbd-mongodb&authSource=admin&appName=mongosh+2.6.0
Using MongoDB:          9.0.4
Using Mongosh:          2.6.0
mongosh 2.14.2 is available for download: https://www.mongodb.com/try/download/shell

For mongosh info see: https://www.mongodb.com/docs/mongodb-shell/

rbd-mongodb [primary] test> db.hello().primary
rbd-mongodb-0.rbd-mongodb-svc.default.svc.cluster.local:27017
rbd-mongodb [primary] test> db.pracownicy.insertOne({nazwisko: "Zielinski", etat: "Adiunkt", placa: 2800})
{
  acknowledged: true,
  insertedId: ObjectId('6af5fcee2aab58d204284d0c')
}
```

Podłączając się do zbioru replikacji jesteśmy automatycznie przekierowani do węzła nadrzędnego, więc możemy dokonywać operacji zapisu.

# 3. Testowanie mechanizmu przełączenia awaryjnego

## 4

```
rbd-mongodb [direct: primary] test> db.pracownicy.insertOne({nazwisko: "Malińska", etat: "Asystent",placa: 3222})
...
{
  acknowledged: true,
  insertedId: ObjectId('6af5ff0c828bab7e67284d0d')
}
```

## 5

```
rbd-mongodb [direct: secondary] test> db.pracownicy.find()
[
  {
    _id: ObjectId('6af5fc5f828bab7e67284d0c'),
    nazwisko: 'Kowalski',
    etat: 'Stazysta',
    placa: 2222
  },
  {
    _id: ObjectId('6af5fcee2aab58d204284d0c'),
    nazwisko: 'Zielinski',
    etat: 'Adiunkt',
    placa: 2800
  },
  {
    _id: ObjectId('6af5ff0c828bab7e67284d0d'),
    nazwisko: 'Malińska',
    etat: 'Asystent',
    placa: 3222
  }
]
```

## 6

```
rbd-mongodb [direct: secondary] test> db.pracownicy.find()
[
  {
    _id: ObjectId('6af5fc5f828bab7e67284d0c'),
    nazwisko: 'Kowalski',
    etat: 'Stazysta',
    placa: 2222
  },
  {
    _id: ObjectId('6af5fcee2aab58d204284d0c'),
    nazwisko: 'Zielinski',
    etat: 'Adiunkt',
    placa: 2800
  },
  {
    _id: ObjectId('6af5ff0c828bab7e67284d0d'),
    nazwisko: 'Malińska',
    etat: 'Asystent',
    placa: 3222
  }
]
```

Awaria węzła podrzędnego nie ma żadnego wpływu na działanie klastra - operacje odczytu i zapisu mają miejsce tak jak powinny.

## 8

```
rbd-mongodb [direct: primary] test> db.hello().isWritablePrimary
false
rbd-mongodb [direct: secondary] test> db.pracownicy.insertOne({nazwisko: "Nowak", etat: "Dyrektor",placa: 4222})
MongoServerError[NotWritablePrimary]: not primary
```

## 9

```
rbd-mongodb [direct: secondary] test> db.pracownicy.find()
[
  {
    _id: ObjectId('6af5fc5f828bab7e67284d0c'),
    nazwisko: 'Kowalski',
    etat: 'Stazysta',
    placa: 2222
  },
  {
    _id: ObjectId('6af5fcee2aab58d204284d0c'),
    nazwisko: 'Zielinski',
    etat: 'Adiunkt',
    placa: 2800
  },
  {
    _id: ObjectId('6af5ff0c828bab7e67284d0d'),
    nazwisko: 'Malińska',
    etat: 'Asystent',
    placa: 3222
  }
]
```

## 10

```
rbd-mongodb [direct: primary] test> db.pracownicy.find()
[
  {
    _id: ObjectId('6af5fc5f828bab7e67284d0c'),
    nazwisko: 'Kowalski',
    etat: 'Stazysta',
    placa: 2222
  },
  {
    _id: ObjectId('6af5fcee2aab58d204284d0c'),
    nazwisko: 'Zielinski',
    etat: 'Adiunkt',
    placa: 2800
  },
  {
    _id: ObjectId('6af5ff0c828bab7e67284d0d'),
    nazwisko: 'Malińska',
    etat: 'Asystent',
    placa: 3222
  }
]
```

Nie został.

## 14

```
rbd-mongodb [direct: secondary] test> rs.status().members.forEach(
...   function(z){
...     printjson(z.name);
...     printjson(z.stateStr);
...   }
... );
rbd-mongodb-0.rbd-mongodb-svc.default.svc.cluster.local:27017
(not reachable/healthy)
rbd-mongodb-1.rbd-mongodb-svc.default.svc.cluster.local:27017
PRIMARY
rbd-mongodb-2.rbd-mongodb-svc.default.svc.cluster.local:27017
SECONDARY
```

# 15

```
rbd-mongodb [direct: secondary] test> db.pracownicy.find()
[
  {
    _id: ObjectId('6af5fc5f828bab7e67284d0c'),
    nazwisko: 'Kowalski',
    etat: 'Stazysta',
    placa: 2222
  },
  {
    _id: ObjectId('6af5fcee2aab58d204284d0c'),
    nazwisko: 'Zielinski',
    etat: 'Adiunkt',
    placa: 2800
  },
  {
    _id: ObjectId('6af5ff0c828bab7e67284d0d'),
    nazwisko: 'Malińska',
    etat: 'Asystent',
    placa: 3222
  }
]

rbd-mongodb [direct: secondary] test> rs.status().members.forEach(
...   function(z){
...     printjson(z.name);
...     printjson(z.stateStr);
...   }
... );
rbd-mongodb-0.rbd-mongodb-svc.default.svc.cluster.local:27017
SECONDARY
rbd-mongodb-1.rbd-mongodb-svc.default.svc.cluster.local:27017
PRIMARY
rbd-mongodb-2.rbd-mongodb-svc.default.svc.cluster.local:27017
SECONDARY
```

Węzeł `rbd-mongodb-1` został węzłem nadrzędnym nawet gdy `rbd-mongodb-0` wrócił.

# 4. Dodanie arbitra do zbioru replikacji

## 7

przed

```rbd-mongodb [direct: secondary] test> rs.status().members.forEach(
...   function(z){
...     printjson(z.name);
...     printjson(z.stateStr);
...   }
... );
rbd-mongodb-0.rbd-mongodb-svc.default.svc.cluster.local:27017
PRIMARY
rbd-mongodb-1.rbd-mongodb-svc.default.svc.cluster.local:27017
SECONDARY
rbd-mongodb-2.rbd-mongodb-svc.default.svc.cluster.local:27017
SECONDARY
rbd-mongodb-arb-0.rbd-mongodb-svc.default.svc.cluster.local:27017
ARBITER
rbd-mongodb-arb-1.rbd-mongodb-svc.default.svc.cluster.local:27017
ARBITER
```

po

```
rbd-mongodb [direct: primary] test> rs.status().members.forEach(
...   function(z){
...     printjson(z.name);
...     printjson(z.stateStr);
...   }
... );
rbd-mongodb-0.rbd-mongodb-svc.default.svc.cluster.local:27017
PRIMARY
rbd-mongodb-1.rbd-mongodb-svc.default.svc.cluster.local:27017
(not reachable/healthy)
rbd-mongodb-2.rbd-mongodb-svc.default.svc.cluster.local:27017
(not reachable/healthy)
rbd-mongodb-arb-0.rbd-mongodb-svc.default.svc.cluster.local:27017
ARBITER
rbd-mongodb-arb-1.rbd-mongodb-svc.default.svc.cluster.local:27017
ARBITER
```

## 8

```
rbd-mongodb [direct: primary] test> db.pracownicy.insertOne({nazwisko: "Arbiter1"}, {writeConcern: {w: 1}})
{
  acknowledged: true,
  insertedId: ObjectId('6af60a192434685440284d0c')
}

rbd-mongodb [direct: primary] test> db.pracownicy.insertOne({nazwisko: "Arbiter2"}, {writeConcern: {w: "majority", wtimeout: 5000}})
Uncaught:
MongoWriteConcernError[WriteConcernTimeout]: waiting for replication timed out
Additional information: {
  wtimeout: true,
  writeConcern: { w: 'majority', wtimeout: 5000, provenance: 'clientSupplied' }
}
Result: {
  n: 1,
  electionId: ObjectId('7fffffff0000000000000005'),
  opTime: { ts: Timestamp({ t: 1794509341, i: 1 }), t: 5 },
  writeConcernError: {
    code: 64,
    codeName: 'WriteConcernTimeout',
    errmsg: 'waiting for replication timed out',
    errInfo: {
      wtimeout: true,
      writeConcern: { w: 'majority', wtimeout: 5000, provenance: 'clientSupplied' }
    }
  },
  ok: 1,
  '$clusterTime': {
    clusterTime: Timestamp({ t: 1794509341, i: 1 }),
    signature: {
      hash: Binary.createFromBase64('/cWvMbjdJEVmbZTsYm+EAbTGUkU=', 0),
      keyId: Long('7707338487917182984')
    }
  },
  operationTime: Timestamp({ t: 1794509341, i: 1 })
}
```

Pierwsze polecenie z writeConcern w:1 wymaga potwierdzenia zapisu tylko od jednego węzła nadrzędnego Primary, więc jeśli węzeł ten działa to wykonuje się natychmiast. W przypadku w: majority potrzeba potwierdzenia od większości węzłów przechowujących dane (w klastrze 3-węzłowym to 2 węzły - węzły ARBITER nie przechowują danych więc się nie wliczają). Ponieważ uzyskaliśmy odpowiedź tylko od jednego działającego węzła, to węzeł primary czekał 5000 ms (5 sekund) na odpowiedź, po czym zwrócił błąd.

## 9

```
rbd-mongodb [direct: primary] test> rs.status().members.forEach(
...   function(z){
...     printjson(z.name);
...     printjson(z.stateStr);
...   }
... );
rbd-mongodb-0.rbd-mongodb-svc.default.svc.cluster.local:27017
PRIMARY
rbd-mongodb-1.rbd-mongodb-svc.default.svc.cluster.local:27017
SECONDARY
rbd-mongodb-2.rbd-mongodb-svc.default.svc.cluster.local:27017
SECONDARY
rbd-mongodb-arb-0.rbd-mongodb-svc.default.svc.cluster.local:27017
ARBITER
rbd-mongodb-arb-1.rbd-mongodb-svc.default.svc.cluster.local:27017
ARBITER
```
