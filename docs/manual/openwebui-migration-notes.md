# Open WebUI Migration Notes

## 목적

기존 운영 위치인 `/home/ubuntu/open-webui`에서 컨테이너를 내리고, 새 위치인 `/home/ubuntu/openwebui`에서 같은 데이터를 사용해 Open WebUI와 pipelines를 운영하도록 이전했다.

## 원인 및 배경

처음 새 위치에서 컨테이너를 올렸을 때 관리자 로그인이 실패했다. 메시지는 다음과 같았다.

```text
The email or password provided is incorrect. Please check for typos and try logging in again.
```

실제 원인은 계정 오류가 아니라 데이터 경로 차이였다. 이전 폴더에는 `.env`가 있었고, 다음 경로를 사용하고 있었다.

```env
OPENWEBUI_LOCAL_DATA=/home/ubuntu/open-webui/openwebui
PIPELINES_LOCAL_DATA=/home/ubuntu/open-webui/pipelines
```

새 폴더에는 `.env`가 없어 compose 기본값인 `/app/backend/data`가 호스트 경로로 사용됐고, Open WebUI가 새 DB를 생성했다. 그 결과 기존 관리자 계정이 없는 DB를 보고 있었다.

## 수행한 이전 작업

1. `/home/ubuntu/openwebui`에서 실행 중인 컨테이너를 중지했다.

```bash
docker compose down
```

2. 기존 데이터를 새 위치로 복사했다.

```bash
cp -a /home/ubuntu/open-webui/openwebui /home/ubuntu/openwebui/openwebui
cp -a /home/ubuntu/open-webui/pipelines /home/ubuntu/openwebui/pipelines
cp /home/ubuntu/open-webui/.env /home/ubuntu/openwebui/.env
```

3. 새 `.env`의 경로를 새 위치로 변경했다.

```env
OPENWEBUI_LOCAL_DATA=/home/ubuntu/openwebui/openwebui
PIPELINES_LOCAL_DATA=/home/ubuntu/openwebui/pipelines
```

4. compose 설정을 검증하고 컨테이너를 다시 올렸다.

```bash
docker compose config
docker compose up -d
```

## 검증 결과

컨테이너 내부 `/app/backend/data/webui.db`에서 기존 사용자와 인증 레코드가 확인됐다.

```text
user 4
auth 4
```

최종 상태는 `openwebui-openwebui-1`이 `healthy`, `openwebui-pipelines-1`이 `Up`이었다. 새 Open WebUI 데이터 마운트 경로는 `/home/ubuntu/openwebui/openwebui`이다.

## 주의사항

DB 파일을 복사할 때는 반드시 Open WebUI 컨테이너를 먼저 내려 DB 쓰기를 멈춘다. 운영 중 복사하면 `webui.db`, `webui.db-wal`, `webui.db-shm` 간 불일치가 생길 수 있다.
