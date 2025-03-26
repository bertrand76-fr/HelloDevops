import os
import logging

from fastapi import FastAPI
from app.routes import messages  # ton routeur

# ===========================================
# 🔧 Configuration du logger avec AppInsights
# ===========================================
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Affiche toujours dans la console (stdout)
console_handler = logging.StreamHandler()
logger.addHandler(console_handler)

# Tente d'ajouter AzureLogHandler
try:
    from opencensus.ext.azure.log_exporter import AzureLogHandler # type: ignore
    instrumentation_key = os.getenv("APPINSIGHTS_INSTRUMENTATIONKEY")

    if instrumentation_key:
        azure_handler = AzureLogHandler(
            connection_string=f"InstrumentationKey={instrumentation_key}"
        )
        logger.addHandler(azure_handler)
        logger.info("✅ AzureLogHandler activé pour Application Insights")
    else:
        logger.warning("⚠️ Clé App Insights manquante dans les variables d’environnement")

except ImportError as e:
    logger.warning(f"⚠️ Impossible d'importer AzureLogHandler : {e}")

# ===========================
# 🚀 Application FastAPI
# ===========================
app = FastAPI()
app.include_router(messages.router)

@app.get("/")
def read_root():
    logger.info("📥 GET / appelée avec succès")
    return {"message": "Hello, DevOps!"}
