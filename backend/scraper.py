import requests
from bs4 import BeautifulSoup
import pykakasi
import re
import json
import sys
import html
import logging
import itertools # Нужно для чередования списков
from urllib.parse import urljoin, quote_plus

# Настройка логирования
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

class Romanizer:
    def __init__(self):
        self.kks = pykakasi.kakasi()
        self.kks.setMode("H", "a") 
        self.kks.setMode("K", "a") 
        self.kks.setMode("J", "a") 
        self.kks.setMode("r", "Hepburn") 
        self.converter = self.kks.getConverter()
        # Компилируем регулярку один раз при инициализации
        # Диапазоны: Hiragana, Katakana, CJK Unified Ideographs, Hangul
        self.cjk_pattern = re.compile(r'[\u3040-\u30ff\u4e00-\u9fff\uac00-\ud7af]')

    def contains_cjk(self, text):
        return bool(self.cjk_pattern.search(text))

    def romanize_chordpro_line(self, line):
        # Оптимизация: если нет азиатских символов, возвращаем пустоту
        if not self.contains_cjk(line):
            return ""

        pattern = r'(\{.*?\})'
        parts = re.split(pattern, line)
        processed_parts = []
        for part in parts:
            if re.match(pattern, part):
                processed_parts.append(part)
            else:
                if part.strip():
                    rom = self.converter.do(part).strip()
                    processed_parts.append(rom)
                else:
                    processed_parts.append(part)
        return "".join(processed_parts)
    def __init__(self):
        self.kks = pykakasi.kakasi()
        self.kks.setMode("H", "a") 
        self.kks.setMode("K", "a") 
        self.kks.setMode("J", "a") 
        self.kks.setMode("r", "Hepburn") 
        self.converter = self.kks.getConverter()

    def romanize_chordpro_line(self, line):
        pattern = r'(\{.*?\})'
        parts = re.split(pattern, line)
        processed_parts = []
        for part in parts:
            if re.match(pattern, part):
                processed_parts.append(part)
            else:
                if part.strip():
                    rom = self.converter.do(part).strip()
                    processed_parts.append(rom)
                else:
                    processed_parts.append(part)
        return "".join(processed_parts)

class Scraper:
    def __init__(self):
        self.romanizer = Romanizer()
        self.session = requests.Session()
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
            'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
            'Accept': 'application/json, text/javascript, */*; q=0.01',
        }
        self.session.headers.update(self.headers)

    def fetch_page(self, url, params=None, extra_headers=None):
        """Универсальный метод для запросов."""
        try:
            headers = self.headers.copy()
            if extra_headers:
                headers.update(extra_headers)
            
            cookies = {'tone': '0'} # tone=0 для MyChords
            
            response = self.session.get(url, params=params, timeout=10, headers=headers, cookies=cookies)
            
            # Если 404, просто возвращаем None, чтобы не крашить флоу
            if response.status_code == 404:
                logging.warning(f"[FETCH] 404 Not Found: {url}")
                return None
                
            response.raise_for_status()
            
            # Автоматически возвращаем JSON для API запросов
            if 'application/json' in response.headers.get('Content-Type', ''):
                return response.json()
            
            response.encoding = response.apparent_encoding 
            return response.text

        except Exception as e:
            logging.error(f"[FETCH] Error: {url} -> {e}")
            return None

    # --- AGGREGATION LOGIC (INTERLEAVING) ---

    def search_songs(self, query):
        """
        Агрегирует результаты, чередуя их: [UG_1, MC_1, UG_2, MC_2, ...]
        """
        print(f"\n[AGGREGATOR] Starting search for: '{query}'")
        
        # 1. Получаем результаты параллельно (ну, последовательно в коде)
        ug_results = []
        try:
            ug_results = self.search_ultimate_guitar_list(query)
            print(f"[AGGREGATOR] UG found {len(ug_results)} items")
        except Exception as e:
            logging.error(f"Error in UG search: {e}")

        mc_results = []
        try:
            mc_results = self._search_mychords_api(query)
            print(f"[AGGREGATOR] MyChords found {len(mc_results)} items")
        except Exception as e:
            logging.error(f"Error in MyChords search: {e}")

        # 2. Interleaving (Чередование)
        combined_results = []
        # zip_longest берет элементы по очереди, заполняя дырки None, если один список короче
        for ug, mc in itertools.zip_longest(ug_results, mc_results):
            if ug: combined_results.append(ug)
            if mc: combined_results.append(mc)
        
        print(f"[AGGREGATOR] Total combined results: {len(combined_results)}")
        return combined_results

    # --- SEARCH IMPLEMENTATIONS ---

    def _search_mychords_api(self, query):
        """
        Поиск через AJAX Autocomplete API.
        Исправлена обработка словаря suggestions.
        """
        base_url = "https://mychords.net"
        api_url = f"{base_url}/ru/ajax/autocomplete"
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
            'X-Requested-With': 'XMLHttpRequest',
            'Referer': 'https://mychords.net/'
        }
        
        params = {'q': query}
        
        # fetch_page вернет dict
        json_response = self.fetch_page(api_url, params=params, extra_headers=headers)
        
        # Проверка на dict, так как API возвращает объект с ключом suggestions
        if not json_response or not isinstance(json_response, dict):
            return []

        # Извлекаем список подсказок
        suggestions = json_response.get('suggestions', [])
        if not suggestions:
            return []

        results = []
        for item in suggestions:
            # Структура: {"value": "Artist - Song", "data": {"url": "...", "group": "Песни"}}
            item_data = item.get('data', {})
            
            # Фильтруем только песни (там бывают Исполнители и Альбомы)
            if item_data.get('group') != 'Песни':
                continue

            full_text = item.get('value', '')
            relative_url = item_data.get('url', '')
            
            if not relative_url or not full_text:
                continue

            if " - " in full_text:
                artist, title = full_text.split(" - ", 1)
            else:
                artist, title = "Unknown", full_text

            results.append({
                "title": title.strip(),
                "artist": artist.strip(),
                "url": urljoin(base_url, relative_url),
                "source_label": "MyChords",
                "source_type": "mc"
            })
            
        return results

    def search_ultimate_guitar_list(self, query):
        """
        Поиск через search.php (UG код без изменений).
        """
        search_url = "https://www.ultimate-guitar.com/search.php"
        params = {
            'search_type': 'title',
            'value': query
        }
        
        html_content = self.fetch_page(search_url, params=params)
        
        if not html_content or isinstance(html_content, dict): 
            return []

        soup = BeautifulSoup(html_content, 'html.parser')
        store_div = soup.find('div', class_='js-store')
        
        if not store_div or not store_div.has_attr('data-content'):
            return []

        output = []
        try:
            raw_json = html.unescape(store_div['data-content'])
            data = json.loads(raw_json)
            
            tabs = data.get('store', {}).get('page', {}).get('data', {}).get('data', {}).get('tabs', [])
            
            if not tabs:
                 tabs = data.get('store', {}).get('page', {}).get('data', {}).get('results', [])

            for item in tabs:
                if not isinstance(item, dict): continue
                
                item_type = item.get('type')
                valid_types = ['Chords', 'Tab']
                is_official = item.get('marketing_type') == 'official'
                
                if item_type in valid_types or is_official:
                    output.append({
                        "title": item.get('song_name'),
                        "artist": item.get('artist_name'),
                        "url": item.get('tab_url'),
                        "source_label": "Ultimate Guitar",
                        "source_type": "ug"
                    })
                    
        except Exception as e:
            logging.error(f"UG Search JSON parsing error: {e}")
            return []

        return output
    def get_top_songs(self):
        """
        Получает список популярных песен с Ultimate Guitar.
        Использует страницу Explore (Top 100).
        """
        print(f"\n[TOP] Fetching popular songs...")
        # type=300 (Chords)
        url = "https://www.ultimate-guitar.com/explore?type=300"
        
        html_content = self.fetch_page(url)
        if not html_content or isinstance(html_content, dict): 
            return []

        soup = BeautifulSoup(html_content, 'html.parser')
        store_div = soup.find('div', class_='js-store')
        
        if not store_div or not store_div.has_attr('data-content'):
            return []

        output = []
        try:
            raw_json = html.unescape(store_div['data-content'])
            data = json.loads(raw_json)
            
            # Путь для страницы Explore: store -> page -> data -> data -> tabs
            tabs = data.get('store', {}).get('page', {}).get('data', {}).get('data', {}).get('tabs', [])
            
            # Если там пусто, пробуем альтернативный путь (иногда бывает results)
            if not tabs:
                tabs = data.get('store', {}).get('page', {}).get('data', {}).get('results', [])

            for item in tabs:
                if not isinstance(item, dict): continue
                
                # Здесь можно не фильтровать так жестко, так как это уже чарт,
                # но убедимся, что это аккорды
                if item.get('type') == 'Chords' or item.get('marketing_type') == 'official':
                    output.append({
                        "title": item.get('song_name'),
                        "artist": item.get('artist_name'),
                        "url": item.get('tab_url'),
                        "source_label": "Ultimate Guitar",
                        "source_type": "ug"
                    })
            
            print(f"[TOP] Found {len(output)} popular songs")
            return output

        except Exception as e:
            logging.error(f"[TOP] Error parsing top songs: {e}")
            return []

    # --- PARSERS ---

    def parse_ultimate_guitar(self, url):
        html_content = self.fetch_page(url)
        if not html_content: return None # Обработка 404/ошибок
        
        soup = BeautifulSoup(html_content, 'html.parser')
        store_div = soup.find('div', class_='js-store')
        if not store_div: return None
        
        try:
            data = json.loads(html.unescape(store_div['data-content']))
            page_data = data.get('store', {}).get('page', {}).get('data', {})
            wiki_tab = page_data.get('tab_view', {}).get('wiki_tab', {})
            content = wiki_tab.get('content', '')
            
            title = page_data.get('tab', {}).get('song_name', 'Unknown')
            artist = page_data.get('tab', {}).get('artist_name', 'Unknown')

            if not content: return None

            content = re.sub(r'\[ch\](.*?)\[/ch\]', r'{\1}', content)
            content = content.replace('[tab]', '').replace('[/tab]', '')

            lines = []
            for line in content.split('\n'):
                lines.append({
                    "original": line.rstrip(),
                    "romaji": self.romanizer.romanize_chordpro_line(line.rstrip())
                })
            return {"title": title, "artist": artist, "lines": lines}
        except:
            return None

    def parse_mychords(self, url):
        mc_headers = {'Referer': 'https://mychords.net/'}
        html_content = self.fetch_page(url, extra_headers=mc_headers)
        if not html_content: return None # Обработка 404/ошибок
        
        soup = BeautifulSoup(html_content, 'html.parser')
        
        title_tag = soup.find('title')
        if not title_tag: return None # Если HTML битый

        page_title = title_tag.get_text()
        if " - " in page_title:
            parts = page_title.split(" - ")
            artist, title = parts[0].strip(), parts[1].split(",")[0].strip()
        else:
            artist, title = "Unknown", "Unknown"

        container = soup.find('div', itemprop='text')
        lines = []
        if container:
            for row in container.find_all('div', recursive=False):
                line_str = ""
                if 'single-line' in row.get('class', []):
                    line_str = row.get_text(strip=True)
                elif 'pline' in row.get('class', []):
                    for sub in row.find_all(class_='subline'):
                        for el in sub.contents:
                            if el.name == 'span' and 'b-accord__symbol' in el.get('class', []):
                                line_str += f"{{{el.get_text(strip=True)}}}"
                            elif isinstance(el, str): line_str += el
                            elif el.name: line_str += el.get_text()
                
                clean = line_str.replace('\xa0', ' ').strip()
                if clean:
                    lines.append({"original": clean, "romaji": self.romanizer.romanize_chordpro_line(clean)})
                elif lines and lines[-1]['original'] != "":
                    lines.append({"original": "", "romaji": ""})
        
        return {"title": title, "artist": artist, "lines": lines}

if __name__ == "__main__":
    scraper = Scraper()
    # Тест на чередование
    # Можно передать что-то популярное, чтобы оба источника ответили
    res = scraper.search_songs("Metallica")
    for r in res:
        print(f"[{r['source_label']}] {r['title']}")