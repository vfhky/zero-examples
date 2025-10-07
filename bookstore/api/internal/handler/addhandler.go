package handler

import (
	"bookstore/api/internal/logic"
	"bookstore/api/internal/svc"
	"bookstore/api/internal/types"
	"encoding/json"
	"net/http"

	"github.com/zeromicro/go-zero/core/logx"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func AddHandler(ctx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// 获取客户端IP
		clientIP := httpx.GetRemoteAddr(r)

		var req types.AddReq
		if err := httpx.Parse(r, &req); err != nil {
			// 记录请求解析失败
			logx.WithContext(r.Context()).Errorf("[%s] AddHandler parse request failed, error: %v", clientIP, err)
			httpx.Error(w, err)
			return
		}

		// 记录请求数据（包含客户端IP）
		reqData, _ := json.Marshal(req)
		logx.WithContext(r.Context()).Infof("[%s] AddHandler request: %s", clientIP, string(reqData))

		l := logic.NewAddLogic(r.Context(), ctx)
		resp, err := l.Add(req)
		if err != nil {
			// 记录错误响应
			logx.WithContext(r.Context()).Errorf("[%s] AddHandler response error: %v", clientIP, err)
			httpx.Error(w, err)
		} else {
			// 记录成功响应（包含客户端IP）
			respData, _ := json.Marshal(resp)
			logx.WithContext(r.Context()).Infof("[%s] AddHandler response: %s", clientIP, string(respData))
			httpx.WriteJson(w, http.StatusOK, resp)
		}
	}
}
