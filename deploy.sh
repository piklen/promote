#!/bin/bash

# LLM提示词优化平台 - 智能部署脚本
# 支持自动环境检测、依赖安装和错误恢复

set -euo pipefail  # 严格错误处理

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# 全局变量
COMPOSE_FILE=""
MODE=""
BACKUP_DIR=""
LOG_FILE="./deploy.log"
DEPLOYMENT_START_TIME=""
ROLLBACK_AVAILABLE=false

# 日志函数
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${GREEN}ℹ️  ${message}${NC}"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  ${message}${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ ${message}${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✅ ${message}${NC}"
            ;;
        "STEP")
            echo -e "${BLUE}🔄 ${message}${NC}"
            ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# 错误处理函数
error_exit() {
    log "ERROR" "$1"
    echo -e "${RED}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                                 部署失败"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "日志文件: $LOG_FILE"
    echo "如需帮助，请访问: https://github.com/yourusername/promote/issues"
    echo -e "${NC}"
    
    if [[ "$ROLLBACK_AVAILABLE" == true && -n "$BACKUP_DIR" ]]; then
        echo -e "${YELLOW}是否要回滚到之前的状态？ (y/N)${NC}"
        read -r -n 1 -t 10 rollback_choice || rollback_choice="n"
        echo
        if [[ "$rollback_choice" =~ ^[Yy]$ ]]; then
            rollback_deployment
        fi
    fi
    
    exit 1
}

# 系统检查函数
check_system() {
    log "STEP" "正在检查系统环境..."
    
    # 检查操作系统
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log "WARN" "此脚本主要为Linux设计，在其他系统上可能需要调整"
    fi
    
    # 检查是否为root用户
    if [[ $EUID -eq 0 ]]; then
        log "WARN" "不建议以root用户运行此脚本"
    fi
    
    # 检查可用磁盘空间
    local available_space=$(df . | tail -1 | awk '{print $4}')
    local required_space=2000000  # 2GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        error_exit "磁盘空间不足，至少需要2GB可用空间"
    fi
    
    # 检查内存
    local total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local required_memory=1000000  # 1GB in KB
    
    if [[ $total_memory -lt $required_memory ]]; then
        log "WARN" "系统内存较少（<1GB），可能影响性能"
    fi
    
    log "SUCCESS" "系统环境检查完成"
}

# Docker环境检查和安装
setup_docker() {
    log "STEP" "检查Docker环境..."
    
    # 检查Docker是否安装
    if ! command -v docker &> /dev/null; then
        log "WARN" "未检测到Docker，正在自动安装..."
        
        if command -v apt-get &> /dev/null; then
            # Ubuntu/Debian
            curl -fsSL https://get.docker.com | sh
            sudo usermod -aG docker $USER
        elif command -v yum &> /dev/null; then
            # CentOS/RHEL
            curl -fsSL https://get.docker.com | sh
            sudo usermod -aG docker $USER
        else
            error_exit "无法自动安装Docker，请手动安装后重试"
        fi
        
        log "SUCCESS" "Docker安装完成"
    else
        log "INFO" "Docker已安装: $(docker --version)"
    fi
    
    # 检查Docker服务状态
    if ! systemctl is-active --quiet docker; then
        log "STEP" "启动Docker服务..."
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log "WARN" "未检测到Docker Compose，正在安装..."
        
        # 安装Docker Compose
        local compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
        sudo curl -L "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        log "SUCCESS" "Docker Compose安装完成"
    else
        if command -v docker-compose &> /dev/null; then
            log "INFO" "Docker Compose已安装: $(docker-compose --version)"
        else
            log "INFO" "Docker Compose已安装: $(docker compose version)"
        fi
    fi
}

# 选择部署模式
select_deployment_mode() {
    log "STEP" "选择部署模式..."
    
    echo -e "${CYAN}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                              部署模式选择"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1) 开发环境    - 适合开发和测试，包含热重载和调试功能"
    echo "2) 生产环境    - 适合生产部署，优化了性能和安全性"
    echo "3) 自动检测    - 根据系统环境自动选择合适的模式"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
    
    read -p "请输入选择 (1/2/3) [默认: 3]: " MODE
    MODE=${MODE:-3}
    
    case $MODE in
        1)
            COMPOSE_FILE="docker-compose.yml"
            log "INFO" "选择开发环境模式"
            ;;
        2)
            COMPOSE_FILE="docker-compose.prod.yml"
            log "INFO" "选择生产环境模式"
            ;;
        3)
            # 自动检测
            if [[ -f "/etc/systemd/system" ]] && [[ $(free -m | awk 'NR==2{print $2}') -gt 1000 ]]; then
                COMPOSE_FILE="docker-compose.prod.yml"
                log "INFO" "自动检测：选择生产环境模式"
            else
                COMPOSE_FILE="docker-compose.yml"
                log "INFO" "自动检测：选择开发环境模式"
            fi
            ;;
        *)
            error_exit "无效选择，请输入1、2或3"
            ;;
    esac
}

# 环境配置
setup_environment() {
    log "STEP" "配置环境..."
    
    if [[ "$COMPOSE_FILE" == "docker-compose.prod.yml" ]]; then
        # 生产环境配置
        local data_dir="/opt/prompt-optimizer"
        
        if [[ ! -d "$data_dir" ]]; then
            log "STEP" "创建生产环境数据目录..."
            sudo mkdir -p "$data_dir"/{data,logs,backups}
            sudo chown -R $(id -u):$(id -g) "$data_dir"
            log "SUCCESS" "数据目录创建完成: $data_dir"
        fi
        
        # 检查环境变量文件
        if [[ ! -f "backend/.env" ]]; then
            log "STEP" "创建生产环境配置文件..."
            cp backend/env.example backend/.env 2>/dev/null || true
            
            # 生成安全密钥
            if command -v openssl &> /dev/null; then
                sed -i "s/SECRET_KEY=.*/SECRET_KEY=$(openssl rand -hex 32)/" backend/.env
                sed -i "s/ENCRYPTION_MASTER_KEY=.*/ENCRYPTION_MASTER_KEY=$(openssl rand -hex 32)/" backend/.env
                log "SUCCESS" "安全密钥已自动生成"
            fi
        fi
    fi
}

# 创建备份
create_backup() {
    log "STEP" "创建部署前备份..."
    
    BACKUP_DIR="./backups/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # 备份数据（如果存在）
    if [[ -d "/opt/prompt-optimizer/data" ]] && [[ "$(ls -A /opt/prompt-optimizer/data 2>/dev/null)" ]]; then
        cp -r /opt/prompt-optimizer/data "$BACKUP_DIR/"
        log "SUCCESS" "数据备份完成"
        ROLLBACK_AVAILABLE=true
    fi
    
    # 备份配置文件
    if [[ -f "backend/.env" ]]; then
        cp backend/.env "$BACKUP_DIR/"
    fi
    
    if [[ -f "frontend/.env" ]]; then
        cp frontend/.env "$BACKUP_DIR/"
    fi
    
    log "SUCCESS" "备份创建完成: $BACKUP_DIR"
}

# 部署应用
deploy_application() {
    log "STEP" "部署应用..."
    
    # 停止现有服务
    log "INFO" "停止现有服务..."
    docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
    
    # 清理未使用的资源
    log "INFO" "清理Docker资源..."
    docker system prune -f >/dev/null 2>&1 || true
    
    # 构建和启动服务
    log "STEP" "构建和启动服务..."
    if ! docker-compose -f "$COMPOSE_FILE" up --build -d; then
        error_exit "服务启动失败"
    fi
    
    log "SUCCESS" "服务启动完成"
}

# 健康检查
health_check() {
    log "STEP" "执行健康检查..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log "INFO" "健康检查 ($attempt/$max_attempts)..."
        
        # 检查容器状态
        local backend_status=$(docker-compose -f "$COMPOSE_FILE" ps backend | grep -c "Up" || echo "0")
        local frontend_status=$(docker-compose -f "$COMPOSE_FILE" ps frontend | grep -c "Up" || echo "0")
        
        if [[ "$backend_status" == "1" && "$frontend_status" == "1" ]]; then
            # 检查API响应
            if curl -f -s http://localhost:8080/health >/dev/null; then
                log "SUCCESS" "健康检查通过"
                return 0
            fi
        fi
        
        sleep 5
        ((attempt++))
    done
    
    log "ERROR" "健康检查失败，显示服务日志："
    docker-compose -f "$COMPOSE_FILE" logs --tail=20
    error_exit "服务未能正常启动"
}

# 回滚函数
rollback_deployment() {
    log "STEP" "开始回滚部署..."
    
    if [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" ]]; then
        # 停止当前服务
        docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
        
        # 恢复数据
        if [[ -d "$BACKUP_DIR/data" ]]; then
            sudo rm -rf /opt/prompt-optimizer/data
            sudo cp -r "$BACKUP_DIR/data" /opt/prompt-optimizer/
            sudo chown -R $(id -u):$(id -g) /opt/prompt-optimizer/data
        fi
        
        # 恢复配置
        if [[ -f "$BACKUP_DIR/.env" ]]; then
            cp "$BACKUP_DIR/.env" backend/
        fi
        
        log "SUCCESS" "回滚完成"
    else
        log "ERROR" "无法回滚：备份不存在"
    fi
}

# 显示部署结果
show_deployment_info() {
    local deployment_time=$(($(date +%s) - $DEPLOYMENT_START_TIME))
    local local_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo -e "${GREEN}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                              🎉 部署成功！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
    
    echo -e "${CYAN}📍 访问地址：${NC}"
    echo "   🌐 前端界面: http://$local_ip"
    echo "   📚 API文档:  http://$local_ip:8080/docs"
    echo "   ❤️  健康检查: http://$local_ip/health"
    echo
    
    echo -e "${CYAN}🔧 管理命令：${NC}"
    echo "   查看状态: docker-compose -f $COMPOSE_FILE ps"
    echo "   查看日志: docker-compose -f $COMPOSE_FILE logs -f"
    echo "   重启服务: docker-compose -f $COMPOSE_FILE restart"
    echo "   停止服务: docker-compose -f $COMPOSE_FILE down"
    echo
    
    echo -e "${CYAN}📊 部署信息：${NC}"
    echo "   部署模式: $(basename $COMPOSE_FILE .yml)"
    echo "   部署耗时: ${deployment_time}秒"
    echo "   备份位置: $BACKUP_DIR"
    echo "   日志文件: $LOG_FILE"
    echo
    
    echo -e "${YELLOW}📚 下一步：${NC}"
    echo "   1. 访问前端界面开始使用"
    echo "   2. 在'API配置'页面添加LLM服务商配置"
    echo "   3. 查看文档了解更多功能: README.md"
    echo
    
    echo -e "${PURPLE}💡 需要帮助？${NC}"
    echo "   📖 文档: https://github.com/yourusername/promote"
    echo "   🐛 问题: https://github.com/yourusername/promote/issues"
    echo "   💬 讨论: https://github.com/yourusername/promote/discussions"
    echo
}

# 主函数
main() {
    DEPLOYMENT_START_TIME=$(date +%s)
    
    # 初始化日志
    echo "=== LLM提示词优化平台部署日志 ===" > "$LOG_FILE"
    echo "开始时间: $(date)" >> "$LOG_FILE"
    
    echo -e "${PURPLE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                    🚀 LLM提示词优化平台智能部署脚本"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
    
    # 执行部署步骤
    check_system
    setup_docker
    select_deployment_mode
    setup_environment
    create_backup
    deploy_application
    health_check
    show_deployment_info
    
    log "SUCCESS" "部署完成！总耗时: $(($(date +%s) - $DEPLOYMENT_START_TIME))秒"
}

# 捕获中断信号
trap 'error_exit "部署被用户中断"' INT TERM

# 运行主函数
main "$@" 