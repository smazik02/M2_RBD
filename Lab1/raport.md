# 1.24

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: pgsql-rbd2
spec:
  serviceName: pgsql-rbd2-service
  selector:
    matchLabels:
      app: pgsql-rbd2
  replicas: 1
  template:
    metadata:
      labels:
        app: pgsql-rbd2
    spec:
      nodeSelector:
        kubernetes.io/hostname: k3d-rbdcluster-agent-1
      containers:
        - name: pgsql-rbd2
          image: rbd/postgres17:1.0
          volumeMounts:
            - name: pgsql-rbd2-disk
              mountPath: /data
          env:
            - name: POSTGRES_PASSWORD
              value: rbd2
            - name: PGDATA
              value: /data/pgdata
  volumeClaimTemplates:
    - metadata:
        name: pgsql-rbd2-disk
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 25Mi
---
apiVersion: v1
kind: Service
metadata:
  name: pgsql-rbd2-lb
spec:
  type: LoadBalancer
  ports:
    - port: 5433
      targetPort: 5432
  selector:
    app: pgsql-rbd2
```

# 1.25

```sh
kubectl apply -f rbd2.yaml
```

# 2.13

```sql
CREATE SERVER rbd1
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'pgsql-rbd1-lb', port '5432', dbname 'postgres');

CREATE USER MAPPING FOR postgres SERVER rbd1
OPTIONS (user 'postgres', password 'rbd1');

IMPORT FOREIGN SCHEMA public LIMIT TO (pracownicy)
FROM SERVER rbd1 INTO public;
```

# 3.2.4

Tabele pracowników i zespołów posiadają oczekiwaną zmianę

# 3.3.8

W sytuacji awarii RBD1 występuje analogiczna sytuacja - transakcja zostaje wycofana i żadne zmiany nie zostały wprowadzone.

# 4.12

Główną wadą rozwiązania jest to że nie wykrywa ono zakleszczenia, lecz po prostu przerywa każde polecenie, które trwa dłużej niż ustalony limit, więc może niepotrzebnie wycofać transakcję, która czeka z zupełnie innych powodów, np. z powodu obciążenia systemu. Trudno też dobrać właściwą wartość limitu: zbyt krótki powoduje zbędne wycofania, a zbyt długi sprawia, że transakcje długo blokują zasoby i marnują czas przed rozwiązaniem problemu. Dodatkowo aplikacja musi sama obsłużyć błąd, wykonać ROLLBACK i powtórzyć całą transakcję, a SET LOCAL trzeba pamiętać w każdej transakcji i w każdej bazie, ponieważ jego pominięcie oznacza brak ochrony.

# 5.6

Polecenie `REFRESH MATERIALIZED VIEW` usuwa całą zawartość perspektywy i generuje ją od nowa, wykonując ponownie całe zapytanie, nawet jeśli zmienił się tylko jeden wiersz. Przy dużych tabelach jest to kosztowne (obciążenie źródła, sieci i repliki).

Dodatkowo odświeżanie trzeba wykonywać ręcznie lub cyklicznie (cron), więc między odświeżeniami replika zawiera nieaktualne dane.

# 5.20

```sql
SELECT cron.schedule(
    'odswiez_zespoly_replika',
    '*/5 * * * *',
    'REFRESH MATERIALIZED VIEW zespoly_replika'
);
```
