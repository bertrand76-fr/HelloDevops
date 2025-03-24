from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
import uuid

from app.database import get_db
from app.models import Message

router = APIRouter()

#  Définition du schéma pour les requêtes POST avec Pydantic
class MessageCreate(BaseModel):
    content: str

import logging
logger = logging.getLogger(__name__)

# `POST /store` → Ajouter un message en base
@router.post("/store")
def store_message(message: MessageCreate, db: Session = Depends(get_db)):
    logger.info(" @router.post(\"/store\") : store_message appelé")
    unique_id = str(uuid.uuid4())
    new_message = Message(id=unique_id, content=message.content)
    db.add(new_message)
    db.commit()
    return {"message": "Stored successfully", "id": unique_id}

# `GET /getAll` → Récupérer tous les messages
@router.get("/getAll")
def get_all_messages(db: Session = Depends(get_db)):
    logger.info(" @router.get(\"/getAll\") : get_all_messages appelée")
    return db.query(Message).all()

# `GET /getById/{id}` → Récupérer un message spécifique
@router.get("/getById/{id}")
def get_by_id(id: str, db: Session = Depends(get_db)):
    logger.info(" @router.get(\"/getById/" + id + "\") : get_by_id appelé" )
    message = db.query(Message).filter(Message.id == id).first()
    if message:
        return message
    raise HTTPException(status_code=404, detail=f"Message with id {id} not found")

# ✅ `DELETE /deleteById/{id}` → Supprimer un message
@router.delete("/deleteById/{id}")
def delete_by_id(id: str, db: Session = Depends(get_db)):
    logger.info(" @router.delete(\"/deleteById/" + id +"\") : delete_by_id appelé")
    message = db.query(Message).filter(Message.id == id).first()
    if message:
        db.delete(message)
        db.commit()
        return {"message": f"Message with id {id} deleted successfully"}
    raise HTTPException(status_code=404, detail=f"Message with id {id} not found")


# `DELETE /deleteAll` → Supprimer tous les messages
@router.delete("/deleteAll")
def delete_all_messages(db: Session = Depends(get_db)):
    """ Supprime tous les messages de la base """
    try:
        logger.info(" @router.delete(\"/deleteAll\") : delete_all_messages appelé")
        deleted_count = db.query(Message).delete()
        db.commit()
        return {"message": f"{deleted_count} messages supprimés"}
    except Exception as e:
        db.rollback()
        return {"error": f"Échec de la suppression : {str(e)}"}
		
		