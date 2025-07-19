#!/bin/bash

# LLM提示词优化平台 - 简化部署脚本
# 支持开发和生产环境的一键部署

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log() {
    local level=$1
    shift
    case $level in
        "INFO") echo -e "${BLUE}ℹ️  $*${NC}" ;;
        "WARN") echo -e "${YELLOW}⚠️  $*${NC}" ;;
        "ERROR") echo -e "${RED}❌ $*${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ $*${NC}" ;;
    esac
}

# 错误处理
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# 检查依赖
check_dependencies() {
    log "INFO" "检查系统依赖..."
    
    if ! command -v docker &> /dev/null; then
        error_exit "Docker未安装，请先安装Docker"
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error_exit "Docker Compose未安装，请先安装Docker Compose"
    fi
    
    log "SUCCESS" "依赖检查完成"
}

# 选择部署模式
select_mode() {
    echo -e "${BLUE}请选择部署模式：${NC}"
    echo "1) 开发环境 (development)"
    echo "2) 生产环境 (production)"
    read -p "请输入选择 (1/2) [默认: 1]: " choice
    choice=${choice:-1}
    
    case $choice in
        1)
            COMPOSE_FILE="docker-compose.yml"
            log "INFO" "选择开发环境模式"
            ;;
        2)
            COMPOSE_FILE="docker-compose.prod.yml"
            log "INFO" "选择生产环境模式"
            setup_production_env
            ;;
        *)
            error_exit "无效选择"
            ;;
    esac
}

# 生产环境设置
setup_production_env() {
    log "INFO" "配置生产环境..."
    
    # 创建数据目录
    sudo mkdir -p /opt/prompt-optimizer/{data,logs}
    sudo chown -R $(id -u):$(id -g) /opt/prompt-optimizer/
    
    # 创建环境配置文件
    if [[ ! -f "backend/.env" ]]; then
        cp backend/env.example backend/.env 2>/dev/null || true
        log "INFO" "请编辑 backend/.env 配置文件"
    fi
}

# 部署应用
deploy() {
    log "INFO" "开始部署..."
    
    # 停止现有服务
    docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
    
    # 构建并启动服务
    if ! docker-compose -f "$COMPOSE_FILE" up --build -d; then
        error_exit "服务启动失败"
    fi
    
    log "SUCCESS" "服务启动完成"
}

# 健康检查
health_check() {
    log "INFO" "执行健康检查..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f -s http://localhost:8080/health >/dev/null 2>&1; then
            log "SUCCESS" "健康检查通过"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    log "ERROR" "健康检查失败"
    docker-compose -f "$COMPOSE_FILE" logs --tail=20
    error_exit "服务未能正常启动"
}

# 显示部署信息
show_info() {
    local local_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo -e "${GREEN}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                              🎉 部署成功！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
    
    echo -e "${BLUE}📍 访问地址：${NC}"
    echo "   🌐 前端界面: http://$local_ip"
    echo "   📚 API文档:  http://$local_ip:8080/docs"
    echo "   ❤️  健康检查: http://$local_ip:8080/health"
    echo
    
    echo -e "${BLUE}🔧 管理命令：${NC}"
    echo "   查看状态: docker-compose -f $COMPOSE_FILE ps"
    echo "   查看日志: docker-compose -f $COMPOSE_FILE logs -f"
    echo "   重启服务: docker-compose -f $COMPOSE_FILE restart"
    echo "   停止服务: docker-compose -f $COMPOSE_FILE down"
    echo
    
    echo -e "${YELLOW}📚 下一步：${NC}"
    echo "   1. 访问前端界面开始使用"
    echo "   2. 在'API配置'页面添加LLM服务商配置"
    echo "   3. 查看文档了解更多功能: README.md"
    echo
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                    🚀 LLM提示词优化平台部署脚本"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
    
    check_dependencies
    select_mode
    deploy
    health_check
    show_info
    
    log "SUCCESS" "部署完成！"
}

# 运行主函数
main "$@" 