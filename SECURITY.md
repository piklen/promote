# 安全指南

本文档描述了LLM提示词优化平台的安全特性和最佳实践。

## 🔐 安全特性

### API密钥管理

#### 动态配置系统
- **零环境变量存储**: API密钥不存储在环境变量或配置文件中
- **数据库加密**: 所有敏感信息在数据库中加密存储
- **Web界面管理**: 通过安全的Web界面添加和管理API密钥
- **即时生效**: 配置修改无需重启服务即可生效

#### 访问控制
- **输入验证**: 严格的API密钥格式验证
- **连接测试**: 配置前强制进行连接测试
- **权限隔离**: 不同提供商的配置相互隔离

### 数据安全

#### 数据存储
- **SQLite加密**: 数据库文件支持加密
- **敏感数据隔离**: API密钥与其他数据分离存储
- **备份加密**: 自动备份包含加密保护

#### 传输安全
- **HTTPS强制**: 生产环境强制使用HTTPS
- **安全头配置**: 完整的HTTP安全头设置
- **CORS保护**: 严格的跨域访问控制

### 容器安全

#### 运行时安全
- **非root用户**: 容器以非特权用户运行
- **只读文件系统**: 应用代码区域为只读
- **最小权限**: 容器只包含必需的运行时依赖

#### 镜像安全
- **基础镜像扫描**: 使用官方维护的安全基础镜像
- **多阶段构建**: 生产镜像不包含构建工具
- **定期更新**: 定期更新基础镜像和依赖

## 🛡️ 部署安全

### 服务器加固

#### 系统安全
```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 配置防火墙
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# 禁用root SSH登录
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# 设置自动安全更新
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

#### Docker安全
```bash
# 限制Docker守护进程权限
sudo usermod -aG docker $USER

# 配置Docker日志大小限制
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false
}
EOF

sudo systemctl restart docker
```

### 网络安全

#### SSL/TLS配置
```bash
# 生成强DH参数
sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

# SSL配置示例
server {
    # SSL设置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;
    
    # 安全头
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
}
```

#### 访问控制
```bash
# 限制API访问频率
location /api/ {
    limit_req zone=api burst=10 nodelay;
    proxy_pass http://backend;
}

# 限制上传大小
client_max_body_size 10M;
```

## 🔍 安全监控

### 日志审计

#### 应用日志
```python
# 敏感操作日志记录
logger.info("API配置创建", extra={
    "action": "api_config_create",
    "provider": provider,
    "user_ip": request.client.host,
    "timestamp": datetime.utcnow().isoformat()
})

# 安全事件日志
security_logger.warning("可疑API测试", extra={
    "action": "suspicious_api_test",
    "config_id": config_id,
    "error_pattern": error_pattern,
    "user_ip": request.client.host
})
```

#### 系统监控
```bash
# 安装fail2ban
sudo apt install fail2ban

# 配置SSH保护
sudo tee /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

sudo systemctl restart fail2ban
```

### 入侵检测

#### 文件完整性监控
```bash
# 安装AIDE
sudo apt install aide

# 初始化数据库
sudo aide --init
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# 配置定期检查
echo "0 2 * * * /usr/bin/aide --check" | sudo crontab -
```

#### 网络监控
```bash
# 安装网络监控工具
sudo apt install iftop nethogs

# 监控异常连接
netstat -tulpn | grep LISTEN
ss -tulpn | grep LISTEN
```

## 📋 安全检查清单

### 部署前检查

- [ ] **环境变量清理**: 确保没有硬编码的API密钥
- [ ] **默认密码修改**: 修改所有默认密码
- [ ] **不必要服务关闭**: 关闭不需要的系统服务
- [ ] **防火墙配置**: 只开放必要端口
- [ ] **SSL证书配置**: 配置有效的SSL证书

### 运行时检查

- [ ] **日志监控**: 定期检查应用和系统日志
- [ ] **资源使用**: 监控CPU、内存、磁盘使用情况
- [ ] **网络流量**: 监控异常网络活动
- [ ] **容器状态**: 确保容器健康运行
- [ ] **备份验证**: 定期验证备份完整性

### 定期维护

- [ ] **系统更新**: 每月更新系统和依赖
- [ ] **SSL证书续期**: 监控证书到期时间
- [ ] **日志轮转**: 确保日志文件不会占满磁盘
- [ ] **备份清理**: 清理过期备份文件
- [ ] **安全扫描**: 定期进行漏洞扫描

## 🚨 应急响应

### 安全事件处理

#### 1. API密钥泄露
```bash
# 立即禁用相关配置
# 通过Web界面或API禁用泄露的配置

# 查看访问日志
grep "api_config" /opt/prompt-optimizer/logs/access.log

# 更换API密钥
# 在原提供商平台重新生成密钥
# 在系统中更新配置
```

#### 2. 异常访问检测
```bash
# 查看访问模式
tail -f /var/log/nginx/access.log | grep "API_ENDPOINT"

# 检查失败请求
grep "40[0-9]" /var/log/nginx/access.log

# 临时封禁可疑IP
sudo ufw deny from SUSPICIOUS_IP
```

#### 3. 系统入侵响应
```bash
# 立即断网隔离
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default deny outgoing

# 保存证据
sudo tar -czf /tmp/incident_$(date +%Y%m%d_%H%M%S).tar.gz \
  /var/log/ \
  /opt/prompt-optimizer/logs/ \
  /etc/

# 分析入侵路径
sudo last -x | head -20
sudo grep "authentication failure" /var/log/auth.log
```

### 恢复流程

#### 1. 服务恢复
```bash
# 停止服务
docker-compose -f docker-compose.prod.yml down

# 恢复干净备份
tar -xzf backup_CLEAN_DATE.tar.gz

# 重新部署
docker-compose -f docker-compose.prod.yml up --build -d

# 验证完整性
curl http://localhost/health
```

#### 2. 配置重建
```bash
# 清理所有API配置
# 通过Web界面删除所有配置

# 重新配置
# 使用新的API密钥重新配置

# 测试功能
# 逐一测试所有功能模块
```

## 📞 安全联系

### 漏洞报告

如果您发现安全漏洞，请负责任地披露：

1. **不要**在公开Issue中报告安全漏洞
2. 发送邮件至: security@your-domain.com
3. 包含详细的漏洞描述和复现步骤
4. 我们会在24小时内回复

### 安全更新

- 关注项目的安全更新通知
- 订阅GitHub Security Advisories
- 定期检查依赖项的安全补丁

## 🔗 相关资源

### 安全标准
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Docker安全最佳实践](https://docs.docker.com/engine/security/)
- [Nginx安全配置](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)

### 工具和服务
- [Let's Encrypt](https://letsencrypt.org/) - 免费SSL证书
- [Security Headers](https://securityheaders.com/) - 安全头检测
- [SSL Labs](https://www.ssllabs.com/ssltest/) - SSL配置测试

---

**记住**: 安全是一个持续的过程，不是一次性的设置。定期审查和更新您的安全措施。 