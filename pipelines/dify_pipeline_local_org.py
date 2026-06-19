# 필요한 라이브러리 임포트
from typing import List, Union, Generator, Iterator, Optional
from pprint import pprint
import requests, json
from dataclasses import dataclass
from typing import Dict, Optional
from pydantic import BaseModel
import os


@dataclass
class DifySchema:
    """
    Dify API 요청에 필요한 스키마를 정의하는 데이터 클래스

    Attributes:
        dify_type (str): API 요청 타입 ('workflow', 'agent', 'chat', 'completion')
        user_input_key (str): 사용자 입력값의 키
        response_mode (str): 응답 모드 ('streaming' 또는 'blocking')
        user (str): 사용자 식별자
    """

    dify_type: str
    user_input_key: str
    response_mode: str
    user: str = ""

    def get_schema(self) -> Dict:
        """
        API 요청에 필요한 스키마를 딕셔너리 형태로 반환

        Returns:
            Dict: API 요청 스키마
        """
        # API 요청 타입에 따라 적절한 스키마 반환
        if self.dify_type == "workflow":
            return {
                "inputs": {},
                "response_mode": self.response_mode,
                "user": self.user,
            }
        elif self.dify_type == "agent":
            return {
                "inputs": {},
                "query": self.user_input_key,
                "response_mode": self.response_mode,
                "user": self.user,
            }
        elif self.dify_type == "chat":
            return {
                "inputs": {},
                "query": "",
                "response_mode": self.response_mode,
                "user": self.user,
            }
        elif self.dify_type == "completion":
            return {
                "inputs": {},
                "response_mode": self.response_mode,
                "user": self.user,
            }
        else:
            raise ValueError(
                "Invalid dify_type. Must be 'completion', 'workflow', 'agent', or 'chat'"
            )


class Pipeline:
    """
    Dify API와 상호작용하기 위한 파이프라인 클래스

    API 요청을 처리하고 응답을 스트리밍하거나 블로킹 방식으로 반환합니다.
    """

    class Valves(BaseModel):
        """
        파이프라인 설정값을 저장하는 내부 클래스

        Attributes:
            APP_NAME (str): 애플리케이션 이름
            HOST_URL (str): Dify API 호스트 URL
            DIFY_API_KEY (str): API 인증 키
            USER_INPUT_KEY (str): 사용자 입력값 키
            USER_INPUTS (str): 추가 사용자 입력값
            DIFY_TYPE (str): API 요청 타입
            RESPONSE_MODE (str): 응답 모드 (기본값: 'streaming')
            VERIFY_SSL (bool): SSL 인증 여부 (기본값: True)
        """

        APP_NAME: str
        HOST_URL: str
        DIFY_API_KEY: str
        USER_INPUT_KEY: str
        USER_INPUTS: str
        DIFY_TYPE: str
        RESPONSE_MODE: Optional[str] = "streaming"
        VERIFY_SSL: Optional[bool] = True

    def __init__(self):
        """파이프라인 객체 초기화"""
        # 환경 변수에서 설정값을 가져와 Valves 객체 초기화
        self.valves = self.Valves(
            **{
                "pipelines": ["*"],
                "APP_NAME": os.getenv("APP_NAME", "My Dify Pipeline Local"),
                "HOST_URL": os.getenv("HOST_URL", "http://host.docker.internal"),
                "DIFY_API_KEY": os.getenv("DIFY_API_KEY", "YOUR_DIFY_API_KEY"),
                "USER_INPUT_KEY": os.getenv("USER_INPUT_KEY", "input"),
                "USER_INPUTS": (
                    os.getenv("USER_INPUTS") if os.getenv("USER_INPUTS") else "{}"
                ),
                "DIFY_TYPE": os.getenv("DIFY_TYPE", "workflow"),
                "RESPONSE_MODE": os.getenv("RESPONSE_MODE", "streaming"),
                "VERIFY_SSL": os.getenv("VERIFY_SSL", False),
            }
        )
        self.name = self.valves.APP_NAME

        # 초기 데이터 스키마 설정
        self.data_schema = DifySchema(
            dify_type=self.valves.DIFY_TYPE,
            user_input_key=self.valves.USER_INPUT_KEY,
            response_mode=self.valves.RESPONSE_MODE,
        ).get_schema()

        self.debug = False

    def create_api_url(self):
        """
        API 요청 URL을 생성

        Returns:
            str: API 엔드포인트 URL
        """
        # API 타입에 따른 엔드포인트 URL 생성
        if self.valves.DIFY_TYPE == "workflow":
            return f"{self.valves.HOST_URL}/v1/workflows/run"
        elif self.valves.DIFY_TYPE == "agent":
            return f"{self.valves.HOST_URL}/v1/chat-messages"
        elif self.valves.DIFY_TYPE == "chat":
            return f"{self.valves.HOST_URL}/v1/chat-messages"
        elif self.valves.DIFY_TYPE == "completion":
            return f"{self.valves.HOST_URL}/v1/completion-messages"
        else:
            raise ValueError(f"Invalid Dify type: {self.valves.DIFY_TYPE}")

    def set_data_schema(self, schema: dict):
        """
        데이터 스키마를 동적으로 설정

        Args:
            schema (dict): 새로운 데이터 스키마
        """
        self.data_schema = schema

    async def on_startup(self):
        """서버 시작 시 호출되는 메서드"""
        print(f"on_startup: {__name__}")
        pass

    async def on_shutdown(self):
        """서버 종료 시 호출되는 메서드"""
        print(f"on_shutdown: {__name__}")
        pass

    async def inlet(self, body: dict, user: Optional[dict] = None) -> dict:
        """
        OpenAI API 요청 전 데이터 전처리

        Args:
            body (dict): 요청 본문
            user (Optional[dict]): 사용자 정보

        Returns:
            dict: 처리된 요청 본문
        """
        print(f"inlet: {__name__}")
        if self.debug:
            print(f"inlet: {__name__} - body:")
            pprint(body)
            print(f"inlet: {__name__} - user:")
            pprint(user)
        return body

    async def outlet(self, body: dict, user: Optional[dict] = None) -> dict:
        """
        OpenAI API 응답 후 데이터 후처리

        Args:
            body (dict): 응답 본문
            user (Optional[dict]): 사용자 정보

        Returns:
            dict: 처리된 응답 본문
        """
        print(f"outlet: {__name__}")
        if self.debug:
            print(f"outlet: {__name__} - body:")
            pprint(body)
            print(f"outlet: {__name__} - user:")
            pprint(user)
        return body

    def pipe(
        self, user_message: str, model_id: str, messages: List[dict], body: dict
    ) -> Union[str, Generator, Iterator]:
        """
        Dify API를 호출하여 메시지를 처리

        Args:
            user_message (str): 사용자 메시지
            model_id (str): 모델 식별자
            messages (List[dict]): 메시지 목록
            body (dict): 요청 본문

        Returns:
            Union[str, Generator, Iterator]: 응답 텍스트 또는 에러 메시지를 생성하는 제너레이터
        """

        if self.debug:
            print(f"pipe: {__name__} - received message from user: {user_message}")

        try:
            # API 요청 헤더 설정
            self.name = self.valves.APP_NAME
            self.headers = {
                "Authorization": f"Bearer {self.valves.DIFY_API_KEY}",
                "Content-Type": "application/json",
            }

            # 요청 데이터 준비
            data = self.data_schema.copy()
            if self.valves.DIFY_TYPE == "workflow":
                data["inputs"][self.valves.USER_INPUT_KEY] = user_message
            elif self.valves.DIFY_TYPE == "agent" or self.valves.DIFY_TYPE == "chat":
                data["query"] = user_message
            elif self.valves.DIFY_TYPE == "completion":
                data["inputs"]["query"] = user_message
            data["user"] = body["user"]["email"]

            # 추가 사용자 입력 처리
            if self.valves.USER_INPUTS:
                inputs_dict = json.loads(self.valves.USER_INPUTS)
                data["inputs"].update(inputs_dict)
            print(data)

            # API 요청 실행
            response = requests.post(
                self.create_api_url(),
                headers=self.headers,
                json=data,
                verify=self.valves.VERIFY_SSL,
                stream=self.valves.RESPONSE_MODE == "streaming",
            )

            if response.status_code != 200:
                yield f"API request failed with status code {response.status_code}: {response.text}"

            # 스트리밍 또는 일반 응답 처리
            if self.valves.RESPONSE_MODE == "streaming":
                for line in response.iter_lines():
                    if line:
                        decoded_line = line.decode("utf-8")
                        if decoded_line.startswith("data: "):
                            try:
                                data = json.loads(decoded_line.replace("data: ", ""))
                                if data["event"] == "text_chunk":
                                    yield data["data"]["text"]
                                elif (
                                    data["event"] == "agent_message"
                                    or data["event"] == "message"
                                    or data["event"] == "completion"
                                ):
                                    if "answer" in data:
                                        yield data["answer"]
                                    else:
                                        yield data["data"]["text"]
                                elif data["event"] == "workflow_finished":
                                    yield data["data"]["outputs"]["output"]
                            except:
                                print(f"Error parsing line: {decoded_line}")
            else:
                try:
                    response_data = json.loads(response.text)
                    yield response_data
                except json.JSONDecodeError:
                    yield f"Failed to parse JSON response. Raw response: {response.text}"

        except requests.exceptions.RequestException as e:
            yield f"API request failed: {str(e)}"
