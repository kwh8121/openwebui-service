# Korean Locale Image Notes

## 문제 현상

설정 화면에서 `Korean (한국어)`를 선택해도 화면 언어가 한국어로 바뀌지 않았다. 서버 로그에는 `lang=ko-KR` 요청이 보였으므로, 선택값 자체가 거부되는 문제는 아니었다.

## 확인한 원인

초기 컨테이너는 `ghcr.io/open-webui/open-webui:main` 이미지를 사용하고 있었지만, 실제 `/api/config`의 버전은 `0.9.5`였다.

```json
{
  "version": "0.9.5",
  "default_locale": ""
}
```

컨테이너 내부 빌드 산출물에서 한국어 번역 리소스를 확인했으나 다음 문제가 있었다.

- `/app` 아래에 `ko-KR` locale 원본 파일 없음
- `/app/build/_app/immutable` 안에 실제 한국어 UI 문자열 없음
- 별도 번역 JSON 파일도 배포되어 있지 않음

즉, UI에는 `Korean (한국어)` 항목이 있었지만 프론트엔드가 불러올 한국어 번역 청크가 없어 영어 fallback으로 남는 상태였다.

## 적용한 해결책

운영 안정성을 위해 로컬 빌드 대신 공식 이미지의 명시 버전 태그를 사용했다. `docker-compose.yaml`의 Open WebUI 이미지를 다음처럼 변경했다.

```yaml
openwebui:
  image: ghcr.io/open-webui/open-webui:0.9.6
```

변경 전 compose 파일은 다음 이름으로 백업했다.

```text
docker-compose.yaml.before-image-tag-change
```

공식 이미지를 받고 Open WebUI 컨테이너만 재생성했다.

```bash
docker compose pull openwebui
docker compose up -d openwebui
```

## 검증 결과

새 컨테이너의 `/api/config`는 `0.9.6`을 반환했다.

```json
{
  "version": "0.9.6"
}
```

한국어 번역 청크가 HTTP로 정상 제공됐고, 청크 내부에서 다음 한국어 UI 문자열을 확인했다.

```text
새 채팅
언어
```

최종 컨테이너 상태는 다음과 같았다.

```text
openwebui-openwebui-1   ghcr.io/open-webui/open-webui:0.9.6   healthy   80->8080
openwebui-pipelines-1   ghcr.io/open-webui/pipelines:main      Up        9099->9099
```

## 브라우저 캐시 주의

한국어 리소스가 서버에 있어도 브라우저가 이전 `main` 이미지의 프론트엔드 청크를 캐시하고 있으면 영어 화면이 계속 보일 수 있다. 이 경우 `Ctrl + F5`로 강력 새로고침하거나 해당 사이트의 localStorage/cache를 지운 뒤 다시 접속한다.
