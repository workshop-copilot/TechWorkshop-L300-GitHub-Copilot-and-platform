# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy solution and project files first (better cache utilization)
COPY ZavaStorefront.sln .
COPY ZavaStorefront.csproj .

# Restore dependencies
RUN dotnet restore ZavaStorefront.csproj

# Copy source code
COPY . .

# Build and publish in one layer
RUN dotnet publish ZavaStorefront.csproj -c Release -o /app/publish --no-restore

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN adduser --disabled-password --gecos '' --shell /bin/bash --home /home/appuser appuser

# Set working directory and copy app
WORKDIR /app
COPY --from=build /app/publish .
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port 80 (App Service uses port 80)
EXPOSE 80

# Set environment variables
ENV ASPNETCORE_URLS=http://+:80 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

# Start the application
ENTRYPOINT ["dotnet", "ZavaStorefront.dll"]