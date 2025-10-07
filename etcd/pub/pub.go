package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/zeromicro/go-zero/core/discov"
)

var value = flag.String("v", "value", "the value")
var etcdHosts = flag.String("etcd", "etcd.discovery:2379", "etcd hosts, comma separated")

func main() {
	flag.Parse()

	// 支持从环境变量读取
	hosts := *etcdHosts
	if envHosts := os.Getenv("ETCD_HOSTS"); envHosts != "" {
		hosts = envHosts
	}

	client := discov.NewPublisher(strings.Split(hosts, ","), "028F2C35852D", *value)
	if err := client.KeepAlive(); err != nil {
		log.Fatal(err)
	}
	defer client.Stop()

	for {
		time.Sleep(time.Second)
		fmt.Println(*value)
	}
}
