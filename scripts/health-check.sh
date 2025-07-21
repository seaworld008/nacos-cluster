#!/bin/bash

# 获取当前主机IP
HOST_IP=$(hostname -I | awk '{print $1}')
echo "当前主机IP: $HOST_IP"

# 检查Nacos服务健康状态
check_nacos() {
  local node_ip=$1
  local result=$(curl -s -m 5 http://${node_ip}:8848/nacos/v1/console/health/readiness)
  if [[ $result == *"success"* ]]; then
    echo "Nacos节点 ${node_ip} 健康状态: 正常"
    return 0
  else
    echo "Nacos节点 ${node_ip} 健康状态: 异常"
    return 1
  fi
}

# 检查所有节点
echo "===== Nacos集群健康检查 ====="
check_nacos 192.168.100.11
check_nacos 192.168.100.12
check_nacos 192.168.100.13

# 检查Nginx负载均衡
echo -e "\n===== Nginx负载均衡健康检查 ====="
nginx_result=$(curl -s -m 5 http://192.168.100.11:8080/nacos/)
if [[ -n "$nginx_result" ]]; then
  echo "Nginx负载均衡状态: 正常"
else
  echo "Nginx负载均衡状态: 异常"
fi

# 检查MySQL
if [ "$HOST_IP" == "192.168.100.11" ]; then
  echo -e "\n===== MySQL健康检查 ====="
  if docker exec nacos-mysql mysqladmin -u nacos -pnacos123456 ping &>/dev/null; then
    echo "MySQL状态: 正常"
    
    # 检查数据库连接数
    connections=$(docker exec nacos-mysql mysql -u nacos -pnacos123456 -e "SHOW STATUS LIKE 'Threads_connected';" | grep -v Variable_name | awk '{print $2}')
    max_connections=$(docker exec nacos-mysql mysql -u nacos -pnacos123456 -e "SHOW VARIABLES LIKE 'max_connections';" | grep -v Variable_name | awk '{print $2}')
    echo "当前连接数: $connections / $max_connections"
    
    # 检查数据库大小
    db_size=$(docker exec nacos-mysql mysql -u nacos -pnacos123456 -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.tables WHERE table_schema = 'nacos_config';" | grep -v "Size (MB)")
    echo "数据库大小: ${db_size} MB"
  else
    echo "MySQL状态: 异常"
  fi
fi

# 检查磁盘使用情况
echo -e "\n===== 磁盘使用情况 ====="
df -h | grep -E '(Filesystem|/$|/opt)'

# 检查内存使用情况
echo -e "\n===== 内存使用情况 ====="
free -h

# 检查Docker容器状态
echo -e "\n===== Docker容器状态 ====="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E '(NAMES|nacos)'

# 检查日志文件大小
echo -e "\n===== 日志文件大小 ====="
if [ -d "/opt/nacos-cluster/logs" ]; then
  du -sh /opt/nacos-cluster/logs/* 2>/dev/null || echo "无日志文件"
else
  echo "日志目录不存在"
fi

echo -e "\n健康检查完成！"