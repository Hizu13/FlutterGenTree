from sqlalchemy import create_engine, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os
import socket
from dotenv import load_dotenv

load_dotenv()

def get_local_ip():
    try:
        # Tự động lấy IP mạng cục bộ của máy
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

# Đọc cấu hình từ .env
raw_url = os.getenv("MYSQL_URL")

if not raw_url:
    raw_url = "mysql+pymysql://root:@127.0.0.1:3306/family_tree_db"

# Tách tên database và URL cơ sở
if "/" in raw_url.split("://")[1]:
    parts = raw_url.rsplit("/", 1)
    base_url = parts[0]
    db_name = parts[1]
    if "?" in db_name:
        db_name = db_name.split("?")[0]
else:
    base_url = raw_url
    db_name = "family_tree_db"

# Thử kết nối lần lượt qua localhost, 127.0.0.1 và IP mạng cục bộ
hosts_to_try = ["127.0.0.1", "localhost", get_local_ip()]
connected_url = None

for host in hosts_to_try:
    test_base_url = base_url
    if "127.0.0.1" in base_url:
        test_base_url = base_url.replace("127.0.0.1", host)
    elif "localhost" in base_url:
        test_base_url = base_url.replace("localhost", host)
        
    try:
        # Kết nối tạm thời tới MySQL server để kiểm tra và tạo DB
        temp_engine = create_engine(test_base_url, connect_args={"connect_timeout": 2})
        with temp_engine.connect() as conn:
            conn.execute(text(f"CREATE DATABASE IF NOT EXISTS {db_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"))
        
        connected_url = f"{test_base_url}/{db_name}"
        print(f"[*] MySQL connected OK at {host}, database: {db_name}")
        break
    except Exception as e:
        print(f"[!] MySQL connection failed at {host}: {e}")

if not connected_url:
    # Fallback về mặc định
    connected_url = f"{base_url}/{db_name}"
    print(f"[!] Auto-detect failed. Using default config: {connected_url}")

# Khởi tạo SQLAlchemy Engine chính thức
engine = create_engine(connected_url, pool_pre_ping=True, pool_recycle=3600)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

