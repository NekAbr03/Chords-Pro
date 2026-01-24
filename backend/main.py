from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
import uvicorn
import os
from urllib.parse import urlparse
from typing import List, Dict, Any

from scraper import Scraper

app = FastAPI(title="Nano Chords Scraper API (Final)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

scraper_service = Scraper()

def get_parser_method(url: str):
    domain = urlparse(url).netloc
    if "mychords.net" in domain:
        return scraper_service.parse_mychords
    elif "ultimate-guitar.com" in domain:
        return scraper_service.parse_ultimate_guitar
    else:
        return None

@app.get("/health")
async def health_check():
    return {"status": "ok"}

@app.get("/")
def read_root():
    return {"status": "running"}

@app.get("/search", response_model=List[Dict[str, Any]])
def search_songs(q: str = Query(..., min_length=1)):
    """
    Поиск с чередованием результатов (Interleaving).
    """
    print(f"\n--- API SEARCH: {q} ---")
    results = scraper_service.search_songs(q)
    return results

@app.get("/top", response_model=List[Dict[str, Any]])
def get_top_songs():
    """
    Возвращает список популярных песен (Top 100 с Ultimate Guitar).
    """
    print(f"\n--- API TOP REQUEST ---")
    results = scraper_service.get_top_songs()
    if not results:
        # Не падаем, просто возвращаем пустой список
        print("API: No top songs found.")
        return []
    return results

@app.get("/parse")
def parse_song(url: str = Query(...)):
    """
    Парсинг песни. Возвращает 404, если песня не найдена или недоступна.
    """
    print(f"\n--- API PARSE: {url} ---")
    
    parser_method = get_parser_method(url)
    if not parser_method:
        raise HTTPException(status_code=400, detail="Domain not supported")

    # Вызов парсера
    result = parser_method(url)
    
    # Обработка ситуаций, когда парсер вернул None (404, бан, ошибка парсинга)
    if not result:
        raise HTTPException(status_code=404, detail="Song not found or parsing failed")
        
    return result

# Debug endpoint
@app.get("/debug/html", response_class=HTMLResponse)
def get_debug_html(url: str = Query(...)):
    res = scraper_service.fetch_page(url)
    if not res:
        return "<h1>Error or 404</h1>"
    if isinstance(res, dict) or isinstance(res, list):
        return f"<pre>{res}</pre>"
    return res

if __name__ == "__main__":
    # Render сам назначит порт через переменную окружения PORT
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)