from sqlalchemy import Column, String, TIMESTAMP
from app.database import Base
import datetime
import socket

class Message(Base):
    __tablename__ = "messages"

    id = Column(String, primary_key=True, index=True)  # ID unique
    content = Column(String, index=True)
    timestamp = Column(TIMESTAMP, default=datetime.datetime.now(datetime.UTC))
    server = Column(String, default=socket.gethostname())  # Nom du serveur qui traite