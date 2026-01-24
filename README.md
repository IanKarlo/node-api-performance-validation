# Validação de Performance da API Node

API de Análise de Risco e Simulação para validação de performance e benchmarking.

## Visão Geral

Esta API fornece um mecanismo de análise de risco e simulação para clientes e veículos, projetado para suportar cargas de trabalho intensivas em CPU e memória. Serve como linha de base para implementações comparativas (Node.js Puro vs. Node.js + Rust/Zig).

## Funcionalidades

- **Consolidação de Histórico:** Consolidar histórico de eventos para um cliente/veículo
- **Derivação de Características:** Derivar vetores de características do histórico
- **Cálculo de Pontuação:** Calcular pontuações de risco usando um modelo linear
- **Simulação Monte Carlo:** Simular cenários futuros para estimar probabilidade de perda e valor esperado

## Instalação

```bash
npm install
```

## Compilar

```bash
npm run build
```

## Executar

```bash
# Modo desenvolvimento (com ts-node)
npm run dev

# Modo desenvolvimento com implementação TypeScript (padrão)
npm run dev:ts

# Modo desenvolvimento com implementação Rust
npm run dev:rs

# Modo produção (após compilação)
npm start
```

### Seleção de Modelo de Linguagem

A API suporta tanto implementações em TypeScript quanto Rust para comparação de performance. Use a variável de ambiente `LANG_MODEL` para escolher:

- `LANG_MODEL=TS` (padrão): Usar implementações TypeScript
- `LANG_MODEL=RS`: Usar implementações Rust (requer módulo nativo compilado)

```bash
# Definir variável de ambiente e executar
LANG_MODEL=RS npm run dev

# Ou usar os scripts de conveniência
npm run dev:rs  # Usa Rust
npm run dev:ts  # Usa TypeScript (explícito)
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

**Nota:** Atualmente apenas implementação TypeScript disponível.

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

O sistema segue uma arquitetura modular:

- **Camada HTTP** (`src/routes/`): Rotas Express.js e tratamento de requisições
- **Camada de Computação** (`src/computation/`): Lógica de negócio principal (geração de histórico, derivação de características, pontuação, simulação)
- **Serviços** (`src/services/`): Camada de acesso a dados (atualmente implementações mock)
- **Tipos** (`src/types/`): Definições de tipos TypeScript

Esta separação permite que os módulos de computação sejam facilmente substituídos por módulos nativos Rust/Zig em futuras iterações.

## Características de Performance

- **Intensivo em Memória:** Operações de geração e agregação de histórico
- **Intensivo em CPU:** Operações de simulação Monte Carlo e pontuação em lote
- **Escalável:** Projetado para lidar com grandes cargas de trabalho (até 1M eventos, 10M iterações de simulação)
