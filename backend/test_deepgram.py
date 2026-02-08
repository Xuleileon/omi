#!/usr/bin/env python3
"""
Deepgram STT Direct Test Script

Tests Deepgram API directly to isolate issues:
1. API key validity
2. Connection to Deepgram
3. Audio processing and transcription
4. Chinese language support
"""

import asyncio
import os
import sys
import struct
import math
import time
from datetime import datetime

# Check for deepgram SDK
try:
    from deepgram import DeepgramClient, LiveTranscriptionEvents, LiveOptions
except ImportError:
    print("❌ Deepgram SDK not installed. Run: pip install deepgram-sdk")
    sys.exit(1)

# Configuration
DEEPGRAM_API_KEY = os.getenv("DEEPGRAM_API_KEY", "")
SAMPLE_RATE = 16000
LANGUAGE = "zh"  # Chinese
MODEL = "nova-2-general"

def generate_tone_audio(frequency=440, duration_seconds=0.5, volume=0.3):
    """Generate a sine wave tone for testing"""
    total_samples = int(SAMPLE_RATE * duration_seconds)
    samples = []
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        sample = int(volume * 32767 * math.sin(2 * math.pi * frequency * t))
        samples.append(sample)
    audio_data = struct.pack(f'<{total_samples}h', *samples)
    return audio_data

def generate_silence(duration_seconds=0.5):
    """Generate silent audio"""
    total_samples = int(SAMPLE_RATE * duration_seconds)
    return bytes(total_samples * 2)  # 16-bit = 2 bytes per sample

async def test_deepgram_connection():
    """Test 1: Basic Deepgram connection"""
    print("\n" + "="*60)
    print("TEST 1: Deepgram API Connection")
    print("="*60)
    
    if not DEEPGRAM_API_KEY:
        print("❌ DEEPGRAM_API_KEY not set!")
        return False
    
    print(f"API Key: {DEEPGRAM_API_KEY[:10]}...{DEEPGRAM_API_KEY[-5:]}")
    
    try:
        deepgram = DeepgramClient(DEEPGRAM_API_KEY)
        dg_connection = deepgram.listen.websocket.v("1")
        
        connection_opened = asyncio.Event()
        connection_closed = asyncio.Event()
        errors = []
        
        def on_open(self, open, **kwargs):
            print("✅ Connection opened!")
            connection_opened.set()
        
        def on_error(self, error, **kwargs):
            print(f"❌ Error: {error}")
            errors.append(error)
        
        def on_close(self, close, **kwargs):
            print("🔒 Connection closed")
            connection_closed.set()
        
        dg_connection.on(LiveTranscriptionEvents.Open, on_open)
        dg_connection.on(LiveTranscriptionEvents.Error, on_error)
        dg_connection.on(LiveTranscriptionEvents.Close, on_close)
        
        options = LiveOptions(
            language=LANGUAGE,
            model=MODEL,
            sample_rate=SAMPLE_RATE,
            encoding='linear16',
        )
        
        print(f"Connecting with options: language={LANGUAGE}, model={MODEL}")
        result = dg_connection.start(options)
        print(f"Connection start result: {result}")
        
        # Wait for connection
        await asyncio.sleep(2)
        
        # Close connection
        dg_connection.finish()
        await asyncio.sleep(1)
        
        return len(errors) == 0 and connection_opened.is_set()
    
    except Exception as e:
        print(f"❌ Connection test failed: {e}")
        return False

async def test_deepgram_transcription():
    """Test 2: Send audio and get transcription"""
    print("\n" + "="*60)
    print("TEST 2: Deepgram Transcription")
    print("="*60)
    
    if not DEEPGRAM_API_KEY:
        print("❌ DEEPGRAM_API_KEY not set!")
        return False
    
    try:
        deepgram = DeepgramClient(DEEPGRAM_API_KEY)
        dg_connection = deepgram.listen.websocket.v("1")
        
        transcripts = []
        metadata_received = asyncio.Event()
        speech_detected = asyncio.Event()
        
        def on_message(self, result, **kwargs):
            sentence = result.channel.alternatives[0].transcript
            print(f"📝 Transcript: '{sentence}'")
            if sentence:
                transcripts.append(sentence)
        
        def on_metadata(self, metadata, **kwargs):
            print(f"📊 Metadata: duration={metadata.duration}s")
            metadata_received.set()
        
        def on_speech_started(self, speech_started, **kwargs):
            print("🎤 Speech detected!")
            speech_detected.set()
        
        def on_error(self, error, **kwargs):
            print(f"❌ Error: {error}")
        
        def on_open(self, open, **kwargs):
            print("✅ Connection opened!")
        
        dg_connection.on(LiveTranscriptionEvents.Transcript, on_message)
        dg_connection.on(LiveTranscriptionEvents.Metadata, on_metadata)
        dg_connection.on(LiveTranscriptionEvents.SpeechStarted, on_speech_started)
        dg_connection.on(LiveTranscriptionEvents.Error, on_error)
        dg_connection.on(LiveTranscriptionEvents.Open, on_open)
        
        options = LiveOptions(
            language=LANGUAGE,
            model=MODEL,
            sample_rate=SAMPLE_RATE,
            encoding='linear16',
            punctuate=True,
            diarize=True,
            smart_format=True,
        )
        
        result = dg_connection.start(options)
        print(f"Connection started: {result}")
        
        # Wait for connection
        await asyncio.sleep(1)
        
        # Send test audio (tone + silence + tone)
        print("🔊 Sending test audio (tone pattern)...")
        
        # Pattern: tone-silence-tone-silence
        for i in range(5):
            audio = generate_tone_audio(frequency=440 + i*100, duration_seconds=0.2)
            dg_connection.send(audio)
            print(f"   Sent {len(audio)} bytes (tone {440 + i*100}Hz)")
            await asyncio.sleep(0.1)
            
            silence = generate_silence(0.1)
            dg_connection.send(silence)
            await asyncio.sleep(0.1)
        
        # Wait for processing
        print("⏳ Waiting for transcription results...")
        await asyncio.sleep(5)
        
        # Close
        dg_connection.finish()
        await asyncio.sleep(1)
        
        print(f"\n📋 Results:")
        print(f"   Speech detected: {speech_detected.is_set()}")
        print(f"   Metadata received: {metadata_received.is_set()}")
        print(f"   Transcripts: {transcripts}")
        
        # Note: Tone audio won't produce meaningful transcription
        # This test mainly verifies the connection and callback flow
        return metadata_received.is_set()
    
    except Exception as e:
        print(f"❌ Transcription test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

async def test_deepgram_with_speech():
    """Test 3: Test with actual speech audio file (if available)"""
    print("\n" + "="*60)
    print("TEST 3: Deepgram with Speech Audio")
    print("="*60)
    
    # Check if there's a test audio file
    test_audio_path = os.path.join(os.path.dirname(__file__), "test_audio.wav")
    
    if not os.path.exists(test_audio_path):
        print(f"⚠️ No test audio file found at {test_audio_path}")
        print("   Skipping this test. To enable:")
        print("   1. Record a short audio clip")
        print("   2. Save as backend/test_audio.wav (16kHz, 16-bit, mono)")
        return None  # Skip, not fail
    
    if not DEEPGRAM_API_KEY:
        print("❌ DEEPGRAM_API_KEY not set!")
        return False
    
    try:
        import wave
        
        with wave.open(test_audio_path, 'rb') as wf:
            sample_rate = wf.getframerate()
            channels = wf.getnchannels()
            audio_data = wf.readframes(wf.getnframes())
        
        print(f"📂 Loaded test audio: {len(audio_data)} bytes, {sample_rate}Hz, {channels}ch")
        
        deepgram = DeepgramClient(DEEPGRAM_API_KEY)
        dg_connection = deepgram.listen.websocket.v("1")
        
        transcripts = []
        
        def on_message(self, result, **kwargs):
            sentence = result.channel.alternatives[0].transcript
            if sentence:
                print(f"📝 Transcript: '{sentence}'")
                transcripts.append(sentence)
        
        def on_error(self, error, **kwargs):
            print(f"❌ Error: {error}")
        
        dg_connection.on(LiveTranscriptionEvents.Transcript, on_message)
        dg_connection.on(LiveTranscriptionEvents.Error, on_error)
        
        options = LiveOptions(
            language=LANGUAGE,
            model=MODEL,
            sample_rate=sample_rate,
            encoding='linear16',
            punctuate=True,
        )
        
        dg_connection.start(options)
        await asyncio.sleep(1)
        
        # Send audio in chunks
        chunk_size = sample_rate * 2 // 10  # 100ms chunks
        for i in range(0, len(audio_data), chunk_size):
            chunk = audio_data[i:i+chunk_size]
            dg_connection.send(chunk)
            await asyncio.sleep(0.05)
        
        # Wait for processing
        await asyncio.sleep(3)
        
        dg_connection.finish()
        await asyncio.sleep(1)
        
        print(f"\n📋 Transcripts received: {len(transcripts)}")
        for t in transcripts:
            print(f"   '{t}'")
        
        return len(transcripts) > 0
    
    except Exception as e:
        print(f"❌ Speech audio test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

async def test_api_key_validity():
    """Test 0: Check if API key is valid"""
    print("\n" + "="*60)
    print("TEST 0: API Key Validity Check")
    print("="*60)
    
    if not DEEPGRAM_API_KEY:
        print("❌ DEEPGRAM_API_KEY environment variable not set!")
        print("   Set it in backend/.env or export it:")
        print("   export DEEPGRAM_API_KEY=your_key_here")
        return False
    
    print(f"API Key: {DEEPGRAM_API_KEY[:10]}...{DEEPGRAM_API_KEY[-5:]} ({len(DEEPGRAM_API_KEY)} chars)")
    
    # Try to make a simple request to verify key
    try:
        import aiohttp
        
        url = "https://api.deepgram.com/v1/projects"
        headers = {"Authorization": f"Token {DEEPGRAM_API_KEY}"}
        
        async with aiohttp.ClientSession() as session:
            async with session.get(url, headers=headers, timeout=aiohttp.ClientTimeout(total=10)) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    print(f"✅ API Key is valid!")
                    print(f"   Projects: {len(data.get('projects', []))}")
                    return True
                elif resp.status == 401:
                    print("❌ API Key is invalid or expired!")
                    return False
                else:
                    print(f"⚠️ Unexpected status: {resp.status}")
                    return False
    except Exception as e:
        print(f"⚠️ Could not verify API key: {e}")
        print("   Continuing with connection test...")
        return True  # Don't fail, just warn

async def main():
    print("="*60)
    print("Deepgram STT Direct Test")
    print(f"Time: {datetime.now().isoformat()}")
    print("="*60)
    
    results = {}
    
    # Run tests
    results['api_key'] = await test_api_key_validity()
    results['connection'] = await test_deepgram_connection()
    results['transcription'] = await test_deepgram_transcription()
    
    speech_result = await test_deepgram_with_speech()
    if speech_result is not None:
        results['speech'] = speech_result
    
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
