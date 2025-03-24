import logging
from fastapi import FastAPI
from app.routes import messages  # Import du routeur


# Configuration du logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# Inclusion des routes du microservice
app.include_router(messages.router) 

 
@app.get('/') 
def read_root(): 
    logger.info(" @app.get('/') : read_root appelée")
    return {'message': 'Hello, DevOps!'} 
