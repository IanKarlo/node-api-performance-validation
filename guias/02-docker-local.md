# Docker Local

## Pre-requisitos

- Docker
- Docker Compose

## Build da Imagem

```bash
docker build -t test/node-api-validation .
```

A imagem multi-stage compila automaticamente TypeScript, Rust e Zig dentro do container.

## Executar os Containers da API

```bash
# TypeScript (porta 3000)
docker run --rm -d \
  --name node-api-ts \
  -p 3000:3000 \
  -e LANG_MODEL=TS \
  -e NODE_ENV=production \
  test/node-api-validation

# Rust (porta 3002)
docker run --rm -d \
  --name node-api-rs \
  -p 3002:3000 \
  -e LANG_MODEL=RS \
  -e NODE_ENV=production \
  test/node-api-validation

# Zig (porta 3003)
docker run --rm -d \
  --name node-api-zg \
  -p 3003:3000 \
  -e LANG_MODEL=ZG \
  -e NODE_ENV=production \
  test/node-api-validation
```

## Parar os Containers

```bash
docker stop node-api-ts node-api-rs node-api-zg
```

## Monitoramento Local (Prometheus + Grafana)

O `docker-compose.yml` na raiz do projeto sobe Prometheus e Grafana para monitorar as APIs rodando localmente.

```bash
# Subir Prometheus + Grafana
docker compose up -d

# Verificar status
docker compose ps

# Ver logs
docker compose logs -f

# Parar
docker compose down
```

### Acessos

| Servico    | URL                    | Credenciais     |
|------------|------------------------|-----------------|
| Prometheus | http://localhost:9090   | -               |
| Grafana    | http://localhost:3001   | admin / admin   |

### Configuracao do Prometheus

O arquivo `prometheus.yml` na raiz esta configurado para coletar metricas das tres variantes da API rodando localmente:

- TypeScript: `localhost:3000`
- Rust: `localhost:3100`
- Zig: `localhost:3200`

> **Nota:** Para o Prometheus conseguir acessar as APIs rodando no host, e usado `host.docker.internal`. Se estiver rodando a API diretamente (sem Docker), funciona normalmente. Se a API tambem estiver em Docker, considere usar uma rede Docker compartilhada.
