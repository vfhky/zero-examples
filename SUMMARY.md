# Go-Zero 框架全面实战指南

## 📚 目录

- [1. 框架概述](#1-框架概述)
- [2. 核心组件](#2-核心组件)
- [3. API服务开发](#3-api服务开发)
- [4. RPC服务开发](#4-rpc服务开发)
- [5. 微服务治理](#5-微服务治理)
- [6. 并发工具](#6-并发工具)
- [7. 中间件与拦截器](#7-中间件与拦截器)
- [8. 服务发现](#8-服务发现)
- [9. 日志与监控](#9-日志与监控)
- [10. 文件操作](#10-文件操作)
- [11. 实战项目模板](#11-实战项目模板)
- [12. 最佳实践](#12-最佳实践)

---

## 1. 框架概述

### 1.1 Go-Zero 简介

Go-Zero 是一个集成各种工程实践的 Web 和 RPC 框架，具有以下特点：

- **高性能**：经受千万级日活考验
- **弹性设计**：内建熔断、限流、降载、超时控制
- **代码生成**：通过 goctl 工具一键生成代码
- **微服务治理**：完整的服务发现、负载均衡、链路追踪
- **简单易用**：极简的 API 定义语法

### 1.2 技术栈

```
Go 1.18+
Etcd (服务发现)
Redis (缓存)
MySQL (数据存储)
gRPC (RPC通信)
```

---

## 2. 核心组件

### 2.1 Goctl 工具

Goctl 是 go-zero 的代码生成工具，支持：

```bash
# 安装 goctl
go install github.com/zeromicro/go-zero/tools/goctl@latest

# 生成 API 服务
goctl api new <service-name>
goctl api go -api <api-file> -dir <output-dir>

# 生成 RPC 服务
goctl rpc new <service-name>
goctl rpc protoc <proto-file> --go_out=. --go-grpc_out=. --zrpc_out=.

# 生成模型代码
goctl model mysql ddl -src <sql-file> -dir <output-dir>
```

### 2.2 项目结构

#### API 服务标准结构
```
service-api/
├── etc/                    # 配置文件
│   └── service-api.yaml
├── internal/
│   ├── config/            # 配置定义
│   │   └── config.go
│   ├── handler/           # 路由处理
│   │   └── xxxhandler.go
│   ├── logic/             # 业务逻辑
│   │   └── xxxlogic.go
│   ├── svc/               # 服务上下文
│   │   └── servicecontext.go
│   └── types/             # 类型定义
│       └── types.go
├── service.api            # API 定义文件
└── service.go             # 主程序入口
```

#### RPC 服务标准结构
```
service-rpc/
├── etc/                    # 配置文件
│   └── service.yaml
├── internal/
│   ├── config/            # 配置定义
│   ├── logic/             # 业务逻辑
│   ├── server/            # gRPC 服务器
│   └── svc/               # 服务上下文
├── pb/                    # protobuf 生成文件
├── service.proto          # protobuf 定义
└── service.go             # 主程序入口
```

---

## 3. API服务开发

### 3.1 API 文件定义

**示例：bookstore.api**
```api
syntax = "v1"

type (
    addReq {
        book  string `form:"book"`
        price int64  `form:"price"`
    }
    addResp {
        ok bool `json:"ok"`
    }
)

type (
    checkReq {
        book string `form:"book"`
    }
    checkResp {
        found bool  `json:"found"`
        price int64 `json:"price"`
    }
)

service bookstore-api {
    @handler AddHandler
    get /add (addReq) returns (addResp)

    @handler CheckHandler
    get /check (checkReq) returns (checkResp)
}
```

### 3.2 配置文件

**etc/service-api.yaml**
```yaml
Name: bookstore-api
Host: 0.0.0.0
Port: 8888

# 日志配置
Log:
  ServiceName: bookstore-api
  Mode: file                    # console | file | volume
  Path: logs/api
  Level: info                   # debug | info | error | severe
  Compress: true
  KeepDays: 7
  StackCooldownMillis: 100

# RPC 客户端配置
Add:
  Etcd:
    Hosts:
      - localhost:2379
    Key: add.rpc

Check:
  Etcd:
    Hosts:
      - localhost:2379
    Key: check.rpc
```

### 3.3 Logic 业务逻辑

```go
package logic

import (
    "context"
    "bookstore/api/internal/svc"
    "bookstore/api/internal/types"
    "bookstore/rpc/add/adder"

    "github.com/zeromicro/go-zero/core/logx"
)

type AddLogic struct {
    logx.Logger
    ctx    context.Context
    svcCtx *svc.ServiceContext
}

func NewAddLogic(ctx context.Context, svcCtx *svc.ServiceContext) AddLogic {
    return AddLogic{
        Logger: logx.WithContext(ctx),
        ctx:    ctx,
        svcCtx: svcCtx,
    }
}

func (l *AddLogic) Add(req types.AddReq) (*types.AddResp, error) {
    // 调用 RPC 服务
    resp, err := l.svcCtx.Adder.Add(l.ctx, &adder.AddReq{
        Book:  req.Book,
        Price: req.Price,
    })
    if err != nil {
        return nil, err
    }

    return &types.AddResp{
        Ok: resp.Ok,
    }, nil
}
```

### 3.4 ServiceContext 服务上下文

```go
package svc

import (
    "bookstore/api/internal/config"
    "bookstore/rpc/add/adder"
    "bookstore/rpc/check/checker"

    "github.com/zeromicro/go-zero/zrpc"
)

type ServiceContext struct {
    Config  config.Config
    Adder   adder.Adder
    Checker checker.Checker
}

func NewServiceContext(c config.Config) *ServiceContext {
    return &ServiceContext{
        Config:  c,
        Adder:   adder.NewAdder(zrpc.MustNewClient(c.Add)),
        Checker: checker.NewChecker(zrpc.MustNewClient(c.Check)),
    }
}
```

---

## 4. RPC服务开发

### 4.1 Proto 文件定义

**add.proto**
```protobuf
syntax = "proto3";

package add;

message addReq {
    string book = 1;
    int64 price = 2;
}

message addResp {
    bool ok = 1;
}

service adder {
    rpc add(addReq) returns(addResp);
}
```

### 4.2 RPC 服务实现

```go
package logic

import (
    "context"
    "bookstore/rpc/add/internal/svc"
    "bookstore/rpc/model"

    add "bookstore/rpc/add/adder"
    "github.com/zeromicro/go-zero/core/logx"
)

type AddLogic struct {
    ctx    context.Context
    svcCtx *svc.ServiceContext
    logx.Logger
}

func NewAddLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AddLogic {
    return &AddLogic{
        ctx:    ctx,
        svcCtx: svcCtx,
        Logger: logx.WithContext(ctx),
    }
}

func (l *AddLogic) Add(in *add.AddReq) (*add.AddResp, error) {
    // 构建数据库模型
    book := model.Book{
        Book:  in.Book,
        Price: in.Price,
    }

    // 插入数据库
    _, err := l.svcCtx.Model.Insert(book)
    if err != nil {
        l.Errorf("database insert failed, error: %v", err)
        return nil, err
    }

    return &add.AddResp{Ok: true}, nil
}
```

### 4.3 RPC 客户端调用

**直连方式**
```go
package main

import (
    "context"
    "github.com/zeromicro/go-zero/zrpc"
    "github.com/zeromicro/zero-examples/rpc/remote/unary"
)

func main() {
    client := zrpc.MustNewClient(zrpc.RpcClientConf{
        Endpoints: []string{"localhost:8080"},
    })

    greet := unary.NewGreeterClient(client.Conn())
    resp, err := greet.Greet(context.Background(), &unary.Request{
        Name: "kevin",
    })
    // 处理响应...
}
```

**服务发现方式（Etcd）**
```go
client := zrpc.MustNewClient(zrpc.RpcClientConf{
    Etcd: discov.EtcdConf{
        Hosts: []string{"localhost:2379"},
        Key:   "greet.rpc",
    },
})
```

---

## 5. 微服务治理

### 5.1 熔断器 (Breaker)

**自动熔断示例**
```go
package main

import (
    "github.com/zeromicro/go-zero/core/breaker"
)

func main() {
    br := breaker.NewBreaker()

    err := br.Do(func() error {
        // 调用可能失败的服务
        return callExternalService()
    })

    if err == breaker.ErrServiceUnavailable {
        // 服务已熔断，使用降级方案
        return fallbackResponse()
    }
}
```

**HTTP 服务熔断**
```go
// 熔断器会自动在 RestConf 中启用
server := rest.MustNewServer(rest.RestConf{
    ServiceConf: service.ServiceConf{
        Name: "breaker-demo",
    },
    Host:     "0.0.0.0",
    Port:     8080,
    MaxConns: 1000,
    Timeout:  3000,  // 3秒超时
})
```

### 5.2 限流 (Rate Limiting)

**令牌桶限流**
```go
package main

import (
    "github.com/zeromicro/go-zero/core/limit"
    "github.com/zeromicro/go-zero/core/stores/redis"
)

func main() {
    // 创建 Redis 连接
    store := redis.New("localhost:6379")

    // 创建令牌桶限流器：每秒 100 个请求
    limiter := limit.NewTokenLimiter(100, store, "rate-limit-key")

    // 使用限流器
    if limiter.Allow() {
        // 处理请求
    } else {
        // 请求被限流
    }
}
```

**周期性限流**
```go
// 每分钟最多 1000 次请求
limiter := limit.NewPeriodLimit(60, 1000, store, "period-limit")
```

### 5.3 自适应降载 (Adaptive Shedding)

```go
package main

import (
    "net/http"
    "github.com/zeromicro/go-zero/rest"
    "github.com/zeromicro/go-zero/core/service"
)

func main() {
    engine := rest.MustNewServer(rest.RestConf{
        ServiceConf: service.ServiceConf{
            Name: "shedding-demo",
        },
        Port:         8080,
        Timeout:      1000,     // 1秒超时
        CpuThreshold: 500,      // CPU 使用率 50% 时开始降载
    })

    engine.AddRoute(rest.Route{
        Method:  http.MethodGet,
        Path:    "/",
        Handler: handle,
    })

    engine.Start()
}
```

### 5.4 超时控制

**链式超时控制**
```go
// 在配置文件中设置
RestConf:
  Timeout: 3000  # 3秒超时

// 在业务逻辑中使用 context
func (l *Logic) Handle(req types.Request) (*types.Response, error) {
    // context 会自动携带超时信息
    ctx, cancel := context.WithTimeout(l.ctx, time.Second*2)
    defer cancel()

    resp, err := l.svcCtx.RemoteService.Call(ctx, req)
    return resp, err
}
```

---

## 6. 并发工具

### 6.1 MapReduce

**并行数据处理**
```go
package main

import (
    "github.com/zeromicro/go-zero/core/mr"
)

func main() {
    // 检查合法用户
    result, err := mr.MapReduce(
        // Generate: 生成数据源
        func(source chan<- int64) {
            for _, uid := range []int64{1, 2, 3, 4, 5} {
                source <- uid
            }
        },
        // Mapper: 并行处理每个元素
        func(item int64, writer mr.Writer[int64], cancel func(error)) {
            ok, err := checkUser(item)
            if err != nil {
                cancel(err)
                return
            }
            if ok {
                writer.Write(item)
            }
        },
        // Reducer: 聚合结果
        func(pipe <-chan int64, writer mr.Writer[[]int64], cancel func(error)) {
            var users []int64
            for uid := range pipe {
                users = append(users, uid)
            }
            writer.Write(users)
        },
    )
}

// 并发调用多个服务
func productDetail(uid, pid int64) (*ProductDetail, error) {
    var pd ProductDetail

    err := mr.Finish(
        func() error {
            user, err := userRpc.GetUser(uid)
            pd.User = user
            return err
        },
        func() error {
            store, err := storeRpc.GetStore(pid)
            pd.Store = store
            return err
        },
        func() error {
            order, err := orderRpc.GetOrder(pid)
            pd.Order = order
            return err
        },
    )

    return &pd, err
}
```

### 6.2 Fx 流式处理

**函数式数据流**
```go
package main

import (
    "github.com/zeromicro/go-zero/core/fx"
)

func main() {
    result, err := fx.From(func(source chan<- interface{}) {
        for i := 0; i < 10; i++ {
            source <- i
        }
    }).Map(func(item interface{}) interface{} {
        // 平方
        i := item.(int)
        return i * i
    }).Filter(func(item interface{}) bool {
        // 过滤偶数
        i := item.(int)
        return i%2 == 0
    }).Distinct(func(item interface{}) interface{} {
        return item
    }).Reduce(func(pipe <-chan interface{}) (interface{}, error) {
        // 求和
        var sum int
        for item := range pipe {
            sum += item.(int)
        }
        return sum, nil
    })
}
```

### 6.3 SharedCalls (防缓存击穿)

```go
package main

import (
    "github.com/zeromicro/go-zero/core/syncx"
)

func main() {
    barrier := syncx.NewSingleFlight()

    // 多个并发请求会合并为一次调用
    val, err := barrier.Do("cache-key", func() (interface{}, error) {
        // 只会执行一次，其他请求等待结果
        return fetchFromDatabase()
    })
}
```

### 6.4 对象池 (Pool)

```go
package main

import (
    "github.com/zeromicro/go-zero/core/syncx"
)

func main() {
    pool := syncx.NewPool(
        100,  // 池大小
        func() interface{} {
            // 创建对象
            return createExpensiveObject()
        },
        func(interface{}) {
            // 销毁对象
        },
        syncx.WithMaxAge(time.Second),  // 对象最大存活时间
    )

    obj := pool.Get()
    // 使用对象...
    pool.Put(obj)
}
```

### 6.5 TimingWheel (时间轮)

```go
package main

import (
    "github.com/zeromicro/go-zero/core/collection"
)

func main() {
    // 创建时间轮：1秒精度，600个槽位
    tw, err := collection.NewTimingWheel(time.Second, 600,
        func(key, value interface{}) {
            // 定时任务回调
            executeTask(value)
        },
    )

    // 设置定时任务
    tw.SetTimer("task-1", taskData, time.Minute)
}
```

---

## 7. 中间件与拦截器

### 7.1 HTTP 中间件

**全局中间件**
```go
package main

import (
    "net/http"
    "github.com/zeromicro/go-zero/rest"
)

// 静态中间件
func middleware(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        w.Header().Add("X-Middleware", "static-middleware")
        next(w, r)
    }
}

// 带依赖的中间件
func middlewareWithService(s *Service) rest.Middleware {
    return func(next http.HandlerFunc) http.HandlerFunc {
        return func(w http.ResponseWriter, r *http.Request) {
            token := s.GetToken()
            w.Header().Add("X-Token", token)
            next(w, r)
        }
    }
}

func main() {
    server := rest.MustNewServer(rest.RestConf{Port: 8888})

    // 使用中间件
    server.Use(middleware)
    server.Use(middlewareWithService(newService()))

    server.Start()
}
```

**CORS 中间件**
```go
server := rest.MustNewServer(c, rest.WithCors())
```

**自定义中间件链**
```go
func first(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        w.Header().Add("X-Middleware", "first")
        next(w, r)
    }
}

func second(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        w.Header().Add("X-Middleware", "second")
        next(w, r)
    }
}

server.Use(first)
server.Use(second)
```

### 7.2 RPC 拦截器

**服务端拦截器**
```go
package main

import (
    "context"
    "google.golang.org/grpc"
    "github.com/zeromicro/go-zero/zrpc"
)

func main() {
    server := zrpc.MustNewServer(c, func(grpcServer *grpc.Server) {
        // 注册服务...
    })

    // 添加拦截器
    interceptor := func(ctx context.Context, req interface{},
        info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {

        start := time.Now()
        resp, err := handler(ctx, req)
        log.Printf("method: %s time: %v\n", info.FullMethod, time.Since(start))
        return resp, err
    }

    server.AddUnaryInterceptors(interceptor)
    server.Start()
}
```

---

## 8. 服务发现

### 8.1 Etcd 服务发现

**服务注册（RPC Server）**
```yaml
# etc/server.yaml
Name: greet.rpc
ListenOn: 0.0.0.0:8080

Etcd:
  Hosts:
    - localhost:2379
  Key: greet.rpc
```

**服务发现（RPC Client）**
```yaml
# etc/client.yaml
Etcd:
  Hosts:
    - localhost:2379
  Key: greet.rpc
```

**发布订阅模式**
```go
// Publisher
client := discov.NewPublisher(
    []string{"localhost:2379"},
    "service-key",
    "service-value",
)
client.KeepAlive()

// Subscriber
sub := discov.NewSubscriber(
    []string{"localhost:2379"},
    "service-key",
)
vals := sub.Values()
```

### 8.2 Consul 服务发现

```go
package main

import (
    "github.com/zeromicro/zero-contrib/zrpc/registry/consul"
    "github.com/zeromicro/go-zero/zrpc"
)

func main() {
    c := config.Config{
        RpcServerConf: zrpc.RpcServerConf{
            ListenOn: ":8080",
        },
        Consul: consul.Conf{
            Host: "localhost:8500",
            Key:  "greet.rpc",
        },
    }

    server := zrpc.MustNewServer(c.RpcServerConf, func(grpcServer *grpc.Server) {
        // 注册服务
    })

    // 注册到 Consul
    consul.RegisterService(c.ListenOn, c.Consul)

    server.Start()
}
```

### 8.3 Kubernetes 服务发现

```yaml
# etc/k8s.yaml
Name: greet.rpc
ListenOn: 0.0.0.0:8080

# Kubernetes 原生服务发现
Target: k8s://default/greet-service:8080
```

### 8.4 Nacos 服务发现

```go
import (
    "github.com/zeromicro/zero-contrib/zrpc/registry/nacos"
)

// 使用 Nacos 配置
```

---

## 9. 日志与监控

### 9.1 日志配置

**配置文件**
```yaml
Log:
  ServiceName: my-service
  Mode: file              # console | file | volume
  Path: logs
  Level: info            # debug | info | error | severe
  Compress: true
  KeepDays: 7
  StackCooldownMillis: 100
```

**代码中使用**
```go
package main

import (
    "github.com/zeromicro/go-zero/core/logx"
)

func main() {
    // 结构化日志
    logx.Infow("user login",
        logx.Field("userId", 123),
        logx.Field("ip", "192.168.1.1"),
        logx.Field("duration", time.Second),
    )

    // 错误日志
    logx.Errorw("database error",
        logx.Field("table", "users"),
        logx.Field("error", err),
    )

    // 慢日志
    logx.Sloww("slow query",
        logx.Field("sql", "SELECT * FROM users"),
        logx.Field("duration", 3*time.Second),
    )

    // 带上下文
    logx.WithContext(ctx).Info("context aware log")

    // 带时长
    logx.WithDuration(duration).Info("operation completed")
}
```

### 9.2 自定义日志 Writer

**双输出（文件+控制台）**
```go
package main

import (
    "bufio"
    "os"
    "github.com/zeromicro/go-zero/core/logx"
)

type MultiWriter struct {
    writer        logx.Writer
    consoleWriter logx.Writer
}

func NewMultiWriter(writer logx.Writer) logx.Writer {
    return &MultiWriter{
        writer:        writer,
        consoleWriter: logx.NewWriter(bufio.NewWriter(os.Stdout)),
    }
}

func (w *MultiWriter) Info(v interface{}, fields ...logx.LogField) {
    w.consoleWriter.Info(v, fields...)
    w.writer.Info(v, fields...)
}

// 实现其他方法...

func main() {
    var c logx.LogConf
    conf.MustLoad("config.yaml", &c)
    logx.MustSetup(c)

    fileWriter := logx.Reset()
    writer := NewMultiWriter(fileWriter)
    logx.SetWriter(writer)
}
```

### 9.3 链路追踪 (Tracing)

**自动启用追踪**
```yaml
# API 服务配置
Telemetry:
  Name: bookstore-api
  Endpoint: http://localhost:14268/api/traces
  Sampler: 1.0
  Batcher: jaeger
```

**追踪传播**
```go
// 追踪信息会自动在 HTTP/RPC 调用间传播
// 通过 context 携带 trace 信息
resp, err := l.svcCtx.RemoteService.Call(l.ctx, req)
```

---

## 10. 文件操作

### 10.1 文件上传

**API 定义**
```api
syntax = "v1"

type UploadResponse {
    Code int `json:"code"`
}

service file-api {
    @handler UploadHandler
    post /upload returns (UploadResponse)
}
```

**处理器实现**
```go
func (h *UploadHandler) Upload(w http.ResponseWriter, r *http.Request) {
    // 解析上传文件
    file, header, err := r.FormFile("file")
    if err != nil {
        httpx.Error(w, err)
        return
    }
    defer file.Close()

    // 保存文件
    dst, err := os.Create("uploads/" + header.Filename)
    if err != nil {
        httpx.Error(w, err)
        return
    }
    defer dst.Close()

    io.Copy(dst, file)

    httpx.OkJson(w, UploadResponse{Code: 0})
}
```

### 10.2 文件下载

**API 定义**
```api
type DownloadRequest {
    File string `path:"file"`
}

service file-api {
    @handler DownloadHandler
    get /static/:file(DownloadRequest)
}
```

**处理器实现**
```go
func (h *DownloadHandler) Download(w http.ResponseWriter, r *http.Request) {
    var req DownloadRequest
    httpx.Parse(r, &req)

    filepath := "static/" + req.File

    // 设置响应头
    w.Header().Set("Content-Type", "application/octet-stream")
    w.Header().Set("Content-Disposition",
        fmt.Sprintf("attachment; filename=%s", req.File))

    // 返回文件
    http.ServeFile(w, r, filepath)
}
```

### 10.3 API 导入

**模块化 API 定义**
```api
// file.api
syntax = "v1"

import "download.api"
import "upload.api"
```

---

## 11. 实战项目模板

### 11.1 Bookstore（书店系统 - 多RPC）

**项目结构**
```
bookstore/
├── docker-compose.yml      # Docker 编排
├── init.sql               # 数据库初始化
├── api/                   # API 网关
│   ├── bookstore.api
│   └── internal/
│       ├── logic/         # 调用 RPC 服务
│       └── svc/           # 依赖注入
└── rpc/
    ├── add/              # 添加书籍服务
    │   ├── add.proto
    │   └── internal/logic/
    ├── check/            # 查询书籍服务
    │   ├── check.proto
    │   └── internal/logic/
    └── model/            # 数据模型
```

**Docker Compose 配置**
```yaml
version: '3.8'

services:
  mysql:
    image: mysql:latest
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: gozero
    ports:
      - "3306:3306"
    volumes:
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql

  redis:
    image: redis:alpine
    ports:
      - "6379:6379"

  etcd:
    image: quay.io/coreos/etcd
    ports:
      - "2379:2379"
```

**数据库模型生成**
```bash
goctl model mysql ddl -src init.sql -dir rpc/model -c
```

### 11.2 ShortUrl（短链服务）

**API 层**
```api
syntax = "v1"

type expandReq {
    Shorten string `form:"shorten"`
}

type expandResp {
    Url string `json:"url"`
}

type shortenReq {
    Url string `form:"url"`
}

type shortenResp {
    Shorten string `json:"shorten"`
}

service shorturl-api {
    @handler ShortenHandler
    get /shorten(shortenReq) returns(shortenResp)

    @handler ExpandHandler
    get /expand(expandReq) returns(expandResp)
}
```

**RPC 层**
```protobuf
syntax = "proto3";

package transform;

message expandReq {
    string shorten = 1;
}

message expandResp {
    string url = 1;
}

service transformer {
    rpc expand(expandReq) returns(expandResp);
    rpc shorten(shortenReq) returns(shortenResp);
}
```

### 11.3 Gateway（API 网关）

**配置文件**
```yaml
Name: demo-gateway
Host: localhost
Port: 8888

Upstreams:
  - Grpc:
      Etcd:
        Hosts:
          - localhost:2379
        Key: hello.rpc
    # ProtoSet 模式
    ProtoSets:
      - hello.pb
    # 路由映射
    Mappings:
      - Method: get
        Path: /pingHello/:ping
        RpcPath: hello.Hello/Ping
```

**启动网关**
```go
package main

import (
    "github.com/zeromicro/go-zero/gateway"
    "github.com/zeromicro/go-zero/core/conf"
)

func main() {
    var c gateway.GatewayConf
    conf.MustLoad("etc/gateway.yaml", &c)

    gw := gateway.MustNewServer(c)
    defer gw.Stop()
    gw.Start()
}
```

### 11.4 Chat（WebSocket 聊天室）

**WebSocket Handler**
```go
package main

import (
    "net/http"
    "github.com/zeromicro/go-zero/rest"
    "github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
    CheckOrigin: func(r *http.Request) bool {
        return true
    },
}

func main() {
    engine := rest.MustNewServer(rest.RestConf{Port: 8080})

    hub := NewHub()
    go hub.Run()

    engine.AddRoute(rest.Route{
        Method: http.MethodGet,
        Path:   "/ws",
        Handler: func(w http.ResponseWriter, r *http.Request) {
            ServeWs(hub, w, r)
        },
    })

    engine.Start()
}
```

---

## 12. 最佳实践

### 12.1 项目初始化流程

```bash
# 1. 创建项目目录
mkdir my-project && cd my-project

# 2. 初始化 Go 模块
go mod init my-project

# 3. 创建 API 服务
goctl api new api
cd api && go mod tidy

# 4. 创建 RPC 服务
goctl rpc new rpc
cd rpc && go mod tidy

# 5. 生成数据模型
goctl model mysql ddl -src schema.sql -dir model -c

# 6. 启动服务
go run api.go -f etc/api.yaml
go run rpc.go -f etc/rpc.yaml
```

### 12.2 配置管理

**环境变量**
```go
type Config struct {
    rest.RestConf

    Database struct {
        Host     string `json:",env=DB_HOST"`
        Port     int    `json:",default=3306"`
        User     string `json:",env=DB_USER"`
        Password string `json:",env=DB_PASSWORD"`
    }
}
```

**多环境配置**
```bash
# 开发环境
etc/api-dev.yaml

# 测试环境
etc/api-test.yaml

# 生产环境
etc/api-prod.yaml
```

### 12.3 错误处理

**统一错误码**
```go
package errorx

import "github.com/pkg/errors"

const (
    CodeSuccess      = 0
    CodeParamError   = 400
    CodeUnauthorized = 401
    CodeServerError  = 500
)

type CodeError struct {
    Code int    `json:"code"`
    Msg  string `json:"msg"`
}

func (e *CodeError) Error() string {
    return e.Msg
}

func NewCodeError(code int, msg string) *CodeError {
    return &CodeError{Code: code, Msg: msg}
}

func NewParamError(msg string) *CodeError {
    return NewCodeError(CodeParamError, msg)
}
```

**全局错误处理**
```go
httpx.SetErrorHandler(func(err error) (int, interface{}) {
    switch e := err.(type) {
    case *CodeError:
        return http.StatusOK, e
    default:
        return http.StatusInternalServerError, &CodeError{
            Code: CodeServerError,
            Msg:  "服务器内部错误",
        }
    }
})
```

### 12.4 数据库操作

**使用 sqlx**
```go
type Book struct {
    Book  string `db:"book"`
    Price int64  `db:"price"`
}

// 插入
result, err := conn.Exec("INSERT INTO book(book, price) VALUES(?, ?)",
    book.Book, book.Price)

// 查询单条
var book Book
err := conn.QueryRow(&book, "SELECT * FROM book WHERE book = ?", bookName)

// 查询多条
var books []Book
err := conn.Query(&books, "SELECT * FROM book WHERE price > ?", 50)
```

**使用缓存**
```go
type BookModel interface {
    Insert(data Book) (sql.Result, error)
    FindOne(book string) (*Book, error)
    Update(data Book) error
    Delete(book string) error
}

// goctl 自动生成带缓存的模型
goctl model mysql ddl -src schema.sql -dir model -c
```

### 12.5 性能优化

**连接池配置**
```go
// MySQL 连接池
sqlx.NewMysql(datasource, sqlx.WithMaxIdleConns(10))

// Redis 连接池
redis.NewRedis(redis.RedisConf{
    Host: "localhost:6379",
    Type: "node",
    Pass: "",
})
```

**并发控制**
```go
import "github.com/zeromicro/go-zero/core/limit"

// 限制并发数
limiter := syncx.NewLimit(100)  // 最多 100 个并发

if limiter.TryBorrow() {
    defer limiter.Return()
    // 执行任务
} else {
    // 并发已满
}
```

### 12.6 测试

**单元测试**
```go
func TestAddLogic_Add(t *testing.T) {
    ctx := context.Background()

    // Mock 依赖
    mockModel := &MockBookModel{}
    svcCtx := &svc.ServiceContext{
        Model: mockModel,
    }

    logic := NewAddLogic(ctx, svcCtx)

    resp, err := logic.Add(&add.AddReq{
        Book:  "Test Book",
        Price: 100,
    })

    assert.Nil(t, err)
    assert.True(t, resp.Ok)
}
```

### 12.7 部署

**Docker 部署**
```dockerfile
FROM golang:1.18-alpine AS builder

WORKDIR /app
COPY . .
RUN go mod download
RUN go build -o main .

FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/main .
COPY etc/ etc/

EXPOSE 8888
CMD ["./main", "-f", "etc/service.yaml"]
```

**Kubernetes 部署**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bookstore-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: bookstore-api
  template:
    metadata:
      labels:
        app: bookstore-api
    spec:
      containers:
      - name: api
        image: bookstore-api:latest
        ports:
        - containerPort: 8888
        env:
        - name: DB_HOST
          value: "mysql-service"
---
apiVersion: v1
kind: Service
metadata:
  name: bookstore-api
spec:
  selector:
    app: bookstore-api
  ports:
  - port: 8888
    targetPort: 8888
  type: LoadBalancer
```

---

## 13. 常用工具类

### 13.1 Bloom Filter (布隆过滤器)

```go
import (
    "github.com/zeromicro/go-zero/core/bloom"
    "github.com/zeromicro/go-zero/core/stores/redis"
)

store := redis.New("localhost:6379")
filter := bloom.New(store, "testbloom", 64)

filter.Add([]byte("kevin"))
exists := filter.Exists([]byte("kevin"))  // true
```

### 13.2 String 工具

```go
import "github.com/zeromicro/go-zero/core/stringx"

// 字符串替换
replacer := stringx.NewReplacer(map[string]string{
    "日本": "法国",
    "东京": "巴黎",
})
result := replacer.Replace("日本的首都是东京")

// 生成随机 ID
id := stringx.RandId()

// 生成随机字符串
str := stringx.Rand()
```

### 13.3 Collection (集合工具)

```go
import "github.com/zeromicro/go-zero/core/collection"

// RollingWindow 滑动窗口
window := collection.NewRollingWindow(50, time.Millisecond*100)
window.Add(1.0)

window.Reduce(func(b *collection.Bucket) {
    // 处理桶数据
})
```

### 13.4 ServiceGroup (服务组)

```go
import "github.com/zeromicro/go-zero/core/service"

type MorningService struct{}
func (m MorningService) Start() { /* ... */ }
func (m MorningService) Stop()  { /* ... */ }

type EveningService struct{}
func (e EveningService) Start() { /* ... */ }
func (e EveningService) Stop()  { /* ... */ }

func main() {
    group := service.NewServiceGroup()
    defer group.Stop()

    group.Add(MorningService{})
    group.Add(EveningService{})

    group.Start()
}
```

---

## 14. 快速开发检查清单

### ✅ 新项目启动

- [ ] 安装 goctl：`go install github.com/zeromicro/go-zero/tools/goctl@latest`
- [ ] 初始化项目：`go mod init <project-name>`
- [ ] 定义 API 文件或 Proto 文件
- [ ] 生成代码：`goctl api go` 或 `goctl rpc protoc`
- [ ] 配置数据库、Redis、Etcd 连接
- [ ] 实现业务 Logic 层

### ✅ API 服务开发

- [ ] 定义请求/响应结构体
- [ ] 设置路由和 Handler
- [ ] 实现 Logic 业务逻辑
- [ ] 配置中间件（CORS、JWT 等）
- [ ] 添加参数验证
- [ ] 配置日志和追踪

### ✅ RPC 服务开发

- [ ] 定义 .proto 文件
- [ ] 生成 gRPC 代码
- [ ] 实现 Logic 层
- [ ] 配置服务注册（Etcd/Consul）
- [ ] 添加拦截器
- [ ] 配置超时和重试

### ✅ 微服务治理

- [ ] 配置熔断器参数
- [ ] 设置限流策略
- [ ] 启用自适应降载
- [ ] 配置超时控制
- [ ] 添加链路追踪

### ✅ 生产部署

- [ ] 编写 Dockerfile
- [ ] 配置环境变量
- [ ] 设置健康检查
- [ ] 配置日志收集
- [ ] 设置监控告警
- [ ] 编写 K8s 部署文件

---

## 15. 常见问题

### Q1: 如何调试 RPC 服务？

```bash
# 使用 grpcurl
grpcurl -plaintext localhost:8080 list
grpcurl -plaintext -d '{"name":"test"}' localhost:8080 pkg.Service/Method
```

### Q2: 如何处理跨域？

```go
server := rest.MustNewServer(c, rest.WithCors())
```

### Q3: 如何自定义错误响应？

```go
httpx.SetErrorHandler(func(err error) (int, interface{}) {
    return http.StatusOK, map[string]interface{}{
        "code": 500,
        "msg":  err.Error(),
    }
})
```

### Q4: 如何优雅停机？

```go
server := rest.MustNewServer(c)
defer server.Stop()  // 会等待现有请求处理完毕
```

### Q5: 如何配置 MySQL 连接？

```go
sqlx.NewMysql("user:pass@tcp(host:3306)/db?charset=utf8mb4&parseTime=true")
```

---

## 16. 参考资源

- **官方文档**: https://go-zero.dev
- **GitHub**: https://github.com/zeromicro/go-zero
- **示例仓库**: https://github.com/zeromicro/zero-examples
- **在线教程**:
  - [快速构建微服务](https://github.com/zeromicro/zero-doc/blob/main/doc/shorturl.md)
  - [多RPC微服务](https://github.com/zeromicro/zero-doc/blob/main/docs/zero/bookstore.md)

---

## 17. 总结

Go-Zero 是一个功能强大、设计优雅的微服务框架，具有以下核心优势：

1. **开箱即用**：内建熔断、限流、降载等治理能力
2. **高性能**：经过千万级日活验证
3. **开发效率高**：goctl 自动生成代码
4. **可维护性好**：标准化的项目结构
5. **生态完善**：支持多种服务发现、追踪方案

通过本文档，你可以快速掌握 Go-Zero 的核心概念和使用方法，在实际项目中参考各个示例快速搭建高可用的微服务系统。

---

