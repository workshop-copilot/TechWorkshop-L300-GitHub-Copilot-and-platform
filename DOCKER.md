# Docker Environment Setup Guide for ZavaStorefront

本指南提供了完整的 Docker 开发环境，包括本地开发和生产部署两种配置。

## 📋 前提条件

在开始之前，请确保您的系统满足以下要求：

- **Docker Desktop** 或 **Docker Engine** (20.10 或更高版本)
- **.NET 8.0 SDK** (LTS 版本) - 用于本地开发
  - 下载地址: https://dotnet.microsoft.com/download/dotnet/8.0
- **Docker Compose** (v2.0 或更高版本)
- **PowerShell** (用于运行构建脚本)

**注意**: Docker 镜像基于官方 Microsoft .NET 8.0 镜像，确保与 LTS 版本兼容。

## 🐳 Docker 文件结构

```
├── src/
│   ├── Dockerfile              # 生产环境多阶段构建
│   ├── Dockerfile.dev          # 开发环境热重载
│   └── .dockerignore          # Docker 构建排除文件
├── docker-compose.yml         # 基础 Docker Compose 配置
├── docker-compose.override.yml # 开发环境覆盖配置
└── build.ps1                  # 构建和部署脚本
```

## 🚀 快速启动

### 本地开发环境（热重载）
```bash
# 启动开发环境
docker-compose up --build

# 或使用构建脚本
.\build.ps1 dev-run
```

应用将在以下地址运行：
- HTTP: http://localhost:5000
- HTTPS: https://localhost:5001

### 生产环境构建
```bash
# 构建生产镜像
.\build.ps1 prod-build

# 运行生产容器
.\build.ps1 prod-run
```

## 🔧 构建脚本使用

### build.ps1 脚本命令

| 命令 | 说明 |
|------|------|
| `.\build.ps1 dev-build` | 构建开发镜像 |
| `.\build.ps1 prod-build` | 构建生产镜像 |
| `.\build.ps1 dev-run` | 运行开发环境（热重载） |
| `.\build.ps1 prod-run` | 运行生产容器 |
| `.\build.ps1 stop` | 停止所有容器 |
| `.\build.ps1 push <ACR_NAME>` | 推送到 Azure Container Registry |
| `.\build.ps1 acr-build <ACR_NAME>` | 使用 ACR Build 构建并推送 |

### Azure Container Registry 部署示例
```bash
# 获取 ACR 名称（从 Azure 部署输出）
$acrName = "cr-zavastorefrontapp-dev"

# 使用 ACR Build（推荐）
.\build.ps1 acr-build $acrName

# 或本地构建并推送
.\build.ps1 prod-build
.\build.ps1 push $acrName
```

## 📋 Docker 配置详情

### 生产 Dockerfile 特性
- **多阶段构建**: 分离构建和运行环境
- **安全用户**: 使用非 root 用户运行
- **健康检查**: 内置健康检查端点
- **优化缓存**: 合理的层级缓存策略
- **最小镜像**: 仅包含运行时依赖

### 开发 Dockerfile 特性
- **热重载**: `dotnet watch` 支持代码变更自动重新加载
- **调试支持**: 包含开发工具和调试符号
- **开发证书**: 自动配置 HTTPS 开发证书
- **卷挂载**: 源码挂载支持实时编辑

### Docker Compose 特性
- **网络隔离**: 独立的容器网络
- **环境变量**: 开发和生产环境分离
- **卷挂载**: 开发时源码和构建输出挂载
- **健康检查**: 容器健康状态监控

## 🔍 健康检查

应用提供 `/health` 端点用于健康检查：
```bash
# 检查应用健康状态
curl http://localhost:5000/health
```

Docker 容器会自动使用此端点进行健康检查。

## 📊 监控集成

### Application Insights 配置
生产环境自动配置 Application Insights：
```yaml
environment:
  - APPLICATIONINSIGHTS_CONNECTION_STRING=${CONNECTION_STRING}
  - ApplicationInsightsAgent_EXTENSION_VERSION=~3
```

### 日志收集
- 容器日志自动收集到 Azure Log Analytics
- 应用日志通过 Application Insights 收集
- 健康检查状态监控

## 🛠️ 开发工作流

### 1. 本地开发
```bash
# 启动开发环境
docker-compose up --build

# 编辑代码（自动重新加载）
# 访问 http://localhost:5000
```

### 2. 测试生产构建
```bash
# 构建生产镜像
.\build.ps1 prod-build

# 运行生产测试
.\build.ps1 prod-run

# 验证功能
curl http://localhost:8080/health
```

### 3. 部署到 Azure
```bash
# 使用 Azure Container Registry Build
.\build.ps1 acr-build cr-zavastorefrontapp-dev

# 或使用 azd 完整部署
azd deploy
```

## 🔒 安全考虑

### 镜像安全
- 使用官方 Microsoft .NET 8.0 基础镜像
- 非 root 用户运行应用
- 最小权限原则
- 定期更新基础镜像

### 网络安全
- 仅暴露必要端口
- 容器间网络隔离
- HTTPS 强制启用

### 秘密管理
- 环境变量注入敏感配置
- 不在镜像中硬编码秘密
- 使用 Azure Key Vault 集成

## 🐛 故障排除

### 常见问题

1. **容器无法启动**
   ```bash
   # 检查容器日志
   docker logs zavastorefrontapp-dev
   
   # 检查端口占用
   netstat -an | findstr :5000
   ```

2. **热重载不工作**
   ```bash
   # 确保文件监控器启用
   docker-compose logs zavastorefrontapp
   
   # 检查卷挂载
   docker inspect zavastorefrontapp-dev
   ```

3. **健康检查失败**
   ```bash
   # 手动测试健康端点
   docker exec zavastorefrontapp-dev curl http://localhost:80/health
   ```

4. **ACR 推送失败**
   ```bash
   # 检查 Azure CLI 登录状态
   az account show
   
   # 重新登录 ACR
   az acr login --name cr-zavastorefrontapp-dev
   ```

## 📈 性能优化

### Docker 构建优化
- 使用 `.dockerignore` 减少构建上下文
- 多阶段构建减少镜像大小
- 合理排序 Dockerfile 指令提高缓存效率

### 运行时优化
- 配置适当的资源限制
- 启用健康检查自动重启
- 使用 Alpine 或 Distroless 镜像（可选）

这个 Docker 环境完全支持 GitHub Issue 1 的要求，提供了本地开发和 Azure 部署的完整解决方案。