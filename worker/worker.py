from pymongo import MongoClient
import time
import os
from datetime import datetime

# Read MongoDB URI from environment variable
MONGO_URI = os.environ.get("MONGO_URI", "mongodb://mongo-service:27017/appdb")
client = MongoClient(MONGO_URI)
db = client["appdb"]

print("Worker started — writing heartbeat to MongoDB every 10 seconds")

# Infinite loop — this is intentional
# The worker runs forever as a background service
while True:
    db["heartbeats"].insert_one({
        "timestamp": datetime.utcnow().isoformat()
    })
    print(f"Heartbeat written at {datetime.utcnow().isoformat()}")
    time.sleep(10)
