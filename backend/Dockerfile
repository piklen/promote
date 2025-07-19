# 多阶段构建优化
FROM python:3.11-slim as builder

# 设置构建参数
ARG BUILDPLATFORM
ARG TARGETPLATFORM

# 安装构建依赖
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libffi-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# 创建虚拟环境
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 升级pip和安装wheel
RUN pip install --no-cache-dir --upgrade pip wheel

# 复制requirements文件
COPY requirements.txt .

# 安装Python依赖到虚拟环境
RUN pip install --no-cache-dir -r requirements.txt

# 生产阶段
FROM python:3.11-slim as production

# 创建非root用户
RUN groupadd -r appuser && useradd -r -g appuser appuser

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 复制虚拟环境
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 设置工作目录
WORKDIR /app

# 复制应用代码（使用.dockerignore优化）
COPY --chown=appuser:appuser . .

# 创建数据目录并设置权限
RUN mkdir -p /app/data && chown -R appuser:appuser /app/data

# 设置环境变量
ENV PYTHONPATH=/app
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DATABASE_URL=sqlite:///./data/prompt_optimizer.db

# 暴露端口
EXPOSE 8080

# 健康检查优化
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# 切换到非root用户
USER appuser

# 启动命令优化
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1"] 