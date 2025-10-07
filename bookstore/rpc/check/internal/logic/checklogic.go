package logic

import (
	"bookstore/rpc/check/internal/svc"
	"context"
	"encoding/json"

	check "bookstore/rpc/check/checker"

	"github.com/zeromicro/go-zero/core/logx"
)

type CheckLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCheckLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CheckLogic {
	return &CheckLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *CheckLogic) Check(in *check.CheckReq) (*check.CheckResp, error) {
	// 记录RPC请求数据
	reqData, _ := json.Marshal(in)
	l.Infof("Check RPC received request: %s", string(reqData))

	// 记录数据库查询
	l.Infof("Check RPC query database for book: %s", in.Book)

	resp, err := l.svcCtx.Model.FindOne(in.Book)
	if err != nil {
		// 记录数据库查询失败
		l.Errorf("Check RPC database query failed, error: %v", err)
		return nil, err
	}

	// 记录查询结果
	dbData, _ := json.Marshal(resp)
	l.Infof("Check RPC database result: %s", string(dbData))

	// 构建响应
	checkResp := &check.CheckResp{
		Found: true,
		Price: resp.Price,
	}

	// 记录RPC响应数据
	respData, _ := json.Marshal(checkResp)
	l.Infof("Check RPC response: %s", string(respData))

	return checkResp, nil
}
