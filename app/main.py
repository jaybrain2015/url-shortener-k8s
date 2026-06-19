from fastapi import FastAPI, HTTPException
from fastapi.responses import RedirectResponse
from sqlmodel import SQLModel, Field, Session, create_engine, select
import secrets
import redis
import os


cache = redis.Redis(host="redis", port=6379, decode_responses=True)

class URL(SQLModel, table=True):
    short_code: str = Field(primary_key=True)
    long_url: str


DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///urls.db")
engine = create_engine(DATABASE_URL)  


def create_db_and_table():
    SQLModel.metadata.create_all(engine)

app = FastAPI()

@app.on_event("startup")
def on_startup():
    create_db_and_table()




@app.get("/")
def health_check():
    return {"status": "ok"}



@app.post("/shorten")
def shorten_url(long_url: str):
    short_code = secrets.token_urlsafe(4)
    new_url = URL(short_code=short_code, long_url=long_url)
    with Session(engine) as session:
        session.add(new_url)
        session.commit()
    return {"short_code": short_code, "long_url": long_url}


@app.get("/{short_code}")
def redirect_to_url(short_code: str):

    cached_url = cache.get(short_code)
    if cached_url:
        print(f"CACHE HIT for {short_code}")
        return RedirectResponse(url=cached_url)
    
    print(f"CACHE MISS for {short_code} — reading database")
    with Session(engine) as session:
        url = session.get(URL, short_code)
        if url is None:
            raise HTTPException(status_code=404, detail="Short code not found")
        cache.set(short_code, url.long_url)
        return RedirectResponse(url=url.long_url)