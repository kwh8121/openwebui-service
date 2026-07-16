import requests
import os


class OpenWebUIRAG:
    def __init__(self, base_url, api_key):
        self.base_url = base_url
        self.headers = {'Authorization': f'Bearer {api_key}', 'Content-Type': 'application/json'}

    def upload_document(self, file_path):
        """문서 업로드"""
        url = f'{self.base_url}/api/v1/files/'
        headers = {'Authorization': self.headers['Authorization'], 'Accept': 'application/json'}
        with open(file_path, 'rb') as f:
            files = {'file': f}
            response = requests.post(url, headers=headers, files=files)
        return response.json()

    def create_knowledge_base(self, name, description=''):
        """지식 베이스 생성"""
        url = f'{self.base_url}/api/v1/knowledge/create'
        data = {'name': name, 'description': description, 'data': {'file_ids': []}}
        response = requests.post(url, headers=self.headers, json=data)
        return response.json()

    def add_file_to_knowledge(self, knowledge_id, file_id):
        """지식 베이스에 파일 추가"""
        url = f'{self.base_url}/api/v1/knowledge/{knowledge_id}/file/add'
        data = {'file_id': file_id}
        response = requests.post(url, headers=self.headers, json=data)
        return response.json()

    def query_knowledge(self, model, query, knowledge_id):
        """지식 베이스 기반 질의응답"""
        url = f'{self.base_url}/api/chat/completions'
        data = {
            'model': model,
            'messages': [{'role': 'user', 'content': query}],
            'files': [{'type': 'collection', 'id': knowledge_id}],
        }
        response = requests.post(url, headers=self.headers, json=data)
        return response.json()


# 사용 예시
rag = OpenWebUIRAG('http://localhost:3000', 'your_api_key')

# 1. 문서 업로드
file_result = rag.upload_document('/path/to/document.pdf')
file_id = file_result['id']

# 2. 지식 베이스 생성
kb_result = rag.create_knowledge_base('기술 문서', '기술 관련 문서 모음')
kb_id = kb_result['id']

# 3. 파일을 지식 베이스에 추가
rag.add_file_to_knowledge(kb_id, file_id)

# 4. 질의응답
response = rag.query_knowledge('llama3.1', '이 문서의 주요 기능은?', kb_id)
print(response['choices'][0]['message']['content'])
