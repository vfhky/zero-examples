package logic

import (
	"bookstore/api/internal/svc"
	"bookstore/api/internal/types"
	"bookstore/rpc/add/adder"
	"context"
	"encoding/json"

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
	// 构建RPC请求
	rpcReq := &adder.AddReq{
		Book:  req.Book,
		Price: req.Price,
	}

	// 记录RPC请求数据
	rpcReqData, _ := json.Marshal(rpcReq)
	l.Infof("AddLogic call RPC request: %s", string(rpcReqData))

	resp, err := l.svcCtx.Adder.Add(l.ctx, rpcReq)
	if err != nil {
		// 记录RPC调用失败
		l.Errorf("AddLogic call RPC failed, error: %v", err)
		return nil, err
	}

	// 记录RPC响应数据
	rpcRespData, _ := json.Marshal(resp)
	l.Infof("AddLogic call RPC response: %s", string(rpcRespData))

	return &types.AddResp{
		Ok: resp.Ok,
	}, nil
}
