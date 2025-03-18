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

# `POST /store` → Ajouter un message en base
@router.post("/store")
def store_message(message: MessageCreate, db: Session = Depends(get_db)):
    #unique_id = f"{socket.gethostname()}-{int(datetime.datetime.utcnow().timestamp())}"
    unique_id = uuid.uuid4()
    new_message = Message(id=unique_id, content=message.content)
    db.add(new_message)
    db.commit()
    return {"message": "Stored successfully", "id": unique_id}

# `GET /getAll` → Récupérer tous les messages
@router.get("/getAll")
def get_all_messages(db: Session = Depends(get_db)):
    return db.query(Message).all()

# `GET /getById/{id}` → Récupérer un message spécifique
@router.get("/getById/{id}")
def get_by_id(id: str, db: Session = Depends(get_db)):
    message = db.query(Message).filter(Message.id == id).first()
    if message:
        return message
    raise HTTPException(status_code=404, detail=f"Message with id {id} not found")

# ✅ `DELETE /deleteById/{id}` → Supprimer un message
@router.delete("/deleteById/{id}")
def delete_by_id(id: str, db: Session = Depends(get_db)):
    message = db.query(Message).filter(Message.id == id).first()
    if message:
        db.delete(message)
        db.commit()
        return {"message": f"Message with id {id} deleted successfully"}
    raise HTTPException(status_code=404, detail=f"Message with id {id} not found")
