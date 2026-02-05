#!/usr/bin/env python3
"""End-to-end test for chat functionality"""
import asyncio
from datetime import datetime, timezone

# Test the full chat flow
async def test_full_chat():
    from utils.retrieval.graph import execute_graph_chat_stream
    from models.chat import Message, MessageSender
    
    uid = 'boU94OY9PDPskGgJhBFn9MwvOlB3'
    
    # Create test message
    msg = Message(
        id='test-e2e-123',
        text='Hello, how are you?',
        created_at=datetime.now(timezone.utc),
        sender=MessageSender.human,
        type='text',
    )
    
    print(f"Testing with message: {msg.text}")
    print("-" * 50)
    
    callback_data = {}
    chunks = []
    
    try:
        async for chunk in execute_graph_chat_stream(uid, [msg], callback_data=callback_data):
            if chunk is None:
                print("\n[END OF STREAM]")
                break
            chunks.append(chunk)
            # Print chunk without newline for streaming effect
            if chunk.startswith("data: "):
                print(chunk[6:], end='', flush=True)
            elif chunk.startswith("think: "):
                print(f"\n[THINKING: {chunk[7:]}]", flush=True)
            else:
                print(f"[CHUNK: {chunk}]", flush=True)
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"\nError during streaming: {type(e).__name__}: {e}")
    
    print("\n" + "-" * 50)
    print(f"Total chunks received: {len(chunks)}")
    
    answer = callback_data.get('answer', '')
    print(f"\nFinal answer: {answer[:200] if answer else '<NO ANSWER>'}")
    
    if answer:
        print("\n✅ Test PASSED - AI responded!")
        return True
    else:
        print("\n❌ Test FAILED - No response received")
        return False

if __name__ == "__main__":
    result = asyncio.run(test_full_chat())
    exit(0 if result else 1)
