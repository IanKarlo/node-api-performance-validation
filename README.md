# Validação de Performance de API Node

API de Análise de Risco e Simulação para validação de performance e benchmarking com implementações em TypeScript, Rust e Zig.

## Visão Geral

Esta API fornece mecanismos de análise de risco e simulação para clientes e veículos, projetada para suportar cargas de trabalho intensivas em CPU e memória. Ela serve como base para implementações comparativas, com versões em TypeScript (Node.js) e Rust disponíveis para benchmarking.

## Funcionalidades

- **Consolidação de Histórico:** Consolida o histórico de eventos para um par cliente/veículo.
- **Derivação de Características:** Deriva vetores de características a partir de dados históricos.
- **Pontuação de Risco:** Calcula pontuações de risco usando um modelo linear.
- **Simulação de Monte Carlo:** Simula cenários futuros para estimar a probabilidade de perda e o valor esperado.
- **Análise (Analytics):** Gera resumos analíticos do histórico do cliente.
- **Processamento em Lote:** Calcula pontuações de risco para grandes lotes de perfis.

## Quick Start

```bash
# Instalar dependências
yarn install

# Build completo (TypeScript + Rust + Zig)
yarn build

# Executar em modo de desenvolvimento
yarn dev:ts   # TypeScript (porta 3000)
yarn dev:rs   # Rust (porta 3100)
yarn dev:zg   # Zig (porta 3200)
```

Use a variável de ambiente `LANG_MODEL` para escolher a implementação: `TS` (padrão), `RS` ou `ZG`.

## Endpoints da API

### POST /risk/report

Gera um relatório completo de risco para um par cliente/veículo.

**Requisição:**
```json
{
  "customerId": "customer-123",
  "vehicleId": "vehicle-456",
  "historySize": 100000,
  "simulationIterations": 1000000,
  "seed": 12345
}
```

**Resposta:**
```json
{
  "customerId": "customer-123",
  "vehicleId": "vehicle-456",
  "features": {
    "severeFines": 5,
    "mediumFines": 12,
    "totalKm": 45000,
    "latePayments": 3,
    "customerAge": 35,
    "vehicleAge": 5,
    "accidents": 1,
    "maintenanceCount": 8,
    "heavyUseCount": 25
  },
  "score": 0.65,
  "simulation": {
    "lossProbability": 0.19,
    "expectedLoss": 1250.50,
    "confidenceInterval95": [0, 8500]
  }
}
```

### POST /risk/batch-score

Calcula pontuações de risco para um lote de perfis.

**Requisição:**
```json
{
  "count": 10000,
  "seed": 12345
}
```

**Resposta:**
```json
{
  "totalProcessed": 10000,
  "statistics": {
    "meanScore": 0.52,
    "stdDev": 0.15,
    "min": 0.12,
    "max": 0.89
  }
}
```

### GET /analytics/customer/:id/summary

Retorna um resumo analítico do histórico do cliente.

**Disponível em ambas as implementações:** TypeScript e Rust.

**Resposta:**
```json
{
  "customerId": "customer-123",
  "summary": {
    "totalEvents": 50000,
    "eventsByCategory": {
      "FINE": 1200,
      "LATE_PAYMENT": 350,
      "ACCIDENT": 5,
      "MAINTENANCE": 800,
      "HEAVY_USE": 47645
    },
    "temporalAggregation": {
      "lastMonth": 4200,
      "lastQuarter": 12500,
      "lastYear": 50000
    },
    "averageTimeBetweenEventsDays": 0.007
  }
}
```

## Arquitetura

O sistema segue uma arquitetura modular com implementações em TypeScript, Rust e Zig:

- **Camada HTTP** (`src/routes/`): Rotas Express.js e tratamento de requisições.
- **Camada de Computação** (`src/computation/`): Lógica de negócio central (geração de histórico, derivação de características, pontuação, simulação).
- **Camada Nativa Rust** (`src/native/rust/`): Implementações Rust de alta performance usando napi-rs.
- **Camada Nativa Zig** (`src/native/zig/`): Implementações Zig de alta performance usando Node-API.
- **Serviços** (`src/services/`): Camada de acesso a dados (atualmente implementações simuladas/mocks).
- **Tipos** (`src/types/`): Definições de tipo TypeScript.

O design modular permite a alternância contínua entre as implementações TypeScript, Rust e Zig para benchmarking de performance.

## Características de Performance

- **Intensivo em Memória:** Operações de geração e agregação de histórico.
- **Intensivo em CPU:** Operações de simulação Monte Carlo e pontuação em lote.
- **Escalável:** Projetado para lidar com grandes cargas de trabalho (até 1M eventos, 10M iterações de simulação).

## Guias de Execução

Guias detalhados para cada etapa do projeto estão disponíveis em [`guias/`](guias/):

1. [Desenvolvimento Local](guias/01-desenvolvimento-local.md)
2. [Docker Local](guias/02-docker-local.md)
3. [Infraestrutura Terraform (DigitalOcean)](guias/03-infraestrutura-terraform.md)
4. [Deploy no Kubernetes](guias/04-deploy-kubernetes.md)
5. [Testes de Carga (k6)](guias/05-testes-carga-k6.md)
6. [Exportação de Métricas](guias/06-exportacao-metricas.md)
7. [Replay de Métricas](guias/07-replay-metricas.md)
8. [Análise de Dados (ETL + PostgreSQL)](guias/08-analise-dados.md)

## Dataset

O dump PostgreSQL com os resultados completos dos experimentos está versionado em [`analysis/dump/perf_analysis.dump`](analysis/dump/perf_analysis.dump). Consulte [`analysis/DATASET.md`](analysis/DATASET.md) para a descrição do schema e instruções de restauração.
