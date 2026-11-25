import requests
from django.conf import settings

SYSTEM_PROMPT = (
    "You are a friendly study assistant for university and school students. "
    "Explain concepts step by step with simple examples. "
    "Reply in the same language the student writes in (English, Urdu or Roman Urdu). "
    "Help the student learn and understand; do not just hand over finished assignments."
)


class AIError(Exception):
    pass


def call_gemini(history):
    """history: list of {"role": "user"|"assistant", "content": str}. Returns reply text."""
    if not settings.GEMINI_API_KEY or settings.GEMINI_API_KEY.startswith("yahan_"):
        raise AIError("AI key set nahi hai. backend/.env mein GEMINI_API_KEY likhein.")

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{settings.GEMINI_MODEL}:generateContent"
    payload = {
        "system_instruction": {"parts": [{"text": SYSTEM_PROMPT}]},
        "contents": [
            {"role": "user" if m["role"] == "user" else "model", "parts": [{"text": m["content"]}]}
            for m in history
        ],
    }
    try:
        r = requests.post(url, json=payload, headers={"x-goog-api-key": settings.GEMINI_API_KEY}, timeout=60)
    except requests.RequestException:
        raise AIError("AI service se connect nahi ho saka. Thori der baad try karein.")

    if r.status_code == 429:
        raise AIError("AI ki free limit poori ho gayi hai. Thori der baad try karein.")
    if r.status_code != 200:
        raise AIError(f"AI service ne error diya ({r.status_code}). Key aur model ka naam check karein.")

    try:
        return r.json()["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError, ValueError):
        raise AIError("AI ne jawab nahi diya (shayad content block hua). Sawal badal kar dekhein.")
