GenAI & Mobile Portfolio — Deekshith Chakilam

A curated portfolio showcasing my projects in Generative AI, RAG systems, Embeddings, LLMs, and Flutter mobile development.
This repo includes full-stack AI applications, backend services, and production-ready mobile apps.

🚀 Portfolio Highlights
1️⃣ GenAI RAG Chat Assistant (Flutter + FastAPI + Groq)

A complete mobile + backend AI system.

Features

Upload PDFs from Flutter

Backend extracts text → chunking → embeddings (MiniLM)

Vector search using FAISS

RAG answers grounded in uploaded documents

Auto fallback to general LLM when document is not relevant

Works on real Android devices

Backend deployed on Render

Tech Stack

Flutter

FastAPI

Python

Groq LLM API

Sentence Transformers (MiniLM)

FAISS Vector Search

📁 Folder: projects/genai-rag-chatbot/

2️⃣ Chat-with-PDF (Python RAG demo)

A Python-only demo for learning RAG basics.

What it includes

OCR for scanned PDFs

Text extraction

Chunking + embeddings

FAISS vector search

LLM Q&A with Groq

📁 Folder: projects/chat-with-pdf/

3️⃣ LLM Chatbot (Groq API)

A simple multi-turn CLI chatbot using Groq models.

Features

Conversation history

System prompts

Fast inference via Groq

📁 Folder: projects/llm-chatbot/

4️⃣ RAG Examples / Embeddings / FAISS demos

Hands-on scripts for learning:

Text embeddings

Semantic similarity

FAISS indexing

Cosine similarity scoring

📁 Folder: projects/rag-demos/

5️⃣ Flutter UI Samples

Reusable UI templates built with Flutter:

Chat UI

Components

Mobile layouts

📁 Folder: projects/flutter-ui/

📄 Demo Resume Disclaimer

A sample resume was used only for local testing of PDF → RAG.
⚠️ It is NOT included in the repo for privacy reasons.

Local testing path used during development:

/mnt/data/eeb4c4c0-3f47-4a56-b2de-c5153971cf94.pdf

🧪 How to Run the RAG Chat Assistant (Backend)
cd projects/genai-rag-chatbot/backend
python -m venv venv
venv\Scripts\activate   # Windows
pip install -r requirements.txt


Set API keys:

set GROQ_API_KEY=your_key_here
set MODEL_NAME=llama-3.1-8b-instant


Run:

uvicorn app:app --reload --host 0.0.0.0 --port 8000

📱 How to Run the Flutter Mobile App
cd projects/genai-rag-chatbot/flutter_app
flutter pub get
flutter run --dart-define=BACKEND_BASE=http://<your-ip>:8000


Supports:

Real Android devices

Wi-Fi

adb reverse

APK & Release builds

🌐 Live Deployment

Backend deployed on Render:

(https://vercel-deploy-opv8.onrender.com/)

📬 Contact

LinkedIn: <your-link>

Email: deekshith2.chakilam@gmail.com

GitHub: https://github.com/Deekshith2-dot
