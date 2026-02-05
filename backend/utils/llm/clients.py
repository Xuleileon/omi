import os
from typing import List
import requests

from langchain_core.output_parsers import PydanticOutputParser
from langchain_openai import ChatOpenAI
import tiktoken

from models.conversation import Structured
from utils.llm.usage_tracker import get_usage_callback

# Get the usage tracking callback
_usage_callback = get_usage_callback()

# Custom API configuration
_api_key = os.environ.get('OPENAI_API_KEY')
_api_base = os.environ.get('OPENAI_API_BASE')
_model = os.environ.get('OPENAI_MODEL')

# Base models for general use - using custom endpoint
llm_mini = ChatOpenAI(model=_model, api_key=_api_key, base_url=_api_base, callbacks=[_usage_callback])
llm_mini_stream = ChatOpenAI(
    model=_model,
    api_key=_api_key,
    base_url=_api_base,
    streaming=True,
    callbacks=[_usage_callback],
)
llm_large = ChatOpenAI(model=_model, api_key=_api_key, base_url=_api_base, callbacks=[_usage_callback])
llm_large_stream = ChatOpenAI(
    model=_model,
    api_key=_api_key,
    base_url=_api_base,
    streaming=True,
    temperature=1,
    callbacks=[_usage_callback],
)
llm_high = ChatOpenAI(model=_model, api_key=_api_key, base_url=_api_base, callbacks=[_usage_callback])
llm_high_stream = ChatOpenAI(
    model=_model,
    api_key=_api_key,
    base_url=_api_base,
    streaming=True,
    temperature=1,
    callbacks=[_usage_callback],
)
llm_medium = ChatOpenAI(model=_model, api_key=_api_key, base_url=_api_base, callbacks=[_usage_callback])
llm_medium_stream = ChatOpenAI(
    model=_model,
    api_key=_api_key,
    base_url=_api_base,
    streaming=True,
    callbacks=[_usage_callback],
)
llm_medium_experiment = ChatOpenAI(model=_model, api_key=_api_key, base_url=_api_base, callbacks=[_usage_callback])

# Specialized models for agentic workflows
llm_agent = ChatOpenAI(model=_model, api_key=_api_key, base_url=_api_base, callbacks=[_usage_callback])
llm_agent_stream = ChatOpenAI(
    model=_model,
    api_key=_api_key,
    base_url=_api_base,
    streaming=True,
    callbacks=[_usage_callback],
)
llm_persona_mini_stream = ChatOpenAI(
    temperature=0.8,
    model=_model,
    api_key=_api_key,
    base_url=_api_base,
    streaming=True,
    callbacks=[_usage_callback],
)
llm_persona_medium_stream = ChatOpenAI(
    temperature=0.8,
    model=_model,
    api_key=_api_key,
    base_url=_api_base,
    streaming=True,
    callbacks=[_usage_callback],
)

# Gemini models for large context analysis - also use custom endpoint
llm_gemini_flash = ChatOpenAI(
    temperature=0.7,
    model=_model,
    api_key=_api_key,
    base_url=_api_base,
    callbacks=[_usage_callback],
)

# Doubao (ByteDance) embeddings API
_doubao_api_key = os.environ.get('DOUBAO_API_KEY')
_doubao_embedding_url = os.environ.get('DOUBAO_EMBEDDING_URL', 'https://ark.cn-beijing.volces.com/api/v3/embeddings/multimodal')
_doubao_embedding_model = os.environ.get('DOUBAO_EMBEDDING_MODEL', 'doubao-embedding-vision-251215')

class DoubaoEmbeddings:
    """Wrapper for Doubao multimodal embedding API"""
    def _call_api(self, texts: List[str]) -> List[List[float]]:
        results = []
        for text in texts:
            response = requests.post(
                _doubao_embedding_url,
                headers={
                    'Content-Type': 'application/json',
                    'Authorization': f'Bearer {_doubao_api_key}'
                },
                json={
                    'model': _doubao_embedding_model,
                    'input': [{'type': 'text', 'text': text}],
                    'dimensions': 1024,
                    'encoding_format': 'float'
                },
                timeout=30
            )
            data = response.json()
            if 'data' in data and 'embedding' in data['data']:
                results.append(data['data']['embedding'])
            else:
                raise Exception(f"Doubao embedding error: {data}")
        return results

    def embed_documents(self, texts: List[str]) -> List[List[float]]:
        return self._call_api(texts)

    def embed_query(self, text: str) -> List[float]:
        return self._call_api([text])[0]

embeddings = DoubaoEmbeddings()
parser = PydanticOutputParser(pydantic_object=Structured)

encoding = tiktoken.encoding_for_model('gpt-4')


def num_tokens_from_string(string: str) -> int:
    """Returns the number of tokens in a text string."""
    num_tokens = len(encoding.encode(string))
    return num_tokens


def generate_embedding(content: str) -> List[float]:
    return embeddings.embed_documents([content])[0]
