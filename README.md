# Validação de Performance de API Node

API de Análise de Risco e Simulação para validação de performance e benchmarking com implementações em TypeScript e Rust.

## Visão Geral

Esta API fornece mecanismos de análise de risco e simulação para clientes e veículos, projetada para suportar cargas de trabalho intensivas em CPU e memória. Ela serve como base para implementações comparativas, com versões em TypeScript (Node.js) e Rust disponíveis para benchmarking.

## Funcionalidades

- **Consolidação de Histórico:** Consolida o histórico de eventos para um par cliente/veículo.
- **Derivação de Características:** Deriva vetores de características a partir de dados históricos.
- **Pontuação de Risco:** Calcula pontuações de risco usando um modelo linear.
- **Simulação de Monte Carlo:** Simula cenários futuros para estimar a probabilidade de perda e o valor esperado.
- **Análise (Analytics):** Gera resumos analíticos do histórico do cliente.
- **Processamento em Lote:** Calcula pontuações de risco para grandes lotes de perfis.

## Instalação

```bash
npm install
```

## Build (Compilação)

```bash
# Compilar ambas as implementações TypeScript e Rust
npm run build

# Compilar apenas o módulo nativo Rust
npm run native:build
```

## Execução

```bash
# Modo de desenvolvimento (com ts-node)
npm run dev

# Desenvolvimento com a implementação TypeScript (padrão)
npm run dev:ts

# Desenvolvimento com a implementação Rust
npm run dev:rs

# Modo de produção (após a compilação)
npm start
```

### Seleção do Modelo de Linguagem

A API suporta implementações tanto em TypeScript quanto em Rust para comparação de performance. Use a variável de ambiente `LANG_MODEL` para escolher:

- `LANG_MODEL=TS` (padrão): Usa as implementações TypeScript.
- `LANG_MODEL=RS`: Usa as implementações Rust (requer o módulo nativo compilado).

```bash
# Configurar variável de ambiente e executar
LANG_MODEL=RS npm run dev

# Ou use os scripts de conveniência
npm run dev:rs  # Usar Rust
npm run dev:ts  # Usar TypeScript (explícito)
```

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

O sistema segue uma arquitetura modular com implementações tanto em TypeScript quanto em Rust:

- **Camada HTTP** (`src/routes/`): Rotas Express.js e tratamento de requisições.
- **Camada de Computação** (`src/computation/`): Lógica de negócio central (geração de histórico, derivação de características, pontuação, simulação).
- **Camada Nativa** (`src/native/rust/`): Implementações Rust de alta performance usando napi-rs.
- **Serviços** (`src/services/`): Camada de acesso a dados (atualmente implementações simuladas/mocks).
- **Tipos** (`src/types/`): Definições de tipo TypeScript.

O design modular permite a alternância contínua entre as implementações TypeScript e Rust para benchmarking de performance.

## Características de Performance

- **Intensivo em Memória:** Operações de geração e agregação de histórico.
- **Intensivo em CPU:** Operações de simulação Monte Carlo e pontuação em lote.
- **Escalável:** Projetado para lidar com grandes cargas de trabalho (até 1M eventos, 10M iterações de simulação).