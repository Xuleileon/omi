#!/usr/bin/env python3
"""Test memory and conversation processing flow"""
import asyncio
from datetime import datetime, timezone

def test_memory_retrieval():
    """Test retrieving memories from database"""
    try:
        import database.memories as memories_db
        uid = 'boU94OY9PDPskGgJhBFn9MwvOlB3'
        memories = memories_db.get_memories(uid, limit=10)
        print(f"   Firestore memories: {len(memories)} found")
        return True
    except Exception as e:
        print(f"   ERROR: {e}")
        return False

def test_vector_search():
    """Test vector search in Pinecone"""
    try:
        from database.vector_db import query_vectors_by_metadata
        uid = 'boU94OY9PDPskGgJhBFn9MwvOlB3'
        # Search with a simple query
        results = query_vectors_by_metadata(
            uid=uid,
            vector=[0.1] * 1024,  # Dummy vector
            dates_filter=[],
            people=[],
            topics=[],
            entities=[],
            limit=5
        )
        print(f"   Vector search: {len(results)} results")
        return True
    except Exception as e:
        print(f"   ERROR: {e}")
        return False

def test_conversation_retrieval():
    """Test retrieving conversations"""
    try:
        import database.conversations as conversations_db
        uid = 'boU94OY9PDPskGgJhBFn9MwvOlB3'
        conversations = conversations_db.get_conversations(uid, limit=5)
        print(f"   Conversations: {len(conversations)} found")
        return True
    except Exception as e:
        print(f"   ERROR: {e}")
        return False

async def test_memory_extraction():
    """Test memory extraction from conversation"""
    try:
        from utils.llm.conversation_processing import _extract_memories
        test_transcript = """
        User: I work at Google as a software engineer.
        User: I live in San Francisco.
        User: My favorite food is sushi.
        """
        
        # This will call LLM to extract facts
        memories = await _extract_memories(test_transcript, [])
        print(f"   Memory extraction: {len(memories) if memories else 0} memories extracted")
        if memories:
            for m in memories[:3]:
                print(f"      - {m.get('content', m)[:50]}...")
        return True
    except Exception as e:
        print(f"   ERROR: {e}")
        return False

if __name__ == "__main__":
    print("=" * 50)
    print("记忆和对话功能测试")
    print("=" * 50)
    
    print("\n1. 记忆检索 (Firestore):")
    test_memory_retrieval()
    
    print("\n2. 向量搜索 (Pinecone):")
    test_vector_search()
    
    print("\n3. 对话检索:")
    test_conversation_retrieval()
    
    print("\n4. 记忆提取 (LLM):")
    asyncio.run(test_memory_extraction())
    
    print("\n" + "=" * 50)
