package logic

import (
	"bookstore/rpc/add/internal/svc"
	"bookstore/rpc/model"
	"context"
	"encoding/json"

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
	// 记录RPC请求数据
	reqData, _ := json.Marshal(in)
	l.Infof("Add RPC received request: %s", string(reqData))

	// 构建数据库模型
	book := model.Book{
		Book:  in.Book,
		Price: in.Price,
	}

	// 记录数据库操作
	bookData, _ := json.Marshal(book)
	l.Infof("Add RPC insert into database: %s", string(bookData))

	_, err := l.svcCtx.Model.Insert(book)
	if err != nil {
		// 记录数据库操作失败
		l.Errorf("Add RPC database insert failed, error: %v", err)
		return nil, err
	}

	// 构建响应
	resp := &add.AddResp{
		Ok: true,
	}

	// 记录RPC响应数据
	respData, _ := json.Marshal(resp)
	l.Infof("Add RPC response: %s", string(respData))

	return resp, nil
}
