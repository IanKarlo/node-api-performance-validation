# Infraestrutura na Nuvem (Terraform)

Provisiona um cluster Kubernetes gerenciado (DOKS) na DigitalOcean usando Terraform.

## Pre-requisitos

- Terraform instalado
- Conta na DigitalOcean com um API token

## Configuracao

```bash
cd infra

# Copiar arquivo de variaveis
cp terraform.tfvars.example terraform.tfvars
```

Edite `terraform.tfvars` conforme necessario:

```hcl
region              = "nyc1"
cluster_name        = "node-api-perf-cluster"
kubernetes_version  = ""   # vazio = usa a versao mais recente disponivel
node_size           = "s-2vcpu-4gb"
node_count          = 2
```

Configure o token da DigitalOcean (recomendado via variavel de ambiente):

```bash
export TF_VAR_do_token="dop_v1_seu_token_aqui"
```

## Comandos

```bash
cd infra

# Inicializar Terraform
terraform init

# Verificar o plano de execucao
terraform plan

# Aplicar (criar o cluster)
terraform apply

# Destruir o cluster (quando nao precisar mais)
terraform destroy
```

## Configurar kubectl

Apos a criacao do cluster, configure o `kubectl` para apontar para ele:

```bash
# Via doctl (CLI da DigitalOcean)
doctl kubernetes cluster kubeconfig save node-api-perf-cluster

# Ou exporte manualmente
export KUBECONFIG=~/.kube/node-api-perf.yaml
```

## Outputs

Apos o `terraform apply`, os seguintes outputs estarao disponiveis:

```bash
terraform output
```

Outputs incluem informacoes do cluster como ID, endpoint e versao do Kubernetes.
