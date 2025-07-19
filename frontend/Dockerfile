# 多阶段构建优化

# 依赖阶段 - 缓存node_modules
FROM node:18-alpine as deps
WORKDIR /app

# 安装依赖管理工具
RUN apk add --no-cache libc6-compat

# 复制package文件
COPY package*.json ./

# 安装依赖
RUN npm ci --only=production && npm cache clean --force

# 开发阶段
FROM node:18-alpine as development
WORKDIR /app

# 复制依赖
COPY --from=deps /app/node_modules ./node_modules

# 安装开发依赖
COPY package*.json ./
RUN npm ci

# 复制源代码
COPY . .

# 暴露开发服务器端口
EXPOSE 5173

# 开发环境启动命令
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]

# 构建阶段
FROM node:18-alpine as build
WORKDIR /app

# 复制依赖
COPY --from=deps /app/node_modules ./node_modules

# 安装所有依赖（包括开发依赖）
COPY package*.json ./
RUN npm ci

# 复制源代码
COPY . .

# 设置构建环境变量
ENV NODE_ENV=production

# 构建应用
RUN npm run build

# 生产阶段
FROM nginx:1.25-alpine as production

# 安装运行时依赖
RUN apk add --no-cache \
    curl \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# 复制自定义nginx配置
COPY nginx.conf /etc/nginx/nginx.conf

# 复制构建的应用
COPY --from=build /app/dist /usr/share/nginx/html

# 创建健康检查端点
RUN echo '{"status": "ok", "service": "frontend", "timestamp": "'$(date -Iseconds)'"}' > /usr/share/nginx/html/health

# 创建nginx运行目录并设置权限
RUN mkdir -p /var/cache/nginx/client_temp && \
    mkdir -p /var/cache/nginx/proxy_temp && \
    mkdir -p /var/cache/nginx/fastcgi_temp && \
    mkdir -p /var/cache/nginx/uwsgi_temp && \
    mkdir -p /var/cache/nginx/scgi_temp && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown nginx:nginx /var/run/nginx.pid

# 暴露端口
EXPOSE 80

# 健康检查优化
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

# 切换到非root用户
USER nginx

# 启动nginx
CMD ["nginx", "-g", "daemon off;"] 