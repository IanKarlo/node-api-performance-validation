# Exportacao de Metricas do Prometheus

Exporta os dados do Prometheus (TSDB) do cluster Kubernetes para a maquina local, permitindo replay posterior.

## Pre-requisitos

- `kubectl` configurado e apontando para o cluster
- Prometheus rodando no cluster (namespace `node-api-perf`)

## Executar

```bash
./k8s/export-prometheus.sh
```

## O que o Script Faz

1. Encontra o pod do Prometheus no cluster
2. Cria um snapshot do TSDB (ou faz copia direta se a API de snapshot nao estiver disponivel)
3. Copia os dados para `exports/prometheus/<timestamp>/`
4. Salva metadados (pod de origem, ConfigMap do Prometheus, manifesto do deployment)

## Variaveis

| Variavel          | Padrao                     | Descricao                     |
|-------------------|----------------------------|-------------------------------|
| `NAMESPACE`       | `node-api-perf`            | Namespace do Prometheus       |
| `EXPORT_BASE_DIR` | `exports/prometheus`       | Diretorio base de exportacao  |

## Estrutura de Saida

```
exports/prometheus/<timestamp>/
  tsdb-data/                        # Dados TSDB do Prometheus
  source-pod.txt                    # Nome do pod de origem
  export-timestamp.txt              # Timestamp da exportacao
  prometheus-configmap.yaml         # ConfigMap do Prometheus
  prometheus-deployment.yaml        # Manifest do deployment
```

## Proximo Passo

Apos exportar, use o replay local para visualizar os dados:

```bash
./replay/run-replay.sh up exports/prometheus/<timestamp>/tsdb-data
```

Ou simplesmente (usa a exportacao mais recente automaticamente):

```bash
./replay/run-replay.sh up
```
