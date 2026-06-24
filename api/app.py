from flask import Flask, jsonify, request
from pymongo import MongoClient
from prometheus_flask_exporter import PrometheusMetrics
from flask_cors import CORS
import os

app = Flask(__name__)
CORS(app)  # Allows the frontend container to talk to the API

# Automatically adds a /metrics endpoint for Prometheus to scrape
metrics = PrometheusMetrics(app)

# Reads MongoDB URI from environment variable
MONGO_URI = os.environ.get("MONGO_URI", "mongodb://mongo-service:27017/appdb")
client = MongoClient(MONGO_URI)
db = client["appdb"]
items_collection = db["items"]

# Health check endpoint — Kubernetes liveness probe hits this
@app.route("/health")
def health():
    return jsonify({"status": "ok"}), 200

# Get all items from MongoDB
@app.route("/api/items", methods=["GET"])
def get_items():
    items = list(items_collection.find({}, {"_id": 0}))
    return jsonify(items), 200

# Add a new item to MongoDB
@app.route("/api/items", methods=["POST"])
def add_item():
    data = request.get_json()
    if not data or "name" not in data:
        return jsonify({"error": "name field required"}), 400
    items_collection.insert_one({"name": data["name"]})
    return jsonify({"message": "Item added"}), 201

# Get a single item by name
@app.route("/api/items/<name>", methods=["GET"])
def get_item(name):
    item = items_collection.find_one({"name": name}, {"_id": 0})
    if not item:
        return jsonify({"error": "Item not found"}), 404
    return jsonify(item), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
