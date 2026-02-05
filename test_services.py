#!/usr/bin/env python3
"""Test external services connectivity"""
import os
import requests

def test_deepgram():
    """Test Deepgram STT API"""
    key = os.environ.get('DEEPGRAM_API_KEY')
    if not key:
        return "NOT CONFIGURED"
    try:
        headers = {'Authorization': f'Token {key}'}
        resp = requests.get('https://api.deepgram.com/v1/projects', headers=headers, timeout=10)
        if resp.status_code == 200:
            return "OK"
        return f"FAILED ({resp.status_code})"
    except Exception as e:
        return f"ERROR: {e}"

def test_pinecone():
    """Test Pinecone vector DB"""
    key = os.environ.get('PINECONE_API_KEY')
    index_name = os.environ.get('PINECONE_INDEX_NAME', 'omi-memories')
    if not key:
        return "NOT CONFIGURED"
    try:
        headers = {'Api-Key': key}
        resp = requests.get('https://api.pinecone.io/indexes', headers=headers, timeout=10)
        if resp.status_code == 200:
            indexes = resp.json().get('indexes', [])
            has_index = any(idx.get('name') == index_name for idx in indexes)
            return f"OK (index '{index_name}' {'found' if has_index else 'NOT found'})"
        return f"FAILED ({resp.status_code})"
    except Exception as e:
        return f"ERROR: {e}"

def test_redis():
    """Test Redis connection"""
    try:
        from database.redis_db import r
        r.ping()
        return "OK"
    except Exception as e:
        return f"ERROR: {e}"

def test_firestore():
    """Test Firestore connection"""
    try:
        from google.cloud import firestore
        db = firestore.Client()
        # Try to list collections (lightweight operation)
        collections = list(db.collections())
        return f"OK ({len(collections)} collections)"
    except Exception as e:
        return f"ERROR: {e}"

if __name__ == "__main__":
    print("=" * 50)
    print("Omi 服务连接测试")
    print("=" * 50)
    print(f"1. Deepgram (语音转文字): {test_deepgram()}")
    print(f"2. Pinecone (记忆向量库): {test_pinecone()}")
    print(f"3. Redis (缓存): {test_redis()}")
    print(f"4. Firestore (数据库): {test_firestore()}")
    print("=" * 50)
