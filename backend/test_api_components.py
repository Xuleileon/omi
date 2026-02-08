#!/usr/bin/env python3
"""
Test script to verify API components (LLM, Embedding, etc.)
Run inside Docker: docker exec -it omi-backend-1 python test_api_components.py
"""

import os
import sys
import json
import requests
from datetime import datetime

# Results summary
results = []

def log_result(component: str, status: str, details: str = ""):
    icon = "✅" if status == "OK" else "❌" if status == "FAIL" else "⚠️"
    results.append({"component": component, "status": status, "details": details})
    print(f"{icon} {component}: {status}")
    if details:
        print(f"   Details: {details[:200]}...")


def test_llm_basic():
    """Test basic LLM call"""
    print("\n=== Testing LLM (Basic Call) ===")
    try:
        from utils.llm.clients import llm_medium_experiment
        
        response = llm_medium_experiment.invoke("Say 'Hello World' in Chinese. Reply with only the Chinese text.")
        content = response.content if hasattr(response, 'content') else str(response)
        log_result("LLM Basic", "OK", content)
        return True
    except Exception as e:
        log_result("LLM Basic", "FAIL", str(e))
        return False


def test_llm_structured():
    """Test structured output (the problematic one)"""
    print("\n=== Testing LLM (Structured Output) ===")
    try:
        from utils.llm.clients import llm_medium_experiment, parser
        from langchain_core.prompts import ChatPromptTemplate
        
        prompt_text = """Analyze this text and provide structured output:
Text: "Today I had a meeting with John about the project. We need to submit by Friday."

{format_instructions}"""

        prompt = ChatPromptTemplate.from_messages([('system', prompt_text)])
        chain = prompt | llm_medium_experiment | parser
        
        response = chain.invoke({
            'format_instructions': parser.get_format_instructions(),
        })
        log_result("LLM Structured", "OK", f"title={response.title}, category={response.category}")
        return True
    except Exception as e:
        log_result("LLM Structured", "FAIL", str(e))
        # Try fallback
        print("   Trying plain text fallback...")
        try:
            from utils.llm.clients import llm_medium_experiment
            fallback_response = llm_medium_experiment.invoke(
                """Return a JSON object with: {"title": "Meeting notes", "overview": "test", "emoji": "📝", "category": "work"}"""
            )
            content = fallback_response.content
            data = json.loads(content.strip().replace('```json', '').replace('```', '').strip())
            log_result("LLM Fallback", "OK", f"Parsed: {data}")
            return True
        except Exception as e2:
            log_result("LLM Fallback", "FAIL", str(e2))
        return False


def test_doubao_embedding():
    """Test Doubao embedding API"""
    print("\n=== Testing Doubao Embedding ===")
    try:
        api_key = os.environ.get('DOUBAO_API_KEY', '')
        if not api_key:
            log_result("Doubao Embedding", "SKIP", "DOUBAO_API_KEY not set")
            return None
        
        url = os.environ.get('DOUBAO_EMBEDDING_URL', 'https://ark.cn-beijing.volces.com/api/v3/embeddings/multimodal')
        model = os.environ.get('DOUBAO_EMBEDDING_MODEL', 'doubao-embedding-vision-251215')
        
        response = requests.post(
            url,
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {api_key}'
            },
            json={
                'model': model,
                'input': [{'type': 'text', 'text': 'Hello World'}],
                'dimensions': 1024,
                'encoding_format': 'float'
            },
            timeout=30
        )
        
        data = response.json()
        if response.status_code == 200 and 'data' in data:
            embedding = data['data'].get('embedding', [])
            log_result("Doubao Embedding", "OK", f"Got {len(embedding)}-dim vector")
            return True
        else:
            log_result("Doubao Embedding", "FAIL", f"HTTP {response.status_code}: {data}")
            return False
    except Exception as e:
        log_result("Doubao Embedding", "FAIL", str(e))
        return False


def test_redis():
    """Test Redis connection"""
    print("\n=== Testing Redis ===")
    try:
        from database.redis_db import r
        r.ping()
        log_result("Redis", "OK", "Connection successful")
        return True
    except Exception as e:
        log_result("Redis", "FAIL", str(e))
        return False


def test_firestore():
    """Test Firestore connection"""
    print("\n=== Testing Firestore ===")
    try:
        from database.conversations import db
        # Just verify db object exists and is initialized
        if db:
            log_result("Firestore", "OK", "Client initialized")
            return True
        else:
            log_result("Firestore", "FAIL", "db is None")
            return False
    except Exception as e:
        log_result("Firestore", "FAIL", str(e))
        return False


def test_gcs():
    """Test GCS connection"""
    print("\n=== Testing GCS (Cloud Storage) ===")
    try:
        from utils.other.storage import private_cloud_sync_bucket, storage_client
        
        if not private_cloud_sync_bucket:
            log_result("GCS", "SKIP", "BUCKET_PRIVATE_CLOUD_SYNC not set (disabled)")
            return None
        
        bucket = storage_client.bucket(private_cloud_sync_bucket)
        # Try to check if bucket exists
        bucket.exists()
        log_result("GCS", "OK", f"Bucket '{private_cloud_sync_bucket}' accessible")
        return True
    except Exception as e:
        log_result("GCS", "FAIL", str(e))
        return False


def print_env_vars():
    """Print relevant environment variables"""
    print("\n=== Environment Variables ===")
    env_vars = [
        'OPENAI_API_KEY',
        'OPENAI_API_BASE',
        'ANTHROPIC_API_KEY',
        'DOUBAO_API_KEY',
        'GOOGLE_CLOUD_PROJECT',
        'GCLOUD_PROJECT',
        'BUCKET_PRIVATE_CLOUD_SYNC',
        'REDIS_HOST',
    ]
    for var in env_vars:
        value = os.environ.get(var, '')
        if value:
            # Mask sensitive keys
            if 'KEY' in var or 'TOKEN' in var:
                masked = value[:8] + '...' + value[-4:] if len(value) > 12 else '***'
            else:
                masked = value[:50] + '...' if len(value) > 50 else value
            print(f"  {var}: {masked}")
        else:
            print(f"  {var}: (not set)")


def main():
    print("=" * 60)
    print("Omi Backend API Components Test")
    print(f"Time: {datetime.now().isoformat()}")
    print("=" * 60)
    
    print_env_vars()
    
    # Run tests
    test_firestore()
    test_redis()
    test_gcs()
    test_doubao_embedding()
    test_llm_basic()
    test_llm_structured()
    
    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    ok = sum(1 for r in results if r['status'] == 'OK')
    fail = sum(1 for r in results if r['status'] == 'FAIL')
    skip = sum(1 for r in results if r['status'] == 'SKIP')
    print(f"✅ OK: {ok}  ❌ FAIL: {fail}  ⚠️ SKIP: {skip}")
    
    if fail > 0:
        print("\nFailed components:")
        for r in results:
            if r['status'] == 'FAIL':
                print(f"  - {r['component']}: {r['details'][:100]}")


if __name__ == "__main__":
    main()
