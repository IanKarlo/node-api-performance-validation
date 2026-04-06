# Guias de Execucao

Este diretorio contem guias separados por processo para executar todas as partes do projeto **node-api-performance-validation**.

## Indice

1. [Desenvolvimento Local](01-desenvolvimento-local.md) - Instalacao, build e execucao da API localmente
2. [Docker Local](02-docker-local.md) - Build e execucao da imagem Docker e monitoramento local (Prometheus + Grafana)
3. [Infraestrutura na Nuvem (Terraform)](03-infraestrutura-terraform.md) - Provisionamento do cluster Kubernetes na DigitalOcean
4. [Deploy no Kubernetes](04-deploy-kubernetes.md) - Deploy da aplicacao e stack de monitoramento no cluster
5. [Testes de Carga (k6)](05-testes-carga-k6.md) - Execucao dos experimentos de carga com k6 no cluster
6. [Exportacao de Metricas](06-exportacao-metricas.md) - Exportar dados do Prometheus do cluster para a maquina local
7. [Replay de Metricas](07-replay-metricas.md) - Replay local das metricas exportadas com Prometheus e Grafana
8. [Analise de Dados (ETL + PostgreSQL)](08-analise-dados.md) - Carga dos dados no PostgreSQL para analise
