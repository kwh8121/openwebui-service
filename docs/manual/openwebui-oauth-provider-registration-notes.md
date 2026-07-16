# Open WebUI OAuth Provider Registration Notes

## 목적

Open WebUI `0.10.1`에서 관리자 UI의 OAuth 설정 저장은 성공하지만 로그인 화면에 Google 버튼이 나타나지 않는 문제를 해결한 작업 내용을 기록한다. 이미지 리빌드, 버전 업데이트, 컨테이너 재생성 이후 같은 문제가 생기면 이 문서를 기준으로 확인한다.

## 문제 현상

관리자 화면 `/admin/settings/authentication`에서 OAuth 값을 저장하면 API 요청은 성공했다.

```text
POST /api/v1/auths/admin/config/oauth
HTTP 200
```

하지만 저장 직후 응답 또는 로그인 화면에서는 OAuth provider가 반영되지 않았다. 초기에는 `OAUTH_PROVIDER_NAME`이 `SSO`, `OAUTH_CLIENT_ID`가 빈 값처럼 보였고, 로그인 화면의 공개 설정도 다음처럼 provider가 비어 있었다.

```json
{
	"oauth": {
		"providers": {}
	}
}
```

## 확인한 원인

현재 운영 중인 컨테이너는 다음 이미지다.

```text
ghcr.io/open-webui/open-webui:0.10.1
```

이 버전에서는 OAuth 관련 persistent config가 별도 플래그의 영향을 받는다.

```env
ENABLE_PERSISTENT_CONFIG=true
ENABLE_OAUTH_PERSISTENT_CONFIG=true
```

또한 `0.10.1`의 provider 등록은 앱 기동 시점에 수행된다. 관리자 UI에서 DB에 값을 저장하더라도 이미 기동된 프로세스의 `oauth.providers`에는 즉시 반영되지 않을 수 있다.

실제 확인 결과 DB에는 다음 OAuth 값이 저장되어 있었다.

```text
oauth.provider_name=Google
oauth.provider_url=https://accounts.google.com/.well-known/openid-configuration
oauth.client_id=SET
oauth.client_secret=SET
oauth.scopes=openid email profile
oauth.enable_signup=true
```

하지만 DB 저장값만 있는 상태에서 컨테이너를 재시작해도 `/api/config`는 계속 provider 없음 상태를 반환했다.

```json
{
	"oauth": {
		"providers": {}
	}
}
```

즉, 이 운영 버전에서는 로그인 provider 등록 경로가 DB persistent config만으로는 충분하지 않고, 기동 시 환경변수도 함께 필요했다.

## 적용한 해결책

`docker-compose.yaml`의 `openwebui` 서비스에 OAuth persistent config 플래그를 추가했다.

```yaml
environment:
  - TZ=Asia/Seoul
  - ENABLE_PERSISTENT_CONFIG=true
  - ENABLE_OAUTH_PERSISTENT_CONFIG=true
```

그리고 DB에 저장된 OAuth 값을 별도 env 파일로 옮겼다.

```text
/home/ubuntu/openwebui/.env.openwebui.oauth
```

이 파일은 secret을 포함하므로 git에 올리면 안 된다. 현재 `.gitignore`에는 `.env.*`가 포함되어 있어 ignore 대상이며, 파일 권한은 `600`으로 설정했다.

`docker-compose.yaml`에는 다음처럼 연결했다.

```yaml
openwebui:
  image: ghcr.io/open-webui/open-webui:0.10.1
  env_file:
    - ./.env.openwebui.oauth
```

`.env.openwebui.oauth`에는 다음 종류의 값이 들어간다. 실제 값은 문서에 기록하지 않는다.

```env
OAUTH_PROVIDER_NAME=Google
OPENID_PROVIDER_URL=https://accounts.google.com/.well-known/openid-configuration
OAUTH_CLIENT_ID=<google-client-id>
OAUTH_CLIENT_SECRET=<google-client-secret>
OAUTH_SCOPES='openid email profile'
ENABLE_OAUTH_SIGNUP=true
```

적용 후 Open WebUI 서비스만 재생성했다.

```bash
docker compose -f /home/ubuntu/openwebui/docker-compose.yaml up -d openwebui
```

## 검증 결과

컨테이너 내부 환경변수는 다음 상태로 확인됐다. secret과 client id는 값 자체를 출력하지 않고 설정 여부만 확인했다.

```text
OAUTH_PROVIDER_NAME=Google
OPENID_PROVIDER_URL=https://accounts.google.com/.well-known/openid-configuration
OAUTH_CLIENT_ID_SET=True
OAUTH_CLIENT_SECRET_SET=True
ENABLE_OAUTH_SIGNUP=true
OAUTH_SCOPES=openid email profile
ENABLE_OAUTH_PERSISTENT_CONFIG=true
```

최종 `/api/config` 응답은 다음처럼 Google OIDC provider를 반환했다.

```json
{
	"auto_redirect": true,
	"providers": {
		"oidc": "Google"
	}
}
```

컨테이너 상태도 `healthy`로 확인됐다.

```text
openwebui-openwebui-1   ghcr.io/open-webui/open-webui:0.10.1   healthy   80->8080
```

## 업데이트 또는 리빌드 후 확인 절차

1. compose 파일에 persistent config 플래그가 남아 있는지 확인한다.

```bash
sed -n '1,32p' /home/ubuntu/openwebui/docker-compose.yaml
```

2. OAuth env 파일이 존재하고 권한이 `600`인지 확인한다.

```bash
stat -c '%a %n' /home/ubuntu/openwebui/.env.openwebui.oauth
```

3. compose 문법을 확인한다. secret이 출력되지 않도록 `--quiet`을 사용한다.

```bash
docker compose -f /home/ubuntu/openwebui/docker-compose.yaml config --quiet
```

4. Open WebUI 서비스만 재생성한다.

```bash
docker compose -f /home/ubuntu/openwebui/docker-compose.yaml up -d openwebui
```

5. 공개 config에서 provider 등록 여부를 확인한다.

```bash
curl -sS http://127.0.0.1/api/config | python3 -c 'import json,sys; data=json.load(sys.stdin); print(json.dumps(data.get("oauth", {}), ensure_ascii=False, sort_keys=True))'
```

정상 결과는 다음 형태다.

```json
{ "auto_redirect": true, "providers": { "oidc": "Google" } }
```

## DB 저장값 확인 명령

DB에 OAuth 값이 들어 있는지 확인할 때는 secret 값을 직접 출력하지 않는다.

```bash
docker exec openwebui-openwebui-1 sh -lc 'python - <<'"'"'PY'"'"'
import json, sqlite3
conn=sqlite3.connect("/app/backend/data/webui.db")
cur=conn.cursor()
keys = [
    "oauth.provider_name",
    "oauth.provider_url",
    "oauth.client_id",
    "oauth.client_secret",
    "oauth.scopes",
    "oauth.enable_signup",
]
cur.execute("select key, value from config where key in (%s)" % ",".join("?" for _ in keys), keys)
rows = dict(cur.fetchall())
for key in keys:
    raw = rows.get(key)
    try:
        value = json.loads(raw) if isinstance(raw, str) else raw
    except Exception:
        value = raw
    if key in {"oauth.client_id", "oauth.client_secret"}:
        print(f"{key}=SET" if value else f"{key}=EMPTY")
    else:
        print(f"{key}={value!r}")
PY'
```

## 주의사항

`auto_redirect`가 `true`이면 로그인 화면에서 버튼을 오래 확인하기 전에 Google 로그인으로 바로 이동할 수 있다.

`.env.openwebui.oauth`는 운영 secret 파일이다. 백업과 권한 관리는 필요하지만 git 커밋 대상은 아니다.

이미지 업데이트 후 Open WebUI가 OAuth provider 등록 순서를 개선하면 DB persistent config만으로 동작할 수 있다. 그래도 운영 안정성을 위해 현재는 env 파일 방식도 유지한다.
