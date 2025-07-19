from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from ..models import prompt as models
from ..schemas import prompt as schemas

router = APIRouter(
    prefix="/api/v1/prompts",
    tags=["prompts"]
)


@router.post("/", response_model=schemas.PromptRead, status_code=201)
def create_prompt(
    prompt: schemas.PromptCreate,
    db: Session = Depends(get_db)
):
    """创建新的提示词项目"""
    db_prompt = models.Prompt(**prompt.dict())
    db.add(db_prompt)
    db.commit()
    db.refresh(db_prompt)
    return db_prompt


@router.get("/", response_model=List[schemas.PromptRead])
def get_prompts(
    skip: int = Query(0, ge=0, description="跳过的记录数"),
    limit: int = Query(100, ge=1, le=100, description="返回的最大记录数"),
    db: Session = Depends(get_db)
):
    """获取提示词项目列表"""
    prompts = db.query(models.Prompt).offset(skip).limit(limit).all()
    return prompts


@router.get("/{prompt_id}", response_model=schemas.PromptReadWithVersions)
def get_prompt(
    prompt_id: int,
    db: Session = Depends(get_db)
):
    """根据ID获取单个提示词项目（包含版本信息）"""
    prompt = db.query(models.Prompt).filter(models.Prompt.id == prompt_id).first()
    if prompt is None:
        raise HTTPException(status_code=404, detail="提示词项目未找到")
    return prompt


@router.put("/{prompt_id}", response_model=schemas.PromptRead)
def update_prompt(
    prompt_id: int,
    prompt_update: schemas.PromptUpdate,
    db: Session = Depends(get_db)
):
    """更新提示词项目"""
    prompt = db.query(models.Prompt).filter(models.Prompt.id == prompt_id).first()
    if prompt is None:
        raise HTTPException(status_code=404, detail="提示词项目未找到")
    
    update_data = prompt_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(prompt, field, value)
    
    db.commit()
    db.refresh(prompt)
    return prompt


@router.delete("/{prompt_id}", status_code=204)
def delete_prompt(
    prompt_id: int,
    db: Session = Depends(get_db)
):
    """删除提示词项目"""
    prompt = db.query(models.Prompt).filter(models.Prompt.id == prompt_id).first()
    if prompt is None:
        raise HTTPException(status_code=404, detail="提示词项目未找到")
    
    db.delete(prompt)
    db.commit()
    return None


@router.post("/{prompt_id}/versions", response_model=schemas.PromptVersionRead, status_code=201)
def create_prompt_version(
    prompt_id: int,
    version: schemas.PromptVersionCreate,
    db: Session = Depends(get_db)
):
    """为指定提示词创建新版本"""
    # 检查提示词是否存在
    prompt = db.query(models.Prompt).filter(models.Prompt.id == prompt_id).first()
    if prompt is None:
        raise HTTPException(status_code=404, detail="提示词项目未找到")
    
    # 计算新版本号
    last_version = db.query(models.PromptVersion).filter(
        models.PromptVersion.prompt_id == prompt_id
    ).order_by(models.PromptVersion.version_number.desc()).first()
    
    new_version_number = 1 if last_version is None else last_version.version_number + 1
    
    # 创建新版本
    db_version = models.PromptVersion(
        prompt_id=prompt_id,
        version_number=new_version_number,
        **version.dict()
    )
    db.add(db_version)
    db.commit()
    db.refresh(db_version)
    return db_version 