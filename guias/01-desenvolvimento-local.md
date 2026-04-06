# Desenvolvimento Local

## Pre-requisitos

- Node.js 20+
- Yarn 4.9.1 (ativado via corepack)
- Rust toolchain (para o modulo nativo Rust)
- Zig 0.15.1 (para o modulo nativo Zig)

## Instalacao

```bash
# Ativar corepack (se ainda nao ativado)
corepack enable

# Instalar dependencias
yarn install
```

## Build

```bash
# Build completo (TypeScript + Rust + Zig)
yarn build

# Apenas modulos nativos
yarn native:build

# Apenas Rust
yarn build:rust

# Apenas Zig
yarn build:zig
```

## Configuracao

Copie o arquivo `.env.example` para `.env` e ajuste conforme necessario:

```bash
cp .env.example .env
```

Variaveis principais:

| Variavel     | Descricao                                       | Padrao        |
|--------------|------------------------------------------------|---------------|
| `LANG_MODEL` | Implementacao a usar: `TS`, `RS` ou `ZG`       | `TS`          |
| `PORT`       | Porta do servidor                               | `3000`        |
| `NODE_ENV`   | Ambiente (`development` ou `production`)        | `development` |

## Execucao em Modo de Desenvolvimento

```bash
# TypeScript (porta 3000)
yarn dev:ts

# Rust (porta 3100)
yarn dev:rs

# Zig (porta 3200)
yarn dev:zg

# Ou escolher manualmente
LANG_MODEL=RS PORT=3100 yarn dev
```

## Execucao em Modo de Producao

```bash
# Compilar primeiro
yarn build

# Executar
yarn start
```

## Testando a API

```bash
# Risk report
curl -X POST http://localhost:3000/risk/report \
  -H "Content-Type: application/json" \
  -d '{"customerId":"cust-001","vehicleId":"veh-001","historySize":500,"simulationIterations":1000,"seed":42}'

# Batch score
curl -X POST http://localhost:3000/risk/batch-score \
  -H "Content-Type: application/json" \
  -d '{"count":10000,"seed":42}'

# Analytics summary
curl http://localhost:3000/analytics/customer/cust-001/summary

# Metricas Prometheus
curl http://localhost:3000/metrics
```
