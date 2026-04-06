# Analise de Dados (ETL + PostgreSQL)

Script ETL que carrega dados de time-series do Prometheus e resultados dos experimentos k6 em um PostgreSQL local para analise com SQL.

## Pre-requisitos

- Docker e Docker Compose
- Python 3 com pip
- Dados exportados e replay rodando (ver guias [06](06-exportacao-metricas.md) e [07](07-replay-metricas.md))
- Resultados de experimentos k6 em `docs/k6-experiments/`

## Passo 1: Subir o PostgreSQL

```bash
docker compose -f analysis/docker-compose.yml up -d
```

Isso sobe um PostgreSQL na porta **5433** com:
- Usuario: `perf`
- Senha: `perf`
- Banco: `perf_analysis`

O schema (`analysis/schema.sql`) e aplicado automaticamente na primeira inicializacao.

## Passo 2: Subir o Replay do Prometheus

```bash
./replay/run-replay.sh up
```

O Prometheus de replay roda em http://localhost:9092.

## Passo 3: Instalar Dependencias Python

```bash
pip install -r analysis/requirements.txt
```

Dependencias: `psycopg2-binary` e `requests`.

## Passo 4: Executar o ETL

```bash
# Carregar todos os batches de experimentos
python analysis/load_to_postgres.py

# Carregar um batch especifico
python analysis/load_to_postgres.py --batch 20260308-144054

# Com opcoes customizadas
python analysis/load_to_postgres.py \
  --prom-url http://localhost:9092 \
  --pg-dsn "postgresql://perf:perf@localhost:5433/perf_analysis" \
  --experiments-dir docs/k6-experiments \
  --step 15

# Resetar tabelas e recarregar tudo
python analysis/load_to_postgres.py --reset
```

## Opcoes do Script

| Flag                | Padrao                                            | Descricao                              |
|---------------------|---------------------------------------------------|----------------------------------------|
| `--prom-url`        | `http://localhost:9092`                           | URL do Prometheus (replay)             |
| `--pg-dsn`          | `postgresql://perf:perf@localhost:5433/perf_analysis` | DSN do PostgreSQL                  |
| `--experiments-dir` | `docs/k6-experiments`                             | Diretorio dos resultados k6            |
| `--batch`           | (todos)                                           | Batch especifico para carregar         |
| `--step`            | `15`                                              | Resolucao em segundos das queries      |
| `--reset`           | `false`                                           | Recriar tabelas antes de carregar      |

## Acessar o PostgreSQL

```bash
# Via psql
psql "postgresql://perf:perf@localhost:5433/perf_analysis"

# Ou via Docker
docker exec -it perf-analysis-pg psql -U perf -d perf_analysis
```

## Parar o PostgreSQL

```bash
docker compose -f analysis/docker-compose.yml down
```

Para remover os dados persistidos tambem:

```bash
docker compose -f analysis/docker-compose.yml down -v
```
