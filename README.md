# 🎮 FCG - FIAP Cloud Games

Plataforma de games educacionais desenvolvida como **Tech Challenge da Fase 2** da pós-graduação **Arquitetura de Sistemas .NET – FIAP**.

Arquitetura de **microsserviços orientada a eventos**, com comunicação assíncrona via **RabbitMQ** e **MassTransit**.

---

## 👥 Squad 8 – Turma 12NETT

| Integrante | GitHub |
|---|---|
| Ronnam de Lima da Silva | [@ronnam](https://github.com/ronnam) |
| Yan Santos Wendt | |

---

## 🏗️ Arquitetura
```text
┌────────────────┐     UserCreatedEvent      ┌──────────────────┐
│  Users API     │ ───────────────────────►  │  Notifications   │
│  (port 5038)   │                           │  API (port 5060) │
└───────┬────────┘                           └──────────────────┘
        │
        │ JWT Auth
        ▼
┌────────────────┐     OrderPlacedEvent      ┌──────────────────┐
│  Catalog API   │ ───────────────────────►  │  Payments API    │
│  (port 5070)   │                           │  (port 5050)     │
└───────┬────────┘                           └─────────┬────────┘
        │                                              │
        │        PaymentProcessedEvent  ◄──────────────┘
        │        (Approved/Rejected)
        ▼
┌────────────────┐     PaymentProcessedEvent  ┌──────────────────┐
│   Catalog      │ ◄───────────────────────── │  Notifications   │
│  (add lib)     │                            │  (e-mail compra) │
└────────────────┘                            └──────────────────┘
```

### Fluxos

**1. Cadastro de Usuário**
- Users API cadastra → publica `UserCreatedEvent`
- Notifications API consome → loga e-mail de boas-vindas

**2. Compra de Jogo**
- Catalog API recebe requisição → publica `OrderPlacedEvent`
- Payments API consome → processa pagamento → publica `PaymentProcessedEvent`
- Catalog API consome → se `Approved`, adiciona jogo à biblioteca
- Notifications API consome → se `Approved`, loga e-mail de confirmação

---

## 📦 Repositórios

| Microsserviço | Repositório | Tecnologias |
|---|---|---|
| **Users API** | [fgc-users-api](https://github.com/ronnam/fgc-users-api) | .NET 8, EF Core, SQLite, JWT, MassTransit |
| **Catalog API** | [fgc-catalog-api](https://github.com/ronnam/fgc-catalog-api) | .NET 8, EF Core, SQLite, JWT, MassTransit |
| **Payments API** | [fgc-payments-api](https://github.com/ronnam/fgc-payments-api) | .NET 8, MassTransit |
| **Notifications API** | [fgc-notifications-api](https://github.com/ronnam/fgc-notifications-api) | .NET 8, MassTransit |
| **Message Contracts** | [fgc-message-contracts](https://github.com/ronnam/fgc-message-contracts) | Pacote NuGet local de eventos |
| **Orquestração** | *(este repositório)* | Docker Compose, Kubernetes |

---

## 🐳 Execução com Docker

### Pré-requisitos
- [Docker](https://docs.docker.com/engine/install/)
- [Docker Compose](https://docs.docker.com/compose/install/)

### Subir todos os serviços
```bash
docker-compose up -d --build
```
Isso sobe os 5 serviços + RabbitMQ:

| Serviço | Porta | Descrição |
|---|---|---|
| RabbitMQ | 5672 (AMQP), 15672 (UI) | Message broker |
| fgc-users-api | 5038 | Cadastro e autenticação |
| fgc-catalog-api | 5070 | CRUD de jogos e compra |
| fgc-payments-api | 5050 | Processamento de pagamento |
| fgc-notifications-api | 5060 | Notificações via log |

Verificar logs: `docker-compose logs -f`

Acessar interfaces:
- Swagger Users API: http://localhost:5038/swagger
- Swagger Catalog API: http://localhost:5070/swagger
- Swagger Payments API: http://localhost:5050/swagger
- RabbitMQ Management: http://localhost:15672 (admin/admin)

Parar tudo: `docker-compose down`

---

## ☸️ Kubernetes

### Pré-requisitos
- Cluster Kubernetes local (Kind, Minikube, k3d ou Docker Desktop)
- kubectl configurado
- Os 4 repositórios de serviço (`fgc-users-api`, `fgc-catalog-api`, `fgc-payments-api`, `fgc-notifications-api`) clonados como pastas irmãs de `fgc-orchestration` (mesmo layout usado pelo `docker-compose.yml`)

### Estrutura dos manifestos

Este repositório consolida em `k8s/` cópias dos manifests de cada serviço (a fonte de cada um continua também em `fgc-<serviço>-api/k8s/`, para quem quiser aplicar um serviço isolado), agrupados em um único arquivo por tipo de recurso — todos no namespace `fgc`:

- `00-namespace.yaml` — cria o namespace `fgc`
- `deployment.yaml` — os 5 Deployments (RabbitMQ + as 4 APIs), cada um com suas probes de liveness/readiness
- `service.yaml` — os 10 Services: um `ClusterIP` (comunicação interna entre pods) e um `NodePort` (acesso externo, similar às portas do `docker-compose.yml`) para cada um dos 5 acima
- `configmap.yaml` — as 4 ConfigMaps das APIs, com as configurações não sensíveis (RabbitMQ não tem ConfigMap própria, usa `env:` direto no Deployment)
- `secret.yaml` — as 4 Secrets das APIs, com credenciais e dados sensíveis (placeholders de projeto acadêmico)

### Build e carga das imagens

Como o projeto ainda não tem pipeline de CI/CD nem publica imagens em um registry (ver seção de testes), as imagens precisam ser buildadas localmente e disponibilizadas ao cluster:

```powershell
cd fgc-orchestration
.\k8s\build-and-load-images.ps1
```

O script builda as 4 imagens (`fgc-<serviço>-api:latest`) a partir dos repositórios irmãos e, se detectar um cluster **kind** ou **minikube**, carrega as imagens automaticamente (`kind load docker-image` / `minikube image load`). No Kubernetes do **Docker Desktop** nenhuma ação extra é necessária, pois ele compartilha o cache local do Docker.

### Deploy no cluster

```bash
kubectl apply -f k8s/
kubectl get pods -n fgc
```

Alternativa, sem o namespace consolidado — aplicar cada serviço isoladamente a partir do seu próprio repositório:
```bash
kubectl apply -f ../fgc-users-api/k8s/
kubectl apply -f ../fgc-catalog-api/k8s/
kubectl apply -f ../fgc-payments-api/k8s/
kubectl apply -f ../fgc-notifications-api/k8s/
```

### Acessar serviços no cluster

Internamente, os serviços se comunicam pelos nomes do Kubernetes:
- http://fgc-users-api:80
- http://fgc-catalog-api:80
- http://fgc-payments-api:80
- http://fgc-notifications-api:80

Externamente, via os Services `NodePort`:

| Serviço | NodePort | URL |
|---|---|---|
| fgc-users-api | 30038 | http://localhost:30038/swagger |
| fgc-catalog-api | 30070 | http://localhost:30070/swagger |
| fgc-payments-api | 30050 | http://localhost:30050/swagger |
| fgc-notifications-api | 30060 | http://localhost:30060/health |
| RabbitMQ Management | 30672 | http://localhost:30672 (admin/admin) |

> Em kind/Docker Desktop o NodePort costuma responder direto em `localhost`. No minikube, use `minikube service <nome-do-service> -n fgc --url` ou `minikube tunnel` para obter a URL correta.

---

## 🔧 Variáveis de Ambiente

RabbitMQ (comum a todos):

| Variável | Descrição | Padrão |
|---|---|---|
| RabbitMq__Host | Host do RabbitMQ | rabbitmq |
| MassTransit__Host | Host do RabbitMQ (Notifications) | rabbitmq |
| MassTransit__Username | Usuário RabbitMQ | admin |
| MassTransit__Password | Senha RabbitMQ | admin |

---

## ✅ Testes

Cada microsserviço possui testes unitários e/ou de integração:
```bash
# Users API
cd fgc-users-api && dotnet test

# Catalog API
cd fgc-catalog-api && dotnet test

# Payments API
cd fgc-payments-api && dotnet test

# Notifications API
cd fgc-notifications-api && dotnet test
```

## 🎥 Demonstração
[https://youtu.be/eiJI9z8NcI4]

## 📄 Relatório de Entrega
Grupo: Squad 8 – Turma 12NETT
Participantes: Ronnam de Lima da Silva, Yan Santos Wendt
Repositórios: Links na seção acima
Vídeo: Link acima
