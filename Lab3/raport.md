# 2.6

```sh
$ kubectl get sts
NAME                READY   AGE
rbd-citus-coord-1   1/1     62s
rbd-citus-coord-2   1/1     36s
```

Operator Kubegres utworzył 2 obiekty StatefulSet: podstawowy (rbd-citus-coord-1) oraz czuwający (rbd-citus-coord-2). Zdarzenia klastra potwierdzają sprowizjonowanie wolumenów PVC, bazy podstawowej oraz repliki.

# 2.7

```sh
$ kubectl get svc
NAME                      TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
kubernetes                ClusterIP   10.43.0.1    <none>        443/TCP    2m31s
rbd-citus-coord           ClusterIP   None         <none>        5432/TCP   49s
rbd-citus-coord-replica   ClusterIP   None         <none>        5432/TCP   21s

$ kubectl get endpoints
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME                      ENDPOINTS           AGE
kubernetes                192.168.97.2:6443   2m41s
rbd-citus-coord           10.42.1.5:5432      59s
rbd-citus-coord-replica   10.42.3.4:5432      31s
```

# 2.23

Polecenie SELECT na replice się powiodło, ale polecenie UPDATE zakończyło się błędem. Powodem jest to, że repliki są w stanie read-only. Wszelkie polecenia DML muszą być kierowane do głównej bazy danych.

# 2.29

Po wykryciu "awarii" głównej bazy danych koordynatora, operator Kubegres natychmiast to wykrył i wdrożył mechanizm failover, w ramach którego `rbd-citus-coord-2` stał się nową bazą podstawową. Zapytanie zakończyło się błędem oraz zamknięciem połączenia SSL, co wynika z tego że oryginalna replika przestała istnieć. Jednakże klient psql automatycznie wznowił połączenie, które to zostało zkierowane do nowo awansowanej instancji głownej.

# 2.30

Zapytanie wykonało się poprawnie i zwróciło oczekiwany wynik. Nowy koordynator główny posiada aktualne dane i metadane klastra, więc proces przełączenia awarynjego przebiegł bez utraty danych.

# 2.31

Adres zmienił się na 10.42.3.7. Jest to adres różny od tego jaki baza ta miała w momencie bycia repliką czuwającą (10.42.3.4). Wynika to z tego że po restarcie/awansie poda koordynatora do roli głównej repliki, dostała ona nowy adres IP w sieci klastra.

# 2.32

```sh
$ kubectl get endpoints
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME                        ENDPOINTS           AGE
kubernetes                  192.168.97.2:6443   9m
rbd-citus-coord             10.42.3.7:5432      7m18s
rbd-citus-coord-replica     10.42.1.9:5432      6m50s
```

Endpointy zmieniły się analogicznie jak adresy. Wynika to z tego że stara replika czuwająca otrzymała nowy adres IP, nowy adres dostała również nowa replika czuwająca.

# 2.33

```sh
$ kubectl get sts
NAME                  READY   AGE
rbd-citus-coord-2     1/1     13m
rbd-citus-coord-3     1/1     7m48s
```

Stary węzeł koordynacyjny `rbd-citus-coord-1` zniknął. Stara replika `rbd-citus-coord-2` przejęła rolę głównej, a dodatkowo Kubegres utworzył nową replikę `rbd-citus-coord-3` jako zapasowa.

# 2.34

W miejsce starej bazy czuwającej `rbd-citus-coord-3` została utworzona nowa `rbd-citus-coord-4`, jednakże nie ma to żadnego wpływu na działanie klastra, bowiem głowna baza nadal działa i przyjmuje ruch jak wcześniej.
