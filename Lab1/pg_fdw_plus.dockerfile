FROM postgres:17.6 AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git \
       build-essential \
       postgresql-server-dev-17 \
       ca-certificates \
       libkrb5-dev \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Pobieramy i kompilujemy pg_fdw_plus
RUN git clone https://github.com/pgfdwplus/postgres_fdw_plus.git /tmp/pg_fdw_plus \
    && cd /tmp/pg_fdw_plus \
    && make USE_PGXS=1 PG_CONFIG=/usr/lib/postgresql/17/bin/pg_config

# Etap 2: finalny obraz
FROM postgres:17.6

# Kopiujemy skompilowane pliki rozszerzenia z buildera
COPY --from=builder /tmp/pg_fdw_plus/*.so /usr/lib/postgresql/17/lib/
COPY --from=builder /tmp/pg_fdw_plus/*.control /usr/share/postgresql/17/extension/
COPY --from=builder /tmp/pg_fdw_plus/*.sql /usr/share/postgresql/17/extension/

