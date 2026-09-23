# Vercel 배포

GitHub 저장소 `practice`를 Vercel에 Import Project로 연결합니다.

- **Root Directory:** `cbt` (가장 중요)
- **Framework Preset:** `Other`
- **Build Command:** 비움
- **Output Directory:** `public` (`vercel.json`에 포함)
- **Install Command:** 비움
- **Environment Variables:** 필요 없음

배포 후 루트 URL에서 첫 문항과 그림을 확인합니다. `server.js`는 로컬 실행용이며 Vercel은 `public/`을 정적 웹으로 제공합니다. `public/questions.json`이 배포용 문항 데이터입니다.

## 문항 변경

배포된 웹에서의 문항 편집은 **그 브라우저에만** 저장됩니다. 수정 후 **문항 관리 → JSON 내보내기**로 받은 `questions.json`을 저장소의 `cbt/data/questions.json`과 `cbt/public/questions.json` 두 위치에 덮어쓴 다음 커밋·푸시하면 Vercel이 다시 배포합니다. 다른 브라우저에는 새 배포 내용이 보입니다. 이미 문항을 편집한 브라우저는 **문항 관리 → JSON 가져오기**로 새 파일을 가져올 수 있습니다.

로컬 서버에서 문항 관리로 수정하면 두 JSON 파일이 함께 갱신됩니다. `node server.js`는 Node.js 설치 후 로컬에서만 사용합니다.

Vercel 배포를 통해 문제와 이미지가 URL을 아는 사람에게 보일 수 있으므로 공유 범위를 확인하세요. 제공 PDF에는 정답표가 없어 정답은 `null`입니다.
