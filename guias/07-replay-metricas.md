# Replay de Metricas

Sobe Prometheus e Grafana localmente, carregando dados TSDB previamente exportados do cluster. Permite visualizar dashboards e fazer queries sobre os dados dos experimentos sem precisar do cluster.

## Pre-requisitos

- Docker e Docker Compose
- Dados exportados (ver [Exportacao de Metricas](06-exportacao-metricas.md))

## Comandos

```bash
# Subir (usa a exportacao mais recente automaticamente)
./replay/run-replay.sh up

# Subir com uma exportacao especifica
./replay/run-replay.sh up exports/prometheus/<timestamp>/tsdb-data

# Parar
./replay/run-replay.sh down

# Reiniciar (com nova exportacao, por exemplo)
./replay/run-replay.sh restart

# Ver status
./replay/run-replay.sh status

# Ver logs
./replay/run-replay.sh logs
```

## Acessos

| Servico    | URL                    | Credenciais   |
|------------|------------------------|---------------|
| Prometheus | http://localhost:9092   | -             |
| Grafana    | http://localhost:3002   | admin / admin |

> **Nota:** As portas sao diferentes do monitoramento local (9090/3001) para evitar conflito caso ambos estejam rodando.

## Dashboard do Grafana

O arquivo `docs/grafana-dashboard.json` contem o dashboard pre-configurado. Para importar:

1. Acesse o Grafana em http://localhost:3002
2. Va em Dashboards > Import
3. Cole o conteudo de `docs/grafana-dashboard.json`
