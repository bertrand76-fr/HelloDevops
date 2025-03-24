from sqlalchemy import Column, String, TIMESTAMP
from app.database import Base
from datetime import datetime, timezone
import socket

class Message(Base):
    __tablename__ = "messages"

    id = Column(String, primary_key=True, index=True)  # ID unique
    content = Column(String, index=True)
    timestamp = Column(TIMESTAMP, default=lambda: datetime.now(timezone.utc))
    server = Column(String, default=socket.gethostname())  # Nom du serveur qui traite