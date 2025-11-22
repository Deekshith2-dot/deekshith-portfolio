# GenAI & Mobile Portfolio — Deekshith Chakilam

This repo contains portfolio projects combining mobile (Flutter) and GenAI (RAG, embeddings, LLMs).

## Quick highlights
- **Chat-with-PDF (RAG)** — OCR → Chunk → Embeddings → FAISS → LLM (Groq)
- **LLM Chatbot** — multi-turn chat using Groq LLMs
- **RAG Demo** — FAISS + sentence-transformers example
- **Flutter apps** — demo clones and UI samples
- **Java Web** — password generator (servlet + MySQL)

## Demo resume used for local testing (do not commit private resume publicly)
Local demo resume path (on this machine): /mnt/data/eeb4c4c0-3f47-4a56-b2de-c5153971cf94.pdf

## How to run the Chat-with-PDF demo (quick)
1. Create venv and install:
   ```bash
   python -m venv venv
   source venv/bin/activate   # Windows: venv\Scripts\activate
   pip install -r projects/chat-with-pdf/requirements.txt
   ```
2. Set your Groq API key (optional; useful for LLM answers):
   ```bash
   set GROQ_API_KEY=your_key_here
   set MODEL_NAME=llama-3.1-8b-instant
   ```
3. Put a PDF into `projects/chat-with-pdf/sample_data/` or use the repo demo path.
4. Run:
   ```bash
   python projects/chat-with-pdf/ocr_pdf_reader.py
   python projects/chat-with-pdf/chat_with_pdf.py
   ```

## Contact
LinkedIn: YOUR_LINKEDIN
Email: your.email@example.com
