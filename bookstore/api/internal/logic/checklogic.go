package logic

import (
	"bookstore/api/internal/svc"
	"bookstore/api/internal/types"
	"bookstore/rpc/check/checker"
	"context"
	"encoding/json"

	"github.com/zeromicro/go-zero/core/logx"
)

type CheckLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewCheckLogic(ctx context.Context, svcCtx *svc.ServiceContext) CheckLogic {
	return CheckLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *CheckLogic) Check(req types.CheckReq) (*types.CheckResp, error) {
	// 构建RPC请求
	rpcReq := &checker.CheckReq{
		Book: req.Book,
	}

	// 记录RPC请求数据
	rpcReqData, _ := json.Marshal(rpcReq)
	l.Infof("CheckLogic call RPC request: %s", string(rpcReqData))

	resp, err := l.svcCtx.Checker.Check(l.ctx, rpcReq)
	if err != nil {
		// 记录RPC调用失败
		l.Errorf("CheckLogic call RPC failed, error: %v", err)
		return &types.CheckResp{}, err
	}

	// 记录RPC响应数据
	rpcRespData, _ := json.Marshal(resp)
	l.Infof("CheckLogic call RPC response: %s", string(rpcRespData))

	return &types.CheckResp{
		Found: resp.Found,
		Price: resp.Price,
	}, nil
}
