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
`



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
Isso sobe os 5 serviços + RabbitMQ:
ServiçoPortaDescriçãoRabbitMQ5672 (AMQP), 15672 (UI)Message brokerfgc-users-api5038Cadastro e autenticaçãofgc-catalog-api5070CRUD de jogos e comprafgc-payments-api5050Processamento de pagamentofgc-notifications-api5060Notificações via logVerificar logsdocker-compose logs -fAcessar interfaces
Swagger Users API: http://localhost:5038/swagger
Swagger Catalog API: http://localhost:5070/swagger
Swagger Payments API: http://localhost:5050/swagger
RabbitMQ Management: http://localhost:15672 (admin/admin)
Parar tudodocker-compose down☸️ KubernetesPré-requisitos
Cluster Kubernetes local (Kind, Minikube, k3d ou Docker Desktop)
kubectl configurado
Estrutura dos manifestosCada repositório de microsserviço possui sua própria pasta /k8s com:
deployment.yaml — Deployment com probes de liveness/readiness
service.yaml — Service do tipo ClusterIP
configmap.yaml — Configurações não sensíveis
secret.yaml — Credenciais e dados sensíveis
Deploy no clusterPara cada serviço, execute na raiz do repositório correspondente:kubectl apply -f k8s/Ou, a partir deste repositório de orquestração, aponte para cada pasta:

kubectl apply -f ../fgc-users-api/k8s/
kubectl apply -f ../fgc-catalog-api/k8s/
kubectl apply -f ../fgc-payments-api/k8s/
kubectl apply -f ../fgc-notifications-api/k8s/

Verificar podskubectl get podsAcessar serviços no clusterOs serviços se comunicam internamente pelos nomes do Kubernetes:
http://fgc-users-api:80
http://fgc-catalog-api:80
http://fgc-payments-api:80
http://fgc-notifications-api:80
🔧 Variáveis de AmbienteRabbitMQ (comum a todos)
VariávelDescriçãoPadrãoRabbitMq__HostHost do RabbitMQrabbitmqMassTransit__HostHost do RabbitMQ (Notifications)rabbitmqMassTransit__UsernameUsuário RabbitMQadminMassTransit__PasswordSenha RabbitMQadmin✅ TestesCada microsserviço possui testes unitários e/ou de integração:
# Users API
cd fgc-users-api && dotnet test

# Catalog API
cd fgc-catalog-api && dotnet test

# Payments API
cd fgc-payments-api && dotnet test

# Notifications API
cd fgc-notifications-api && dotnet test
🎥 Demonstração[Link do vídeo de apresentação - 20 minutos]📄 Relatório de Entrega
Grupo: Squad 8 – Turma 12NETT
Participantes: Ronnam de Lima da Silva, Yan Santos Wendt
Repositórios: Links na seção acima
Vídeo: Link acima

