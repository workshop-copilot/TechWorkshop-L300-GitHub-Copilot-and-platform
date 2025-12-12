# Build scripts for Docker environments
# Provides convenient commands for building and running the application

# Variables
$AppName = "zavastorefrontapp"
$Version = "latest"
$Registry = "cr-zavastorefrontapp-dev.azurecr.io"  # Will be replaced with actual ACR name

# Functions
function Build-DevImage {
    Write-Host "Building development Docker image..." -ForegroundColor Green
    docker build -f src/Dockerfile.dev -t "$AppName`:dev" ./src
}

function Build-ProdImage {
    Write-Host "Building production Docker image..." -ForegroundColor Green  
    docker build -f src/Dockerfile -t "$AppName`:$Version" ./src
}

function Run-DevContainer {
    Write-Host "Starting development container with hot reload..." -ForegroundColor Green
    docker-compose -f docker-compose.yml -f docker-compose.override.yml up --build
}

function Run-ProdContainer {
    Write-Host "Starting production container..." -ForegroundColor Green
    docker run -d -p 8080:80 --name "$AppName-prod" "$AppName`:$Version"
}

function Stop-Containers {
    Write-Host "Stopping all containers..." -ForegroundColor Yellow
    docker-compose down
    docker stop "$AppName-prod" -ErrorAction SilentlyContinue
    docker rm "$AppName-prod" -ErrorAction SilentlyContinue
}

function Push-ToACR {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ACRName
    )
    
    Write-Host "Pushing to Azure Container Registry: $ACRName" -ForegroundColor Green
    
    # Tag image for ACR
    docker tag "$AppName`:$Version" "$ACRName.azurecr.io/$AppName`:$Version"
    
    # Login to ACR (assumes Azure CLI is configured)
    az acr login --name $ACRName
    
    # Push image
    docker push "$ACRName.azurecr.io/$AppName`:$Version"
}

function Build-AndPushToACR {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ACRName
    )
    
    Write-Host "Building and pushing to ACR: $ACRName" -ForegroundColor Green
    
    # Use ACR Build for consistency with Azure deployment
    az acr build --registry $ACRName --image "$AppName`:$Version" ./src
}

# Main execution based on parameters
switch ($args[0]) {
    "dev-build" { Build-DevImage }
    "prod-build" { Build-ProdImage }
    "dev-run" { Run-DevContainer }
    "prod-run" { Run-ProdContainer }
    "stop" { Stop-Containers }
    "push" { 
        if ($args[1]) { 
            Push-ToACR -ACRName $args[1] 
        } else { 
            Write-Host "Usage: .\build.ps1 push <ACR_NAME>" -ForegroundColor Red 
        }
    }
    "acr-build" { 
        if ($args[1]) { 
            Build-AndPushToACR -ACRName $args[1] 
        } else { 
            Write-Host "Usage: .\build.ps1 acr-build <ACR_NAME>" -ForegroundColor Red 
        }
    }
    default {
        Write-Host @"
ZavaStorefront Docker Build Script

Usage:
  .\build.ps1 dev-build       - Build development image
  .\build.ps1 prod-build      - Build production image
  .\build.ps1 dev-run         - Run development environment with hot reload
  .\build.ps1 prod-run        - Run production container
  .\build.ps1 stop            - Stop all containers
  .\build.ps1 push <ACR_NAME> - Push image to Azure Container Registry
  .\build.ps1 acr-build <ACR_NAME> - Build and push using ACR Build

Examples:
  .\build.ps1 dev-run
  .\build.ps1 acr-build cr-zavastorefrontapp-dev
"@ -ForegroundColor Cyan
    }
}