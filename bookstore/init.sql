-- 初始化 bookstore 数据库表结构

CREATE TABLE IF NOT EXISTS `book` (
  `book` VARCHAR(255) NOT NULL COMMENT '书名',
  `price` BIGINT NOT NULL COMMENT '价格',
  PRIMARY KEY (`book`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='图书表';

-- 插入一些测试数据
INSERT INTO `book` (`book`, `price`) VALUES
  ('Go语言编程', 89),
  ('深入理解计算机系统', 139),
  ('算法导论', 128)
ON DUPLICATE KEY UPDATE `price` = VALUES(`price`);
