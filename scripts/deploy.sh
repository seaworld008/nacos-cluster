#!/bin/bash

# 获取当前主机IP
HOST_IP=$(hostname -I | awk '{print $1}')

echo "===== Nacos集群部署脚本 ====="
echo "当前主机IP: $HOST_IP"

# 根据IP地址确定节点角色
case "$HOST_IP" in
    "192.168.100.11")
        NODE_TYPE="node1"
        echo "检测到节点1 (MySQL + Nacos + Nginx)"
        
        # 确保目录存在
        mkdir -p /opt/nacos-cluster/logs/{node1,nginx}
        mkdir -p /opt/nacos-cluster/mysql/{data,conf}
        
        # 检查MySQL配置文件
        if [ ! -f "/opt/nacos-cluster/mysql/conf/my.cnf" ]; then
            echo "创建MySQL配置文件..."
            cat > /opt/nacos-cluster/mysql/conf/my.cnf << EOF
[mysqld]
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
default-time-zone='+8:00'
max_connections=1000
max_allowed_packet=64M
innodb_buffer_pool_size=1G
innodb_log_file_size=256M
innodb_flush_log_at_trx_commit=1
innodb_flush_method=O_DIRECT
EOF
        fi
        
        # 先启动MySQL
        echo "启动MySQL..."
        docker-compose -f /opt/nacos-cluster/docker-compose-mysql.yml up -d
        
        # 等待MySQL启动完成
        echo "等待MySQL启动完成..."
        for i in {1..30}; do
            if docker exec nacos-mysql mysqladmin -u nacos -pnacos123456 ping &>/dev/null; then
                echo "MySQL已启动并就绪"
                break
            fi
            echo -n "."
            sleep 2
        done
        
        # 启动Nacos节点1
        echo "启动Nacos节点1..."
        docker-compose -f /opt/nacos-cluster/docker-compose-node1.yml up -d
        
        # 等待Nacos节点1启动完成
        echo "等待Nacos节点1启动完成..."
        for i in {1..30}; do
            if curl -s -m 2 http://localhost:8848/nacos/v1/console/health/readiness | grep -q "success"; then
                echo "Nacos节点1已启动并就绪"
                break
            fi
            echo -n "."
            sleep 2
        done
        
        # 启动Nginx负载均衡器
        echo "启动Nginx负载均衡器..."
        docker-compose -f /opt/nacos-cluster/docker-compose-nginx.yml up -d
        
        echo "===== 节点1部署完成 ====="
        echo "请访问 http://192.168.100.11:8080/nacos 验证部署"
        echo "默认用户名/密码: nacos/nacos"
        ;;
        
    "192.168.100.12")
        NODE_TYPE="node2"
        echo "检测到节点2 (Nacos)"
        
        # 确保日志目录存在
        mkdir -p /opt/nacos-cluster/logs/node2
        
        # 启动Nacos节点2
        echo "启动Nacos节点2..."
        docker-compose -f /opt/nacos-cluster/docker-compose-node2.yml up -d
        
        echo "===== 节点2部署完成 ====="
        ;;
        
    "192.168.100.13")
        NODE_TYPE="node3"
        echo "检测到节点3 (Nacos)"
        
        # 确保日志目录存在
        mkdir -p /opt/nacos-cluster/logs/node3
        
        # 启动Nacos节点3
        echo "启动Nacos节点3..."
        docker-compose -f /opt/nacos-cluster/docker-compose-node3.yml up -d
        
        echo "===== 节点3部署完成 ====="
        ;;
        
    *)
        echo "错误: 无法识别当前主机IP ($HOST_IP)"
        echo "本脚本仅支持IP为192.168.100.11、192.168.100.12或192.168.100.13的服务器"
        exit 1
        ;;
esac

# 验证部署
echo -e "\n===== 验证部署 ====="
echo "等待服务启动完成..."
sleep 10

# 检查Nacos服务状态
if curl -s -m 5 http://localhost:8848/nacos/v1/console/health/readiness | grep -q "success"; then
    echo "Nacos服务状态: 正常"
else
    echo "Nacos服务状态: 异常"
fi

# 如果是节点1，检查Nginx状态
if [ "$NODE_TYPE" == "node1" ]; then
    if curl -s -m 5 http://localhost:8080/nacos/ | grep -q "Nacos"; then
        echo "Nginx负载均衡状态: 正常"
    else
        echo "Nginx负载均衡状态: 异常"
    fi
fi

echo -e "\n部署完成！"