#!/bin/bash

# 备份目录
BACKUP_DIR="/opt/nacos-backup"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/nacos_mysql_${DATE}.sql"
LOG_FILE="${BACKUP_DIR}/backup.log"

# 获取当前主机IP
HOST_IP=$(hostname -I | awk '{print $1}')

# 只在节点1上执行备份
if [ "$HOST_IP" != "192.168.100.11" ]; then
  echo "当前节点不是主节点，不执行备份操作"
  exit 0
fi

# 创建备份目录
mkdir -p ${BACKUP_DIR}

echo "===== 开始备份Nacos数据 $(date) =====" | tee -a ${LOG_FILE}

# 检查MySQL容器是否运行
if ! docker ps | grep -q nacos-mysql; then
  echo "错误: MySQL容器未运行，无法执行备份" | tee -a ${LOG_FILE}
  exit 1
fi

# 备份MySQL数据
echo "备份MySQL数据到 ${BACKUP_FILE}..." | tee -a ${LOG_FILE}
docker exec nacos-mysql mysqldump -u nacos -pnacos123456 --databases nacos_config > ${BACKUP_FILE}

# 检查备份是否成功
if [ $? -eq 0 ] && [ -s ${BACKUP_FILE} ]; then
  echo "备份成功: ${BACKUP_FILE}" | tee -a ${LOG_FILE}
  
  # 压缩备份文件
  gzip ${BACKUP_FILE}
  echo "备份文件已压缩: ${BACKUP_FILE}.gz" | tee -a ${LOG_FILE}
  
  # 计算备份文件大小
  BACKUP_SIZE=$(du -h "${BACKUP_FILE}.gz" | cut -f1)
  echo "备份文件大小: ${BACKUP_SIZE}" | tee -a ${LOG_FILE}
  
  # 删除7天前的备份
  OLD_FILES=$(find ${BACKUP_DIR} -name "nacos_mysql_*.sql.gz" -mtime +7)
  if [ -n "$OLD_FILES" ]; then
    echo "删除以下7天前的备份文件:" | tee -a ${LOG_FILE}
    echo "$OLD_FILES" | tee -a ${LOG_FILE}
    find ${BACKUP_DIR} -name "nacos_mysql_*.sql.gz" -mtime +7 -delete
  else
    echo "没有需要删除的旧备份文件" | tee -a ${LOG_FILE}
  fi
  
  # 统计备份目录使用情况
  TOTAL_SIZE=$(du -sh ${BACKUP_DIR} | cut -f1)
  echo "备份目录总大小: ${TOTAL_SIZE}" | tee -a ${LOG_FILE}
else
  echo "备份失败!" | tee -a ${LOG_FILE}
  exit 1
fi

echo "===== 备份完成 $(date) =====" | tee -a ${LOG_FILE}

# 配置定时备份的说明
echo -e "\n要设置定时备份，请执行以下命令:"
echo "crontab -e"
echo "然后添加以下行:"
echo "0 2 * * * /opt/nacos-cluster/scripts/backup.sh > /dev/null 2>&1"
echo "这将在每天凌晨2点执行备份"