# Testes de Carga (k6)

Executa experimentos de carga com k6 contra as APIs no cluster Kubernetes. Cada combinacao (cenario x endpoint) roda como um Job k6, com as variantes (TS, RS, ZG) executando em paralelo dentro do mesmo job.

## Pre-requisitos

- `kubectl` configurado e apontando para o cluster
- APIs e Prometheus deployados no cluster (ver [Deploy Kubernetes](04-deploy-kubernetes.md))

## Execucao Completa

```bash
./k8s/run-k6-experiments.sh
```

Por padrao, executa todos os cenarios, variantes e endpoints com 3 repeticoes.

## Variaveis de Configuracao

| Variavel                  | Padrao                                                                    | Descricao                                    |
|---------------------------|---------------------------------------------------------------------------|----------------------------------------------|
| `SCENARIOS`               | `pico,rampa,resistencia`                                                  | Cenarios de carga                            |
| `VARIANTS`                | `ts,rs,zg`                                                                | Variantes da API                             |
| `ENDPOINTS`               | `risk_report_small,risk_report_medium,risk_report_big,batch_score,analytics_summary` | Endpoints a testar                |
| `REPETITIONS`             | `3`                                                                       | Repeticoes por combinacao (3 a 5)            |
| `NAMESPACE`               | `node-api-perf`                                                           | Namespace Kubernetes                         |
| `RESTART_DEPLOYMENTS`     | `true`                                                                    | Reiniciar pods antes de cada execucao        |
| `TIMEOUT_SECONDS`         | `7200`                                                                    | Timeout por job (em segundos)                |
| `CONTINUE_ON_JOB_FAILURE` | `true`                                                                    | Continuar mesmo se um job falhar             |
| `IGNORE_THRESHOLD_FAILURE`| `true`                                                                    | Ignorar falha de thresholds do k6            |

## Exemplos

```bash
# Apenas cenario rampa, Rust, endpoint batch_score
SCENARIOS=rampa VARIANTS=rs ENDPOINTS=batch_score ./k8s/run-k6-experiments.sh

# Todas as variantes em paralelo para batch_score, cenario rampa
SCENARIOS=rampa VARIANTS=ts,rs,zg ENDPOINTS=batch_score ./k8s/run-k6-experiments.sh

# Com 5 repeticoes
REPETITIONS=5 SCENARIOS=rampa VARIANTS=ts,rs,zg ENDPOINTS=batch_score ./k8s/run-k6-experiments.sh

# Sem reiniciar os deployments entre execucoes
RESTART_DEPLOYMENTS=false SCENARIOS=pico ./k8s/run-k6-experiments.sh
```

## Cenarios de Carga

| Cenario       | Tipo            | Descricao                                            |
|---------------|-----------------|------------------------------------------------------|
| `pico`        | ramping-vus     | Sobe rapido para 40 VUs, mantem 2min, desce          |
| `rampa`       | ramping-vus     | Escada gradual: 10 -> 20 -> 30 -> 40 VUs, 1min cada |
| `resistencia` | constant-vus    | 20 VUs constantes por 12 minutos                     |

## Endpoints Disponiveis

| ID                    | Rota                              | Metodo | Carga        |
|-----------------------|-----------------------------------|--------|--------------|
| `risk_report_small`   | `/risk/report`                    | POST   | Pequena      |
| `risk_report_medium`  | `/risk/report`                    | POST   | Media        |
| `risk_report_big`     | `/risk/report`                    | POST   | Grande       |
| `batch_score`         | `/risk/batch-score`               | POST   | 10k perfis   |
| `analytics_summary`   | `/analytics/customer/:id/summary` | GET    | -            |

## Artefatos de Saida

Cada execucao salva em `docs/k6-experiments/<timestamp>/`:

- `*.log` - Log completo do k6
- `*.summary.json` - Resumo estruturado do k6
- `*.pods.json` - Estado dos pods (antes/depois, restarts, eventos)
- `*.meta.json` - Metadados da execucao

## Executar k6 Localmente (fora do cluster)

Se quiser rodar k6 direto na sua maquina (sem Kubernetes):

```bash
# Instalar k6: https://k6.io/docs/getting-started/installation/

# Executar contra APIs locais
k6 run k6/load-test.js

# Com variaveis customizadas
k6 run \
  -e LOAD_SCENARIO=rampa \
  -e TEST_VARIANTS=ts \
  -e TEST_ENDPOINTS=batch_score \
  k6/load-test.js
```
