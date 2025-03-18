from fastapi import FastAPI
from app.routes import messages  # Import du routeur
 
app = FastAPI()

# Inclusion des routes du microservice
app.include_router(messages.router) 

 
@app.get('/') 
def read_root(): 
    return {'message': 'Hello, DevOps!'} 
