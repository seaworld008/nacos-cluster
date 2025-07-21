# Nacos 3节点集群生产环境部署指南

## 概述

本文档提供了在3台服务器上使用Docker Compose部署Nacos 2.3.0（最新稳定版）集群的完整方案。该方案参考了Nacos官方最佳实践，适用于生产环境部署。

## 服务器信息

- 节点1: 192.168.100.11 (MySQL + Nacos + Nginx)
- 节点2: 192.168.100.12 (Nacos)
- 节点3: 192.168.100.13 (Nacos)

## 架构说明

- **数据存储**: MySQL 8.0 部署在节点1上
- **服务注册与配置中心**: 3个Nacos节点组成高可用集群
- **负载均衡**: Nginx部署在节点1上，实现负载均衡
- **容器编排**: 所有服务使用Docker Compose编排
- **高可用设计**: 任意单节点故障不影响整体服务可用性

## 目录结构

```
nacos-cluster/
├── README.md                   # 部署文档
├── docker-compose-node1.yml    # 节点1配置(Nacos+MySQL)
├── docker-compose-node2.yml    # 节点2配置(Nacos)
├── docker-compose-node3.yml    # 节点3配置(Nacos)
├── docker-compose-nginx.yml    # Nginx配置(部署在节点1)
├── docker-compose-mysql.yml    # MySQL单独配置(可选)
├── config/
│   ├── application.properties  # Nacos应用配置
│   └── nginx.conf              # Nginx配置
├── mysql/
│   ├── nacos-mysql.sql         # 数据库初始化脚本
│   └── conf/                   # MySQL配置文件目录
└── scripts/
    ├── deploy.sh               # 部署脚本
    ├── backup.sh               # 备份脚本
    └── health-check.sh         # 健康检查脚本
```

## 部署步骤

### 1. 环境准备

在所有3台服务器上执行以下命令安装Docker和Docker Compose:

```bash
# 安装Docker
curl -fsSL https://get.docker.com | bash
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 创建项目目录
mkdir -p /opt/nacos-cluster/{config,mysql/conf,scripts,logs/{node1,node2,node3,nginx}}
cd /opt/nacos-cluster
```

### 2. 配置文件准备

将本项目中的配置文件复制到对应服务器的 `/opt/nacos-cluster/` 目录下:

```bash
# 在每台服务器上执行
cd /opt/nacos-cluster

# 节点1 (192.168.100.11)
# 复制docker-compose-node1.yml, docker-compose-nginx.yml, docker-compose-mysql.yml
# 复制config目录和mysql目录下的所有文件

# 节点2 (192.168.100.12)
# 复制docker-compose-node2.yml和config/application.properties

# 节点3 (192.168.100.13)
# 复制docker-compose-node3.yml和config/application.properties
```

### 3. 创建MySQL配置文件

在节点1上创建MySQL配置文件:

```bash
# 在节点1 (192.168.100.11) 执行
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
```

### 4. 创建部署脚本

在每台服务器上创建对应的部署脚本:

#### 节点1 (192.168.100.11)

```bash
cat > /opt/nacos-cluster/scripts/deploy.sh << 'EOF'
#!/bin/bash

echo "===== 开始部署节点1 (192.168.100.11) ====="

# 确保目录存在
mkdir -p /opt/nacos-cluster/logs/{node1,nginx}
mkdir -p /opt/nacos-cluster/mysql/data

# 先启动MySQL
echo "启动MySQL..."
docker-compose -f /opt/nacos-cluster/docker-compose-mysql.yml up -d

# 等待MySQL启动完成
echo "等待MySQL启动完成..."
sleep 30

# 启动Nacos节点1
echo "启动Nacos节点1..."
docker-compose -f /opt/nacos-cluster/docker-compose-node1.yml up -d

# 等待Nacos节点1启动完成
echo "等待Nacos节点1启动完成..."
sleep 20

# 启动Nginx负载均衡器
echo "启动Nginx负载均衡器..."
docker-compose -f /opt/nacos-cluster/docker-compose-nginx.yml up -d

echo "===== 节点1部署完成 ====="
echo "请访问 http://192.168.100.11:8080/nacos 验证部署"
echo "默认用户名/密码: nacos/nacos"
EOF

chmod +x /opt/nacos-cluster/scripts/deploy.sh
```

#### 节点2 (192.168.100.12)

```bash
cat > /opt/nacos-cluster/scripts/deploy.sh << 'EOF'
#!/bin/bash

echo "===== 开始部署节点2 (192.168.100.12) ====="

# 确保日志目录存在
mkdir -p /opt/nacos-cluster/logs/node2

# 启动Nacos节点2
echo "启动Nacos节点2..."
docker-compose -f /opt/nacos-cluster/docker-compose-node2.yml up -d

echo "===== 节点2部署完成 ====="
EOF

chmod +x /opt/nacos-cluster/scripts/deploy.sh
```

#### 节点3 (192.168.100.13)

```bash
cat > /opt/nacos-cluster/scripts/deploy.sh << 'EOF'
#!/bin/bash

echo "===== 开始部署节点3 (192.168.100.13) ====="

# 确保日志目录存在
mkdir -p /opt/nacos-cluster/logs/node3

# 启动Nacos节点3
echo "启动Nacos节点3..."
docker-compose -f /opt/nacos-cluster/docker-compose-node3.yml up -d

echo "===== 节点3部署完成 ====="
EOF

chmod +x /opt/nacos-cluster/scripts/deploy.sh
```

### 5. 创建健康检查脚本

在每台服务器上创建健康检查脚本:

```bash
cat > /opt/nacos-cluster/scripts/health-check.sh << 'EOF'
#!/bin/bash

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
if [ "$(hostname -I | awk '{print $1}')" == "192.168.100.11" ]; then
  echo -e "\n===== MySQL健康检查 ====="
  if docker exec nacos-mysql mysqladmin -u nacos -pnacos123456 ping &>/dev/null; then
    echo "MySQL状态: 正常"
  else
    echo "MySQL状态: 异常"
  fi
fi
EOF

chmod +x /opt/nacos-cluster/scripts/health-check.sh
```

### 6. 创建备份脚本

在节点1上创建备份脚本:

```bash
cat > /opt/nacos-cluster/scripts/backup.sh << 'EOF'
#!/bin/bash

# 备份目录
BACKUP_DIR="/opt/nacos-backup"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/nacos_mysql_${DATE}.sql"

# 创建备份目录
mkdir -p ${BACKUP_DIR}

echo "===== 开始备份Nacos数据 ====="

# 备份MySQL数据
echo "备份MySQL数据到 ${BACKUP_FILE}..."
docker exec nacos-mysql mysqldump -u nacos -pnacos123456 --databases nacos_config > ${BACKUP_FILE}

# 检查备份是否成功
if [ $? -eq 0 ] && [ -s ${BACKUP_FILE} ]; then
  echo "备份成功: ${BACKUP_FILE}"
  
  # 压缩备份文件
  gzip ${BACKUP_FILE}
  echo "备份文件已压缩: ${BACKUP_FILE}.gz"
  
  # 删除7天前的备份
  find ${BACKUP_DIR} -name "nacos_mysql_*.sql.gz" -mtime +7 -delete
  echo "已删除7天前的备份文件"
else
  echo "备份失败!"
fi

echo "===== 备份完成 ====="
EOF

chmod +x /opt/nacos-cluster/scripts/backup.sh
```

### 7. 启动服务

按照以下顺序启动服务:

1. 先在节点1上启动:
```bash
cd /opt/nacos-cluster
./scripts/deploy.sh
```

2. 然后在节点2上启动:
```bash
cd /opt/nacos-cluster
./scripts/deploy.sh
```

3. 最后在节点3上启动:
```bash
cd /opt/nacos-cluster
./scripts/deploy.sh
```

### 8. 验证部署

访问以下地址验证部署:

- Nacos控制台: http://192.168.100.11:8080/nacos
- 默认用户名/密码: nacos/nacos

也可以使用健康检查脚本验证:
```bash
cd /opt/nacos-cluster
./scripts/health-check.sh
```

## 生产环境优化建议

### 1. 安全配置

#### 修改默认密码
登录Nacos控制台后，立即修改默认密码。

#### 配置HTTPS访问
在Nginx中配置SSL证书，启用HTTPS访问:

```nginx
# 在nginx.conf中添加HTTPS配置
server {
    listen 443 ssl;
    server_name _;
    
    ssl_certificate /etc/nginx/ssl/nacos.crt;
    ssl_certificate_key /etc/nginx/ssl/nacos.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # 其他配置与HTTP相同
    location /nacos/ {
        proxy_pass http://nacos-cluster;
        # ...其他配置
    }
}
```

#### 网络安全
- 配置防火墙，只开放必要端口
- 使用内网IP进行节点间通信
- 对外只暴露Nginx负载均衡器的端口

```bash
# 防火墙配置示例 (使用firewalld)
# 节点1
firewall-cmd --permanent --add-port=8080/tcp  # Nginx HTTP
firewall-cmd --permanent --add-port=443/tcp   # Nginx HTTPS (如果配置)
firewall-cmd --permanent --add-port=8848/tcp --source=192.168.100.0/24  # Nacos内部通信
firewall-cmd --permanent --add-port=9848/tcp --source=192.168.100.0/24  # Nacos内部通信
firewall-cmd --permanent --add-port=9849/tcp --source=192.168.100.0/24  # Nacos内部通信
firewall-cmd --permanent --add-port=3306/tcp --source=192.168.100.0/24  # MySQL内部通信

# 节点2和节点3
firewall-cmd --permanent --add-port=8848/tcp --source=192.168.100.0/24  # Nacos内部通信
firewall-cmd --permanent --add-port=9848/tcp --source=192.168.100.0/24  # Nacos内部通信
firewall-cmd --permanent --add-port=9849/tcp --source=192.168.100.0/24  # Nacos内部通信

# 重新加载防火墙配置
firewall-cmd --reload
```

### 2. 监控配置

#### 日志收集
配置ELK或Graylog等日志收集系统，收集Nacos、MySQL和Nginx的日志。

#### 监控告警
使用Prometheus + Grafana监控Nacos集群:

1. 在application.properties中添加:
```properties
management.endpoints.web.exposure.include=*
```

2. 配置Prometheus抓取Nacos指标:
```yaml
scrape_configs:
  - job_name: 'nacos'
    metrics_path: '/nacos/actuator/prometheus'
    static_configs:
      - targets: ['192.168.100.11:8848', '192.168.100.12:8848', '192.168.100.13:8848']
```

#### 定期备份
配置crontab定期执行备份脚本:

```bash
# 每天凌晨2点执行备份
0 2 * * * /opt/nacos-cluster/scripts/backup.sh >> /opt/nacos-cluster/logs/backup.log 2>&1
```

### 3. 性能优化

#### JVM参数调优
根据服务器内存情况调整JVM参数:

```yaml
# 在docker-compose文件中修改
environment:
  JVM_XMS: 2g  # 根据实际内存调整
  JVM_XMX: 2g  # 根据实际内存调整
  JVM_XMN: 1g  # 年轻代大小，通常为XMX的1/2
  JVM_MS: 128m # 元空间初始大小
  JVM_MMS: 320m # 元空间最大大小
  JVM_EXTRA_OPTS: '-XX:+UseG1GC -XX:MaxGCPauseMillis=200'
```

#### 数据库优化
调整MySQL配置以提高性能:

```ini
# 在my.cnf中添加
innodb_buffer_pool_size=4G  # 根据实际内存调整，通常为总内存的50%-70%
innodb_log_file_size=512M
innodb_flush_log_at_trx_commit=1  # 保证数据安全性
innodb_flush_method=O_DIRECT
innodb_read_io_threads=8
innodb_write_io_threads=8
```

#### 网络优化
调整Nginx配置以优化网络性能:

```nginx
# 在nginx.conf中添加
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 10240;
    multi_accept on;
    use epoll;
}

http {
    keepalive_timeout 65;
    keepalive_requests 10000;
    client_max_body_size 20m;
    client_body_buffer_size 128k;
    proxy_buffer_size 64k;
    proxy_buffers 4 64k;
    proxy_busy_buffers_size 128k;
    proxy_connect_timeout 5s;
    proxy_read_timeout 60s;
    proxy_send_timeout 60s;
}
```

## 故障排除

### 常见问题及解决方案

#### 1. 节点无法加入集群
- **症状**: Nacos节点启动后无法加入集群，日志中显示连接其他节点失败
- **解决方案**:
  - 检查网络连通性: `ping 192.168.100.xx`
  - 检查防火墙是否开放了8848、9848、9849端口
  - 确认所有节点的NACOS_SERVERS环境变量配置一致
  - 检查各节点时间是否同步，使用NTP服务同步时间

#### 2. 数据库连接失败
- **症状**: Nacos日志中显示无法连接到MySQL数据库
- **解决方案**:
  - 检查MySQL服务状态: `docker ps | grep mysql`
  - 验证数据库连接配置是否正确
  - 检查MySQL用户权限: `docker exec -it nacos-mysql mysql -u nacos -p -e "SHOW GRANTS FOR 'nacos'@'%';"`
  - 确认MySQL允许远程连接: `docker exec -it nacos-mysql mysql -u root -p -e "SELECT host, user FROM mysql.user WHERE user='nacos';"`

#### 3. 服务启动失败
- **症状**: Docker容器无法启动或启动后立即退出
- **解决方案**:
  - 检查端口占用: `netstat -tulpn | grep 8848`
  - 检查日志: `docker logs nacos-node1`
  - 验证配置文件语法: `docker-compose -f docker-compose-node1.yml config`
  - 检查磁盘空间: `df -h`

### 日志查看

```bash
# 查看Nacos节点1日志
docker logs -f nacos-node1

# 查看MySQL日志
docker logs -f nacos-mysql

# 查看Nginx日志
docker logs -f nacos-nginx

# 查看容器状态
docker ps -a | grep nacos
```

## 维护操作

### 备份数据
```bash
# 手动执行备份
cd /opt/nacos-cluster
./scripts/backup.sh
```

### 更新Nacos版本
```bash
# 1. 修改docker-compose文件中的镜像版本
# 2. 重启服务
docker-compose -f docker-compose-nodeX.yml down
docker-compose -f docker-compose-nodeX.yml up -d
```

### 扩展集群
如需添加更多节点，需要:
1. 准备新服务器
2. 复制配置文件并修改
3. 更新所有节点的NACOS_SERVERS环境变量
4. 更新Nginx负载均衡配置

### 数据迁移
如需迁移数据库到独立服务器:
1. 备份当前数据
2. 在新服务器上恢复数据
3. 更新所有Nacos节点的数据库连接配置
4. 重启所有Nacos节点

## 参考资料

- [Nacos官方文档](https://nacos.io/zh-cn/docs/what-is-nacos.html)
- [Nacos集群部署指南](https://nacos.io/zh-cn/docs/cluster-mode-quick-start.html)
- [Nacos Docker部署](https://nacos.io/zh-cn/docs/quick-start-docker.html)
- [MySQL官方文档](https://dev.mysql.com/doc/)
- [Nginx负载均衡配置](https://nginx.org/en/docs/http/load_balancing.html)