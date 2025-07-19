from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from ..models import prompt as models
from ..schemas import prompt as schemas

router = APIRouter(
    prefix="/api/v1/versions",
    tags=["versions"]
)


@router.get("/{version_id}", response_model=schemas.PromptVersionReadWithResults)
def get_version(
    version_id: int,
    db: Session = Depends(get_db)
):
    """根据ID获取单个提示词版本（包含结果）"""
    version = db.query(models.PromptVersion).filter(
        models.PromptVersion.id == version_id
    ).first()
    if version is None:
        raise HTTPException(status_code=404, detail="版本未找到")
    return version


@router.post("/{version_id}/results", response_model=schemas.OptimizationResultRead, status_code=201)
def create_result(
    version_id: int,
    result: schemas.OptimizationResultCreate,
    db: Session = Depends(get_db)
):
    """为指定版本创建优化结果"""
    # 检查版本是否存在
    version = db.query(models.PromptVersion).filter(
        models.PromptVersion.id == version_id
    ).first()
    if version is None:
        raise HTTPException(status_code=404, detail="版本未找到")
    
    # 创建结果
    db_result = models.OptimizationResult(
        version_id=version_id,
        **result.dict()
    )
    db.add(db_result)
    db.commit()
    db.refresh(db_result)
    return db_result


@router.get("/{version_id}/results", response_model=List[schemas.OptimizationResultRead])
def get_version_results(
    version_id: int,
    db: Session = Depends(get_db)
):
    """获取指定版本的所有结果"""
    # 检查版本是否存在
    version = db.query(models.PromptVersion).filter(
        models.PromptVersion.id == version_id
    ).first()
    if version is None:
        raise HTTPException(status_code=404, detail="版本未找到")
    
    results = db.query(models.OptimizationResult).filter(
        models.OptimizationResult.version_id == version_id
    ).all()
    return results 