<#
Builda as 4 imagens Docker dos microsservicos FCG e, se o contexto kubectl atual
for kind ou minikube, carrega as imagens no cluster (nao ha registry/CI-CD neste
projeto, entao as imagens tem que chegar aos nos do cluster por fora de um pull).

Rodar a partir de qualquer diretorio; o script resolve os caminhos dos repos
irmaos relativos a sua propria localizacao (fgc-orchestration/k8s/../../fgc-<servico>-api).
#>

$ErrorActionPreference = "Stop"

$services = @(
    "fgc-users-api",
    "fgc-catalog-api",
    "fgc-payments-api",
    "fgc-notifications-api"
)

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

foreach ($service in $services) {
    $context = Join-Path $root $service
    if (-not (Test-Path (Join-Path $context "Dockerfile"))) {
        throw "Dockerfile nao encontrado em $context - confirme que os repos irmaos estao clonados ao lado de fgc-orchestration."
    }
    Write-Host "==> Building ${service}:latest" -ForegroundColor Cyan
    docker build -f (Join-Path $context "Dockerfile") -t "${service}:latest" $context
}

$currentContext = (kubectl config current-context 2>$null)

if ($currentContext -match "^kind-") {
    $clusterName = $currentContext -replace "^kind-", ""
    Write-Host "==> Contexto kind detectado ($clusterName) - carregando imagens no cluster" -ForegroundColor Cyan
    foreach ($service in $services) {
        kind load docker-image "${service}:latest" --name $clusterName
    }
}
elseif ($currentContext -eq "minikube") {
    Write-Host "==> Contexto minikube detectado - carregando imagens no cluster" -ForegroundColor Cyan
    foreach ($service in $services) {
        minikube image load "${service}:latest"
    }
}
else {
    Write-Host "==> Contexto '$currentContext' nao e kind nem minikube." -ForegroundColor Yellow
    Write-Host "    Se for o Kubernetes do Docker Desktop, nenhuma acao extra e necessaria: ele compartilha o cache local do Docker." -ForegroundColor Yellow
    Write-Host "    Para outros clusters (k3d, cluster remoto, etc.), publique as imagens em um registry acessivel pelos nos e ajuste a tag/image nos deployments." -ForegroundColor Yellow
}

Write-Host "==> Imagens prontas. Proximo passo: kubectl apply -f k8s/" -ForegroundColor Green
