# 🎮 FCG - FIAP Cloud Games
Plataforma de games educacionais desenvolvida como **Tech Challenge da Fase 3** da pós-graduação **Arquitetura de Sistemas .NET – FIAP**.
Arquitetura de **microsserviços orientada a eventos**, com **API Gateway**, **Serverless**, **Observabilidade**, **Persistência Poliglota** e **Cache Distribuído**.

## 👤 Projeto Individual – Turma 12NETT
| Integrante | GitHub |
|---|---|
| Ronnam de Lima da Silva | [@ronnam](https://github.com/ronnam) |

## 🏗️ Arquitetura
```text
┌──────────────────────────────────────────────────┐
│                  USUÁRIO / CLIENTE               │
└──────────────────────┬───────────────────────────┘
                       │ HTTP
                       ▼
┌──────────────────────────────────────────────────┐
│              API Gateway Kong                    │
│        (porta única de entrada + JWT)            │
└──────────┬───────────────────────┬───────────────┘
           │                       │
           ▼                       ▼
┌──────────────────┐      ┌──────────────────┐
│    Users API     │      │   Catalog API    │
│   (port 5038)    │      │   (port 5070)    │
└───────┬──────────┘      └────────┬─────────┘
        │                         │
        │      ┌──────────────────┘
        │      ▼
┌──────────────────────────────────────────────────┐
│        RABBITMQ (Message Broker)                 │
│  UserCreated / OrderPlaced / PaymentProcessed    │
└──────┬───────────────────────────────┬───────────┘
       │                               │
       ▼                               ▼
┌──────────────────┐      ┌──────────────────────────────┐
│   Payments API   │      │         Azure Cloud          │
│   (port 5050)    │      │  ┌──────────────────────┐    │
└──────────────────┘      │  │ Serverless Function  │    │
                          │  │   (ex-Notifications) │    │
                          │  └──────────────────────┘    │
                          └──────────────────────────────┘
```

### Fluxos
**1. Cadastro de Usuário**
- Usuário → API Gateway Kong (valida JWT) → Users API → cadastra → publica UserCreatedEvent
- Serverless Function (Azure) consome → loga e-mail de boas-vindas

**2. Compra de Jogo**
- Usuário → API Gateway Kong → Catalog API → publica OrderPlacedEvent
- Payments API consome → processa pagamento → publica PaymentProcessedEvent
- Catalog API consome → se Approved, adiciona jogo à biblioteca (Persistência em MongoDB/SQLite)
- Serverless Function consome → se Approved, loga e-mail de confirmação

## 📦 Repositórios
| Microsserviço | Repositório | Tecnologias |
|---|---|---|
| **Users API** | [fgc-users-api](https://github.com/ronnam/fgc-users-api) | .NET 8, EF Core, SQLite, JWT, MassTransit, Prometheus |
| **Catalog API** | [fgc-catalog-api](https://github.com/ronnam/fgc-catalog-api) | .NET 8, EF Core, SQLite, MongoDB, Redis, MassTransit, Prometheus |
| **Payments API** | [fgc-payments-api](https://github.com/ronnam/fgc-payments-api) | .NET 8, MassTransit, SQLite |
| **Serverless Function** | [REPOSITÓRIO A CRIAR] — ex: https://github.com/ronnam/fgc-serverless-function | Azure Functions, .NET 8, MassTransit |
| **Message Contracts** | [fgc-message-contracts](https://github.com/ronnam/fgc-message-contracts) | Pacote NuGet local de eventos |
| **Orquestração** | *(este repositório)* | Docker Compose, Kubernetes, Kong, Prometheus, Grafana |

## 🐳 Execução com Docker
### Pré-requisitos
- Docker
- Docker Compose

### Subir todos os serviços
```bash
docker compose up -d --build
```
Isso sobe os serviços:
| Serviço | Porta | Descrição |
|---|---|---|
| RabbitMQ | 5672 (AMQP), 15672 (UI) | Message broker |
| Kong | 8000 (HTTP), 8001 (Admin) | API Gateway |
| fgc-users-api | 5038 | Cadastro e autenticação |
| fgc-catalog-api | 5070 | CRUD de jogos e compra |
| fgc-payments-api | 5050 | Processamento de pagamento |
| Prometheus | 9090 | Coleta de métricas |
| Grafana | 3000 | Dashboards de observabilidade |
| MongoDB | 27017 | Banco NoSQL (catálogo expandido) |
| Redis | 6379 | Cache distribuído |

Verificar logs: `docker compose logs -f`

Acessar interfaces:
- Kong Gateway: http://localhost:8000
- Kong Admin API: http://localhost:8001
- Swagger Users API: http://localhost:5038/swagger
- Swagger Catalog API: http://localhost:5070/swagger
- Swagger Payments API: http://localhost:5050/swagger
- RabbitMQ Management: http://localhost:15672 (admin/admin)
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)

Parar tudo: `docker compose down`

## ☸️ Kubernetes
### Pré-requisitos
- Cluster Kubernetes local (Kind, Minikube, k3d ou Docker Desktop)
- kubectl configurado
- Os repositórios de serviço (fgc-users-api, fgc-catalog-api, fgc-payments-api) clonados como pastas irmãs de fgc-orchestration (mesmo layout usado pelo docker-compose.yml)

### Estrutura dos manifestos
Este repositório consolida em `k8s/` os manifestos de todos os componentes, incluindo **Kong**, **Prometheus** e **Grafana**, agrupados no namespace `fgc`:
- `00-namespace.yaml` — cria o namespace fgc
- `deployment.yaml` — Deployments de todos os serviços
- `service.yaml` — Services ClusterIP e NodePort
- `configmap.yaml` — ConfigMaps com configurações não sensíveis
- `secret.yaml` — Secrets com credenciais e dados sensíveis
- `kong/` — Manifestos do Kong API Gateway (deployment, service, config)
- `monitoring/` — Manifestos do Prometheus e Grafana

### Build e carga das imagens
```powershell
cd fgc-orchestration
.\k8s\build-and-load-images.ps1
```
O script builda as imagens fgc-<serviço>-api:latest a partir dos repositórios irmãos e, se detectar um cluster **kind** ou **minikube**, carrega as imagens automaticamente (`kind load docker-image` / `minikube image load`). No Kubernetes do **Docker Desktop** nenhuma ação extra é necessária, pois ele compartilha o cache local do Docker.

### Deploy no cluster
```bash
kubectl apply -f k8s/
kubectl get pods -n fgc
```

### Acessar serviços no cluster
Internamente, os serviços se comunicam pelos nomes do Kubernetes:
- http://fgc-users-api:80
- http://fgc-catalog-api:80
- http://fgc-payments-api:80
- http://kong-proxy:80 (via Gateway)

Externamente, via Services NodePort:
| Serviço | NodePort | URL |
|---|---|---|
| Kong Proxy | 30080 | http://localhost:30080 |
| fgc-users-api | 30038 | http://localhost:30038/swagger |
| fgc-catalog-api | 30070 | http://localhost:30070/swagger |
| fgc-payments-api | 30050 | http://localhost:30050/swagger |
| Prometheus | 39090 | http://localhost:39090 |
| Grafana | 33000 | http://localhost:33000 (admin/admin) |
| RabbitMQ Management | 30672 | http://localhost:30672 (admin/admin) |

> Em kind/Docker Desktop o NodePort costuma responder direto em localhost. No minikube, use `minikube service <nome-do-service> -n fgc --url` ou `minikube tunnel` para obter a URL correta.

## 📊 Observabilidade
Stack escolhida: **Prometheus + Grafana** (Opção A — código aberto)
- Users API e Catalog API instrumentadas com métricas Prometheus
- Grafana com dashboard customizado para visualizar em tempo real:
  - Latência de requisições
  - Contagem de requisições (total e por status code HTTP)
  - Taxa de erros (HTTP 4xx/5xx)
  - Saúde geral dos serviços

## 🔧 Variáveis de Ambiente
RabbitMQ (comum a todos):
| Variável | Descrição | Padrão |
|---|---|---|
| RabbitMq__Host | Host do RabbitMQ | rabbitmq |
| MassTransit__Username | Usuário RabbitMQ | admin |
| MassTransit__Password | Senha RabbitMQ | admin |

MongoDB:
| Variável | Descrição | Padrão |
|---|---|---|
| MongoDb__ConnectionString | String de conexão | mongodb://localhost:27017 |
| MongoDb__DatabaseName | Nome do banco | fgc-catalog |

Redis:
| Variável | Descrição | Padrão |
|---|---|---|
| Redis__ConnectionString | String de conexão | localhost:6379 |

## ✅ Testes
```bash
# Users API
cd fgc-users-api && dotnet test
# Catalog API
cd fgc-catalog-api && dotnet test
# Payments API
cd fgc-payments-api && dotnet test
# Serverless Function
cd fgc-serverless-function && dotnet test
```

## 🎥 Demonstração
https://youtu.be/wBkjgqAAfH4

## 📄 Relatório de Entrega
Projeto: Individual – Turma 12NETT
Integrante: Ronnam de Lima da Silva
Usernames no Discord: [A PREENCHER]
Data: 15 de setembro de 2026
Repositórios: Links na seção acima
Vídeo: [LINK DO VÍDEO DA FASE 3 A INSERIR]
