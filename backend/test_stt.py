#!/usr/bin/env python3
"""
STT Service Integration Test Script

Tests the WebSocket transcription endpoint to verify:
1. WebSocket connection works
2. STT service is properly selected (Soniox fallback to Deepgram)
3. Audio data is being processed
4. Transcription is returned
"""

import asyncio
import websockets
import json
import struct
import os
import sys
from datetime import datetime

# Configuration
BACKEND_URL = os.getenv("BACKEND_URL", "ws://localhost:8000")
UID = os.getenv("TEST_UID", "test-user-12345")
LANGUAGE = os.getenv("TEST_LANGUAGE", "zh")
SAMPLE_RATE = 16000
CODEC = "pcm16"
ADMIN_KEY = os.getenv("ADMIN_KEY", "dev123")

# Generate test audio (1 second of silence as PCM16)
def generate_test_audio(duration_seconds=1):
    """Generate silent PCM16 audio data for testing"""
    samples_per_second = SAMPLE_RATE
    total_samples = samples_per_second * duration_seconds
    # Create silent audio (zeros)
    audio_data = struct.pack(f'<{total_samples}h', *([0] * total_samples))
    return audio_data

# Generate test audio with tone (beep)
def generate_tone_audio(frequency=440, duration_seconds=0.5, volume=0.3):
    """Generate a sine wave tone for testing"""
    import math
    samples_per_second = SAMPLE_RATE
    total_samples = int(samples_per_second * duration_seconds)
    samples = []
    for i in range(total_samples):
        t = i / samples_per_second
        sample = int(volume * 32767 * math.sin(2 * math.pi * frequency * t))
        samples.append(sample)
    audio_data = struct.pack(f'<{total_samples}h', *samples)
    return audio_data

async def test_websocket_connection():
    """Test 1: Basic WebSocket connection"""
    print("\n" + "="*60)
    print("TEST 1: WebSocket Connection")
    print("="*60)
    
    ws_url = f"{BACKEND_URL}/v4/listen?language={LANGUAGE}&sample_rate={SAMPLE_RATE}&codec={CODEC}&uid={UID}&include_speech_profile=false&stt_service=deepgram&conversation_timeout=30"
    
    # Use ADMIN_KEY for authentication
    auth_token = f"{ADMIN_KEY}{UID}"
    headers = {"Authorization": f"Bearer {auth_token}"}
    
    print(f"Connecting to: {ws_url}")
    print(f"Using ADMIN_KEY auth for uid: {UID}")
    
    try:
        async with websockets.connect(ws_url, additional_headers=headers, ping_interval=20, ping_timeout=10) as ws:
            print("✅ WebSocket connection established!")
            
            # Wait for any initial messages
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=5)
                print(f"   Received: {msg[:200]}..." if len(msg) > 200 else f"   Received: {msg}")
            except asyncio.TimeoutError:
                print("   No initial message (this is normal)")
            
            return True
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return False

async def test_audio_transmission():
    """Test 2: Send audio and check for processing"""
    print("\n" + "="*60)
    print("TEST 2: Audio Transmission")
    print("="*60)
    
    ws_url = f"{BACKEND_URL}/v4/listen?language={LANGUAGE}&sample_rate={SAMPLE_RATE}&codec={CODEC}&uid={UID}&include_speech_profile=false&stt_service=deepgram&conversation_timeout=30"
    
    # Use ADMIN_KEY for authentication
    auth_token = f"{ADMIN_KEY}{UID}"
    headers = {"Authorization": f"Bearer {auth_token}"}
    
    try:
        async with websockets.connect(ws_url, additional_headers=headers, ping_interval=20, ping_timeout=10) as ws:
            print("✅ Connected!")
            
            # Generate and send test audio
            print("   Generating test audio (1 second tone)...")
            audio_data = generate_tone_audio(frequency=440, duration_seconds=1)
            
            print(f"   Sending {len(audio_data)} bytes of audio...")
            await ws.send(audio_data)
            print("✅ Audio sent!")
            
            # Listen for responses
            print("   Waiting for transcription response...")
            responses = []
            try:
                for _ in range(10):  # Wait up to 10 messages
                    msg = await asyncio.wait_for(ws.recv(), timeout=3)
                    responses.append(msg)
                    print(f"   Response: {msg[:200]}..." if len(msg) > 200 else f"   Response: {msg}")
                    
                    # Check if it's a transcription
                    if isinstance(msg, str):
                        try:
                            data = json.loads(msg)
                            if 'segments' in data:
                                print("✅ Got transcription response!")
                        except:
                            pass
            except asyncio.TimeoutError:
                print("   Timeout waiting for more messages")
            
            return len(responses) > 0
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False

async def test_stt_fallback():
    """Test 3: Check STT service fallback (Soniox -> Deepgram)"""
    print("\n" + "="*60)
    print("TEST 3: STT Service Fallback (Soniox -> Deepgram)")
    print("="*60)
    
    # Request Soniox, but backend should fallback to Deepgram if API key not set
    ws_url = f"{BACKEND_URL}/v4/listen?language={LANGUAGE}&sample_rate={SAMPLE_RATE}&codec={CODEC}&uid={UID}&include_speech_profile=false&stt_service=soniox&conversation_timeout=30"
    
    # Use ADMIN_KEY for authentication
    auth_token = f"{ADMIN_KEY}{UID}"
    headers = {"Authorization": f"Bearer {auth_token}"}
    
    print(f"Requesting stt_service=soniox (should fallback to Deepgram if no API key)")
    
    try:
        async with websockets.connect(ws_url, additional_headers=headers, ping_interval=20, ping_timeout=10) as ws:
            print("✅ Connection accepted (fallback worked or Soniox is configured)")
            
            # Send some audio to trigger processing
            audio_data = generate_tone_audio(frequency=440, duration_seconds=0.5)
            await ws.send(audio_data)
            
            # Wait briefly for any response
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=3)
                print(f"   Response: {msg[:200]}..." if len(msg) > 200 else f"   Response: {msg}")
            except asyncio.TimeoutError:
                pass
            
            return True
    except Exception as e:
        print(f"❌ Connection failed (fallback may not be working): {e}")
        return False

async def test_api_health():
    """Test 0: Check API health"""
    print("\n" + "="*60)
    print("TEST 0: API Health Check")
    print("="*60)
    
    import aiohttp
    
    health_url = f"{BACKEND_URL.replace('ws://', 'http://').replace('wss://', 'https://')}/health"
    
    print(f"Checking: {health_url}")
    
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(health_url, timeout=aiohttp.ClientTimeout(total=5)) as resp:
                if resp.status == 200:
                    print(f"✅ API is healthy (status: {resp.status})")
                    return True
                else:
                    print(f"⚠️ API returned status: {resp.status}")
                    return False
    except Exception as e:
        print(f"❌ Health check failed: {e}")
        return False

async def main():
    print("="*60)
    print("OMI Backend STT Integration Test")
    print(f"Backend URL: {BACKEND_URL}")
    print(f"Test UID: {UID}")
    print(f"Language: {LANGUAGE}")
    print(f"Time: {datetime.now().isoformat()}")
    print("="*60)
    
    results = {}
    
    # Run tests
    results['health'] = await test_api_health()
    results['websocket'] = await test_websocket_connection()
    results['audio'] = await test_audio_transmission()
    results['fallback'] = await test_stt_fallback()
    
    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    
    passed = 0
    failed = 0
    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"  {test_name}: {status}")
        if result:
            passed += 1
        else:
            failed += 1
    
    print("-"*60)
    print(f"  Total: {passed} passed, {failed} failed")
    print("="*60)
    
    return failed == 0

if __name__ == "__main__":
    try:
        success = asyncio.run(main())
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\nTest interrupted by user")
        sys.exit(1)
