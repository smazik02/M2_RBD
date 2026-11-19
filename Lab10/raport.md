# Przygotowanie środowiska

## 10

```
❯ helm template ./mongo-shrd \
∙   --set clusterRole=configsvr \
∙   --set replicas=1 \
∙   --set replSetName=configsvr \
∙   --set-file keyfile=rbd-keyfile
---
# Source: mongo-shrd/templates/keyfile.yaml
apiVersion: v1
kind: Secret
metadata:
  # Nazwa zgodna z konwencją operatora MCK (<nazwa-zasobu>-keyfile)
  name: configsvr-keyfile
type: Opaque
stringData:
  keyfile: "PCtxH9Jh62TsHQZTKcA94hWyCfNO5RYvceTyH+/Gl1Giy6B/BF5X68rjA9uwSdRj\ndEpgtkssauG/1fXyYEkOWYsRd/YaPZCyFGKkOBjlb0RXoSmdGlAh79239VMgBMgu\ngaf1yFSMpKUWT0Wf+0iZCYwbV8Tsv05GGuFNpP+ZA3T60ZZcELT9Yaz2gMheTh+y\njWTDT/MD2uriIFLbSUxpBA6AC4CAO8sqcUdkNftcN0vT2aglTUbH4AR/V+kSx0uN\nexBKR+9bZqBNy5W6LfEkewHbcvTjIyerCP9Gl7JKCJfsixwD45ccv3K2+wTyx3Xc\n8JpFsFoJ6FYLyebgnS9IZ599NIok+64sG0g/mYtO7D9Oxi8Ce/JEmEt4kkXb0OMc\nze+INPBppNRrsYH/Y66x7nCPdsouGWT3NRAK9dM2P9FKwpaVW7L85nYGWhUiNanQ\nUFUm+VR/xINwnEWSaVG9hIFwCqpTey+6sMlo3Wp4WzjP3ll7G8kQuG3xXFq0CM66\nSFZi525ygrdp/if6kA284h6lc+MQ5Krb5V+hr/qf++byCwRHtEDrLT3RR0HgGe2a\nscJEByC2JQvv4PkF7SW3QoEZNP+RPgXFXqMDLXIhC/DcL8sXaOzN1qhCS5s5D/8S\nhIDJuHfm5ZbfGK0f2FKC4A5L4ffRWitB4Wc7D2PUqznUyCtpuRku9cpSv9BbcI0Q\nyX28MxxJc2hgdrTsaajpG9C9hKL0prqOBRky0UlrmnbbFAhXCqSnJ/YCIMgIgjLd\nXTFZ14ctjFxXDaGxy3NeyomlcTbteKieoeXQ0X9wF6QEXZEeIuTrECrQ44o1aQ2o\nXhWxQOabeVf3Afkq1BnEB+PGZUvf/fBboWw87MVdfoVfDw8A7GD95D+VHB3+yqBM\noaCQIm5bYMo4tOirAQSwcQbLDNkHhOWsjj/81PIPr+Tg89/EIP0ap2rox0+mBkn+\n/um4zUgKjMsqQaOoDyF+wsLkcCvG+g8nggUC0xj8fSA10utT"

---
# Source: mongo-shrd/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: configsvr-configmap
data:
  mongod.conf: |-
    net:
      bindIpAll: true
      port: 27017
    security:
      keyFile: /keyfile/keyfile
    sharding:
      clusterRole: configsvr
    replication:
      replSetName: configsvr
    storage:
      dbPath: /data

---
# Source: mongo-shrd/templates/manifests.yaml
# Węzły konfiguracyjne i rutery zapytań, które nie są obsługiwane przez operator MCK
# w wersji Community, są wdrażane jako zwykłe StatefulSet
apiVersion: v1
kind: Service
metadata:
  name: configsvr-svc
  labels:
    name: configsvr
spec:
  ports:
    - port: 27017
      targetPort: 27017
  clusterIP: None
  selector:
    role: configsvr

---
# Source: mongo-shrd/templates/manifests.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: configsvr
spec:
  selector:
    matchLabels:
      role: configsvr
  serviceName: configsvr-svc
  replicas: 1
  template:
    metadata:
      labels:
        role: configsvr
    spec:
      terminationGracePeriodSeconds: 30
      securityContext:
        runAsUser: 2000
        runAsGroup: 2000
        fsGroup: 2000
        runAsNonRoot: true
      initContainers:
        # mongod/mongos wymagają, aby plik klucza był dostępny wyłącznie dla właściciela
        - name: keyfile-permissions
          image: quay.io/mongodb/mongodb-community-server:9.0.4-ubi8
          command: ["sh", "-c", "cp /keyfile-secret/keyfile /keyfile/keyfile && chmod 400 /keyfile/keyfile"]
          volumeMounts:
            - name: keyfile-secret
              mountPath: /keyfile-secret
            - name: keyfile
              mountPath: /keyfile
      containers:
        - name: configsvr
          image: quay.io/mongodb/mongodb-community-server:9.0.4-ubi8
          command:
            - mongod
            - --config
            - /etc/config/mongod.conf
          env:
            - name: HOME
              value: /tmp
          ports:
            - containerPort: 27017
          readinessProbe:
            tcpSocket:
              port: 27017
            initialDelaySeconds: 5
            periodSeconds: 5
          volumeMounts:
            - name: mongo-persistent-storage
              mountPath: /data
            - name: config-volume
              mountPath: /etc/config
            - name: keyfile
              mountPath: /keyfile
      volumes:
        - name: config-volume
          configMap:
            name: configsvr-configmap
        - name: keyfile-secret
          secret:
            secretName: configsvr-keyfile
        - name: keyfile
          emptyDir: {}
  volumeClaimTemplates:
    - metadata:
        name: mongo-persistent-storage
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 1Gi
```

Zostały wygenerowane 4 manifesty - 1 z configmap, 1 z keyfile i 2 z manifests. Plik shard.yaml został pominięty.

## 14

```
❯ helm template ./mongo-shrd \
∙   --set clusterRole=shardsvr \
∙   --set replicas=1 \
∙   --set replSetName=shard-a \
∙   --set-file keyfile=rbd-keyfile
---
# Source: mongo-shrd/templates/keyfile.yaml
apiVersion: v1
kind: Secret
metadata:
  # Nazwa zgodna z konwencją operatora MCK (<nazwa-zasobu>-keyfile)
  name: shard-a-keyfile
type: Opaque
stringData:
  keyfile: "PCtxH9Jh62TsHQZTKcA94hWyCfNO5RYvceTyH+/Gl1Giy6B/BF5X68rjA9uwSdRj\ndEpgtkssauG/1fXyYEkOWYsRd/YaPZCyFGKkOBjlb0RXoSmdGlAh79239VMgBMgu\ngaf1yFSMpKUWT0Wf+0iZCYwbV8Tsv05GGuFNpP+ZA3T60ZZcELT9Yaz2gMheTh+y\njWTDT/MD2uriIFLbSUxpBA6AC4CAO8sqcUdkNftcN0vT2aglTUbH4AR/V+kSx0uN\nexBKR+9bZqBNy5W6LfEkewHbcvTjIyerCP9Gl7JKCJfsixwD45ccv3K2+wTyx3Xc\n8JpFsFoJ6FYLyebgnS9IZ599NIok+64sG0g/mYtO7D9Oxi8Ce/JEmEt4kkXb0OMc\nze+INPBppNRrsYH/Y66x7nCPdsouGWT3NRAK9dM2P9FKwpaVW7L85nYGWhUiNanQ\nUFUm+VR/xINwnEWSaVG9hIFwCqpTey+6sMlo3Wp4WzjP3ll7G8kQuG3xXFq0CM66\nSFZi525ygrdp/if6kA284h6lc+MQ5Krb5V+hr/qf++byCwRHtEDrLT3RR0HgGe2a\nscJEByC2JQvv4PkF7SW3QoEZNP+RPgXFXqMDLXIhC/DcL8sXaOzN1qhCS5s5D/8S\nhIDJuHfm5ZbfGK0f2FKC4A5L4ffRWitB4Wc7D2PUqznUyCtpuRku9cpSv9BbcI0Q\nyX28MxxJc2hgdrTsaajpG9C9hKL0prqOBRky0UlrmnbbFAhXCqSnJ/YCIMgIgjLd\nXTFZ14ctjFxXDaGxy3NeyomlcTbteKieoeXQ0X9wF6QEXZEeIuTrECrQ44o1aQ2o\nXhWxQOabeVf3Afkq1BnEB+PGZUvf/fBboWw87MVdfoVfDw8A7GD95D+VHB3+yqBM\noaCQIm5bYMo4tOirAQSwcQbLDNkHhOWsjj/81PIPr+Tg89/EIP0ap2rox0+mBkn+\n/um4zUgKjMsqQaOoDyF+wsLkcCvG+g8nggUC0xj8fSA10utT"

---
# Source: mongo-shrd/templates/shard.yaml
apiVersion: v1
kind: Secret
metadata:
  name: shard-a-admin-password
type: Opaque
stringData:
  password: "rbd-mongo"

---
# Source: mongo-shrd/templates/shard.yaml
# Zbiór replikacji węzłów fragmentów zarządzany przez operator MCK
apiVersion: mongodbcommunity.mongodb.com/v1
kind: MongoDBCommunity
metadata:
  name: shard-a
spec:
  members: 1
  type: ReplicaSet
  version: "9.0.4"
  security:
    authentication:
      modes: ["SCRAM"]
  users:
    - name: rbd-admin
      db: admin
      passwordSecretRef:
        name: shard-a-admin-password
      roles:
        - name: clusterAdmin
          db: admin
        - name: userAdminAnyDatabase
          db: admin
      scramCredentialsSecretName: shard-a-rbd-admin
  additionalMongodConfig:
    sharding.clusterRole: shardsvr
    net.port: 27017
```

Różnice wynikają z wykorzystania ifa w plikach templates. Z parametrem `clusterRole=shardsvr` helm pominął pliki configmap i manifests, za to wygenerował odpowiednie manifesty z pliku shard.

## 16

```
❯ helm install mongo-shard-b rbd/mongo-shrd --version 2.0.0 \
∙   --set clusterRole=shardsvr \
∙   --set replicas=1 \
∙   --set replSetName=shard-b \
∙   --set-file keyfile=rbd-keyfile
NAME: mongo-shard-b
LAST DEPLOYED: Thu Nov 19 14:06:32 2026
NAMESPACE: default
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None

❯ helm install mongo-shard-c rbd/mongo-shrd --version 2.0.0 \
∙   --set clusterRole=shardsvr \
∙   --set replicas=1 \
∙   --set replSetName=shard-c \
∙   --set-file keyfile=rbd-keyfile
NAME: mongo-shard-c
LAST DEPLOYED: Thu Nov 19 14:06:38 2026
NAMESPACE: default
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None

❯ helm ls
NAME                            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
mongo-configsvr                 default         1               2026-11-19 13:50:07.295099 +0100 CET    deployed        mongo-shrd-2.0.0                9.0.4
mongo-shard-a                   default         1               2026-11-19 14:04:53.791951 +0100 CET    deployed        mongo-shrd-2.0.0                9.0.4
mongo-shard-b                   default         1               2026-11-19 14:06:32.50883 +0100 CET     deployed        mongo-shrd-2.0.0                9.0.4
mongo-shard-c                   default         1               2026-11-19 14:06:38.043325 +0100 CET    deployed        mongo-shrd-2.0.0                9.0.4
mongodb-kubernetes-operator     default         1               2026-11-19 13:34:35.349806 +0100 CET    deployed        mongodb-kubernetes-1.15.0

❯ kubectl get mdbc --watch
NAME      PHASE     VERSION
shard-a   Running   9.0.4
shard-b   Pending
shard-c   Pending
shard-b   Running   9.0.4
shard-b   Running   9.0.4
shard-c   Running   9.0.4
shard-c   Running   9.0.4
```

# Rozpraszanie kolekcji dokumentów na poziome fragmenty

## 10

```sh
kubectl exec -it mongos-0 -c mongos -- mongoimport \
 --username rbd-admin --password rbd-mongo --authenticationDatabase admin \
 --db test --collection loggers \
 --file /data/loggers-json/loggers.json
 
 kubectl exec -it mongos-0 -c mongos -- mongoimport \
 --username rbd-admin --password rbd-mongo --authenticationDatabase admin \
 --db test --collection measurements \
 --file /data/loggers-json/measurements.json
 
kubectl exec -it mongos-0 -c mongos -- mongoimport \
 --username rbd-admin --password rbd-mongo --authenticationDatabase admin \
 --db test --collection organizations \
 --file /data/loggers-json/organizations.json
```

## 12

```js
databases
[
  {
    database: { _id: 'config', primary: 'config', partitioned: true },
    collections: {
      'config.system.sessions': {
        shardKey: { _id: 1 },
        unique: false,
        balancing: true,
        allowMigrations: true,
        chunkMetadata: [ { shard: 'shard-a', nChunks: 1 } ],
        chunks: [
          { min: { _id: MinKey() }, max: { _id: MaxKey() }, 'on shard': 'shard-a', 'last modified': Timestamp({ t: 1, i: 0 }) }
        ],
        tags: []
      }
    }
  },
  {
    database: {
      _id: 'test',
      primary: 'shard-b',
      version: {
        uuid: UUID('3d491057-f951-4b85-bb10-62fee594ac07'),
        timestamp: Timestamp({ t: 1795093912, i: 9 }),
        lastMod: 1
      }
    },
    collections: {
      'test.loggers': {
        shardKey: { lo_or_id: 'hashed' },
        unique: false,
        balancing: true,
        allowMigrations: true,
        chunkMetadata: [
          { shard: 'shard-a', nChunks: 1 },
          { shard: 'shard-b', nChunks: 1 },
          { shard: 'shard-c', nChunks: 1 }
        ],
        chunks: [
          { min: { lo_or_id: MinKey() }, max: { lo_or_id: Long('-3074457345618258602') }, 'on shard': 'shard-c', 'last modified': Timestamp({ t: 1, i: 0 }) },
          { min: { lo_or_id: Long('-3074457345618258602') }, max: { lo_or_id: Long('3074457345618258602') }, 'on shard': 'shard-a', 'last modified': Timestamp({ t: 1, i: 1 }) },
          { min: { lo_or_id: Long('3074457345618258602') }, max: { lo_or_id: MaxKey() }, 'on shard': 'shard-b', 'last modified': Timestamp({ t: 1, i: 2 }) }
        ],
        tags: []
      },
      'test.measurements': {
        shardKey: { meta: 'hashed' },
        unique: false,
        balancing: true,
        allowMigrations: true,
        chunkMetadata: [
          { shard: 'shard-a', nChunks: 1 },
          { shard: 'shard-b', nChunks: 1 },
          { shard: 'shard-c', nChunks: 1 }
        ],
        chunks: [
          { min: { meta: MinKey() }, max: { meta: Long('-3074457345618258602') }, 'on shard': 'shard-c', 'last modified': Timestamp({ t: 1, i: 0 }) },
          { min: { meta: Long('-3074457345618258602') }, max: { meta: Long('3074457345618258602') }, 'on shard': 'shard-a', 'last modified': Timestamp({ t: 1, i: 1 }) },
          { min: { meta: Long('3074457345618258602') }, max: { meta: MaxKey() }, 'on shard': 'shard-b', 'last modified': Timestamp({ t: 1, i: 2 }) }
        ],
        tags: []
      },
      'test.organizations': {
        shardKey: { _id: 'hashed' },
        unique: false,
        balancing: true,
        allowMigrations: true,
        chunkMetadata: [
          { shard: 'shard-a', nChunks: 1 },
          { shard: 'shard-b', nChunks: 1 },
          { shard: 'shard-c', nChunks: 1 }
        ],
        chunks: [
          { min: { _id: MinKey() }, max: { _id: Long('-3074457345618258602') }, 'on shard': 'shard-c', 'last modified': Timestamp({ t: 1, i: 0 }) },
          { min: { _id: Long('-3074457345618258602') }, max: { _id: Long('3074457345618258602') }, 'on shard': 'shard-a', 'last modified': Timestamp({ t: 1, i: 1 }) },
          { min: { _id: Long('3074457345618258602') }, max: { _id: MaxKey() }, 'on shard': 'shard-b', 'last modified': Timestamp({ t: 1, i: 2 }) }
        ],
        tags: []
      }
    }
  }
]
```

Węzłem podstawowym bazy danych `test` jest `shard-b` (wpis `primary: 'shard-b'`). Każda kolekcja została podzielona na 3 fragmenty/shardy (`shard-a`, `shard-b` i `shard-c`), a każdy fragment składa się z 1 chunku dla wszystkoch kolekcji (wpis `nChunks` w `chunkMedatada`).

## 13

```
[direct: mongos] test> db.loggers.getShardDistribution()
Shard shard-b at shard-b/shard-b-0.shard-b-svc.default.svc.cluster.local:27017
{
  data: '69KiB',
  docs: 915,
  chunks: 1,
  'estimated data per chunk': '69KiB',
  'estimated docs per chunk': 915
}
---
Shard shard-a at shard-a/shard-a-0.shard-a-svc.default.svc.cluster.local:27017
{
  data: '70KiB',
  docs: 926,
  chunks: 1,
  'estimated data per chunk': '70KiB',
  'estimated docs per chunk': 926
}
---
Shard shard-c at shard-c/shard-c-0.shard-c-svc.default.svc.cluster.local:27017
{
  data: '57KiB',
  docs: 756,
  chunks: 1,
  'estimated data per chunk': '57KiB',
  'estimated docs per chunk': 756
}
---
Totals
{
  data: '196KiB',
  docs: 2597,
  chunks: 3,
  'Shard shard-b': [
    '35.21 % data',
    '35.23 % docs in cluster',
    '77B avg obj size on shard'
  ],
  'Shard shard-a': [
    '35.69 % data',
    '35.65 % docs in cluster',
    '77B avg obj size on shard'
  ],
  'Shard shard-c': [
    '29.08 % data',
    '29.11 % docs in cluster',
    '77B avg obj size on shard'
  ]
}
```

Polecenie to pozwala zobaczyć procentowy udział dokumentów i danych w każdym shardzie, oraz przybliżony rozmiar danych i ilość dokumentów na pojedynczy chunk.

## 16

Zapytanie `db.loggers.find()` nie ma żadnych filtrów a kolekcja jest rozproszona po wszystkich 3 węzłach klastra, wobec tego `mongos` jest zmuszone wysłać zapytanie do wszystkich 3 shardów, a nastepnie scalić ich wyniki (`SHARD_MERGE`). Dodatkowo każdy shard wykonuje pełne skanowanie kolekcji `COLLSCAN` z filtrowaniem chunków.

Zapytanie `db.organizations.find({_id:30})` zapytuje bezpośrednio po `_id`, które jest kluczem shardingu kolekcji. `mongos` może więc obliczyć hash wartości `_id`, sprawdzić w metadanych klastra w którym chunku leży wynik, i skierować zapytanie wyłącznie do jednego właściwego fragmentu. Dodatkowo fragment może pobrać dokument bezpośrednio po indeksie unikalnym (`EXPRESS_IXSCAN`) bez skanowania całej kolekcji.

## 20

Pierwsze zapytanie (bez `$match`) kierowane jest do wszystkich 3 shardów, na każdym wykonywane jest pełne skanowanie kolekcji `organizations`, a następnie inicjowany jest etap `$lookup`. Ponieważ dane pochodzą z wielu węzłów to dodatkowo na routerze `mongos` wykonywane jest scalanie.

Drugie zapytanie trafia wyłącznie do 1 shardu, ponieważ filtruje bezpośrednio po polu `_id` które jest kluczem shardingu kolekcji. Na tym shardzie dokument pobiera się bezpośrednio po indeksie, a następnie na tym jednym węźle uruchamiany jest lookup. Ponieważ dane pochodzą z jednego węzła, `mongos` nie musi nic scalać.

Przedstawione plany nie zawierają informacji o tym które shardy zostały odczytane z kolekcji `loggers`, pokazują jednie samą obecność etapu `$lookup`.

Nie ma żadnej gwarancji, że dokumenty leżą na tym samym shardzie i połączenie wykona się na jednym węźle, ponieważ MongoDB nie ma kolokacji i nie wiąże ze sobą chunków różnych kolekcji. Wraz ze wzrostem liczby dokumentów w `loggers`, chunki tej kolekcji będą dzielone i przenoszone na inne shardy niezależnie od chunków kolekcji `organizations`.

Minimalna liczba węzłów fragmentów do tego połączenia to 1 (gdy zarówno dokument organizacji jak i wszystkie loggery znajdują się na tym samym shardzie), a maksymalna to 2 - wynika to z tego, że `lo_or_id` jest kluczem shardingu kolekcji `loggers`, więc podczas lookupu shard wykonuje podzapytanie tylko do jednego konkretnego shardu przechowującego chunk dla hasha danej wartości. W najgorszym razie będzie to zapytanie do innego węzła. Gdyby to pole nie było kluczem shardingu, to podzapytanie musiałoby przeszukać wszystkie fragmenty kolekcji.

# 22

Minimalna to 1, a maksymalna to 2. Wynika to z tego, że kolekcja `logger-types` nie jest poddana shardingowi, więc znajduje się w całości na węźle primary (`shard-b`). Odczyt `loggers` jest filtrowany bezpośrednio po kluczu shardingu, więc zawsze trafia tylko do 1 shardu. Jeśli jest to akurat shard na którym jest kolekcja `logger-types`, to zapytanie powędruje tylko do niego. Jeśli nie to potrzebne jest również zapytanie do drugiego shardu.

# Rozszerzenie klastra MongoDB

## 1

```sh
helm install mongo-shard-d rbd/mongo-shrd --version 2.0.0 \
  --set clusterRole=shardsvr \
  --set replicas=1 \
  --set replSetName=shard-d \
  --set-file keyfile=rbd-keyfile
```

Ręczne wykonanie polecenia `rs.initiate()` nie jest tu wymagane, bo węzły fragmentów są inicjalizowane automatycznie przez operator MCK w wersji Community. Wersja ta nie obsługuje węzłów konfiguracyjnych ani ruterów zapytań, w związku z czym zostały zdefiniowane jako zwykłe StatefulSety, a wówczas wymagana jest dodatkowa ręczna inicjalizacja.

## 2

```js
sh.addShard("shard-d/shard-d-0.shard-d-svc.default.svc.cluster.local:27017")
```

## 3

Nie, dodanie nowego węzła nie powoduje automatycznego rozproszenia kolekcji.

## 5

Polecenie split podzieliło istniejący chunk na `shard-a` na 2 mniejsze fragmenty, ale oba pozostały na tym samym węźle. Wynika to z tego że balancer podejmuje decyzję o migracji na podstawie rozmiaru danych (a nie liczby chunków) i uruchamia równoważenie dopiero wtedy, gdy różnica między najbardziej obciążonym a najmniej obciążonym shardem dla danej kolekcji przekroczy trzykrotność rozmiaru chunka. Jako że wszystkie trzy kolekcje mają zdecydowanie mniejszą objętość, to dla każdej z nich system uznaje dystrybucję za zgodną z polityką równoważenia i nie inicjuje automatycznej migracji danych.

## 6

```
[direct: mongos] test> sh.moveChunk("test.organizations", { _id : 99 }, "shard-d")
{
  millis: 324,
  ok: 1,
  '$clusterTime': {
    clusterTime: Timestamp({ t: 1795103234, i: 58 }),
    signature: {
      hash: Binary.createFromBase64('9R67wW/qnTvsYj/QJbYLlkgT6S8=', 0),
      keyId: Long('7709868893669425192')
    }
  },
  operationTime: Timestamp({ t: 1795103234, i: 56 })
}

[direct: mongos] test> db.organizations.getShardDistribution()
Shard shard-c at shard-c/shard-c-0.shard-c-svc.default.svc.cluster.local:27017
{
  data: '5KiB',
  docs: 84,
  chunks: 1,
  'estimated data per chunk': '5KiB',
  'estimated docs per chunk': 84
}
---
Shard shard-d at shard-d/shard-d-0.shard-d-svc.default.svc.cluster.local:27017
{
  data: '3KiB',
  docs: 56,
  chunks: 1,
  'estimated data per chunk': '3KiB',
  'estimated docs per chunk': 56
}
---
Shard shard-a at shard-a/shard-a-0.shard-a-svc.default.svc.cluster.local:27017
{
  data: '3KiB',
  docs: 113,
  chunks: 1,
  'estimated data per chunk': '3KiB',
  'estimated docs per chunk': 113
}
---
Shard shard-b at shard-b/shard-b-0.shard-b-svc.default.svc.cluster.local:27017
{
  data: '6KiB',
  docs: 103,
  chunks: 1,
  'estimated data per chunk': '6KiB',
  'estimated docs per chunk': 103
}
---
Totals
{
  data: '18KiB',
  docs: 356,
  chunks: 4,
  'Shard shard-c': [
    '28.08 % data',
    '23.59 % docs in cluster',
    '63B avg obj size on shard'
  ],
  'Shard shard-d': [
    '18.64 % data',
    '15.73 % docs in cluster',
    '63B avg obj size on shard'
  ],
  'Shard shard-a': [
    '19.1 % data',
    '31.74 % docs in cluster',
    '63B avg obj size on shard'
  ],
  'Shard shard-b': [
    '34.16 % data',
    '28.93 % docs in cluster',
    '63B avg obj size on shard'
  ]
}
```

# Skurczenie klastra MongoDB

## 4

```
[direct: mongos] test> sh.status()
shardingVersion
{
  _id: ObjectId('6afef4e9cd0c903c95b0d8ba'),
  clusterId: ObjectId('6afef4e9cd0c903c95b0d8b9')
}
---
shards
[
  {
    _id: 'shard-a',
    uuid: UUID('7f669fb2-372e-4885-8efa-552ac98ee836'),
    host: 'shard-a/shard-a-0.shard-a-svc.default.svc.cluster.local:27017',
    topologyTime: Timestamp({ t: 1795103719, i: 13 }),
    replSetConfigVersion: Long('-1')
  },
  {
    _id: 'shard-c',
    uuid: UUID('e011c641-339a-4f92-8382-63354f19789c'),
    host: 'shard-c/shard-c-0.shard-c-svc.default.svc.cluster.local:27017',
    topologyTime: Timestamp({ t: 1795093869, i: 24 }),
    replSetConfigVersion: Long('-1')
  },
  {
    _id: 'shard-d',
    uuid: UUID('60f29205-48f9-4da8-a57c-36401ff7ba92'),
    host: 'shard-d/shard-d-0.shard-d-svc.default.svc.cluster.local:27017',
    topologyTime: Timestamp({ t: 1795102580, i: 24 }),
    replSetConfigVersion: Long('-1')
  }
]
...
```

Nie jest.
