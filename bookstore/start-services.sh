#!/bin/bash
# Bookstore 服务启动脚本
# 数据持久化到 E:\dockerData 目录

echo "=== 创建数据持久化目录 ==="
mkdir -p /e/dockerData/mysql /e/dockerData/redis

echo ""
echo "=== 启动 MySQL (数据挂载到 E:\dockerData\mysql) ==="
docker run -d \
  --name mysql-bookstore \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=gozero \
  -v /e/dockerData/mysql:/var/lib/mysql \
  --restart unless-stopped \
  mysql:latest

echo ""
echo "=== 等待 MySQL 启动... ==="
sleep 15

echo ""
echo "=== 启动 Redis (数据挂载到 E:\dockerData\redis) ==="
docker run -d \
  --name redis-bookstore \
  -p 6379:6379 \
  -v /e/dockerData/redis:/data \
  --restart unless-stopped \
  redis:alpine redis-server --appendonly yes

echo ""
echo "=== 等待服务启动完成... ==="
sleep 5

echo ""
echo "=== 检查服务状态 ==="
docker ps --filter "name=mysql-bookstore" --filter "name=redis-bookstore"

echo ""
echo "=== 初始化数据库表结构 ==="
docker exec -i mysql-bookstore mysql -uroot -proot gozero <<EOF
CREATE TABLE IF NOT EXISTS book (
  book VARCHAR(255) NOT NULL COMMENT '书名',
  price BIGINT NOT NULL COMMENT '价格',
  PRIMARY KEY (book)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT '图书表';
EOF

echo ""
echo "✅ MySQL 和 Redis 已启动!"
echo "MySQL: localhost:3306 (root/root, database: gozero)"
echo "Redis: localhost:6379"
echo "数据目录:"
echo "  - MySQL: E:\\dockerData\\mysql"
echo "  - Redis: E:\\dockerData\\redis"
