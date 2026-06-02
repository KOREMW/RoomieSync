# 제출 전 최종 체크리스트

작성자: 엄민욱 (2091188) · 2026-06-13 (제출 D-1)

> 제출 직전 체크리스트입니다. 위에서 아래로 순서대로 체크.

## A. 코드 / 빌드

- [ ] `xcodegen generate` 후 .xcodeproj 정상 생성
- [ ] Xcode 26.5 에서 `⌘B` 빌드 통과 (경고 0개 목표, 허용치 5개 이내)
- [ ] `⌘U` 테스트 34/34 PASS (Settlement 15 + Rotation 7 + Conflict 4 + Queue 3 + CKError 5)
- [ ] 시뮬레이터 iPhone 15 Pro 에서 `⌘R` 실행 후 4탭 모두 진입
- [ ] 시뮬레이터 2대로 CloudKit 동기화 확인 (한쪽 변경 ≤ 10초 내 반영)
- [ ] 푸시 알림 권한 허용 → 가사 추가 → 알림 트리거
- [ ] 위젯 추가 → Small / Medium / Lock Screen 표시
- [ ] Live Activity — Dynamic Island compact / expanded / minimal 모두 표시 (실기기 필요)

## B. 문서

- [ ] `README.md` 학번 (2091188) / 이름 (엄민욱) / 이메일 반영
- [ ] `README.md` 데모 GIF 자리 → 실제 `docs/demo.gif` 교체 (3 MB 이하)
- [ ] `README.md` 5개 화면 스크린샷 → `docs/screens/01_home.png` ~ `05_stats.png` 교체
- [ ] `README.md` YouTube 임베드 → 실제 영상 URL 로 교체
- [ ] `README.md` GitHub QR `docs/qr.png` 생성 (아래 §D)
- [ ] `docs/progress.md` 4주차 완료 로그 기록
- [ ] `docs/cloudkit-setup.md` 본인 컨테이너 ID 로 갱신 (기본은 `iCloud.com.roomiesync.app`)
- [ ] `docs/video-script.md` 자막 한글 맞춤법 1회 검토

## C. 시연 영상

- [ ] 총 길이 ≤ 3:00 (3:30 초과 시 감점)
- [ ] 6 단계 콘티 모두 포함 (문제 → 그룹 → 가사 → 지출 → 차별점 → 마무리)
- [ ] BGM 크레딧 영상 description 에 표기
- [ ] YouTube 업로드 → 일부 공개(unlisted) 로 설정
- [ ] README 에 임베드 + 마지막 5초 GitHub QR 가독성

## D. GitHub 리포지토리

상세 명령은 [`docs/git-workflow.md`](git-workflow.md) 의 6 섹션 참조. 핵심 체크:

- [ ] `git init` + 첫 commit + `git push -u origin main` (git-workflow.md §1-1)
- [ ] dev 브랜치 + push (git-workflow.md §1-2)
- [ ] PR 1개 생성 (`gh pr create` 또는 GitHub 웹 compare URL)
- [ ] `scripts/_pr_bodies/*.md` 5개를 PR 본문으로 첨부 (`cat scripts/_pr_bodies/*.md > body.md`)
- [ ] Repository **Public** 으로 전환 (`gh repo edit ... --visibility public` 또는 Settings → Danger Zone)
- [ ] `.gitignore` 가 `.xcodeproj`, `DerivedData`, `.DS_Store`, `.env` 모두 차단 (이미 OK)
- [ ] LICENSE (MIT) 의 연도/이름 (2026 엄민욱) 정확 ✅
- [ ] CI 워크플로우 (`.github/workflows/ci.yml`) 가 first push 후 그린 (또는 학생이 수정 후 그린 보장)

### GitHub QR 생성

```bash
bash docs/qr_generator.sh https://github.com/eomminwook/roomiesync
# 또는 직접
qrencode -o docs/qr.png -s 12 -m 2 "https://github.com/eomminwook/roomiesync"
```

생성된 `docs/qr.png` 가 영상 마무리 (2:50 ~ 3:00) + README 헤더에 임베드.

## E. 제출

- [ ] 학교 LMS 에 GitHub 리포 URL + YouTube 영상 URL 입력
- [ ] 첨부: 계획서 PDF (`docs/RoomieSync_계획서_엄민욱.pdf`)
- [ ] 제출 후 본인 학번/이름이 모든 산출물에 정확히 들어갔는지 1 번 더 확인

---

## 최후의 비상 대비

- 빌드 깨짐: `rm -rf ~/Library/Developer/Xcode/DerivedData/RoomieSync-*` 후 재빌드
- CloudKit 안 됨: 시뮬레이터 iCloud 로그아웃/재로그인, 또는 `xcrun simctl erase all`
- Live Activity 시뮬레이터 미지원 케이스: 실기기 사용
- 알림 권한 다이얼로그 안 뜸: 시뮬레이터 설정 → 알림 → RoomieSync 수동 활성화

## 비상 연락

문제 발생 시 — 본인이 직접 디버깅. 학생 프로젝트라 외부 도움 불가.
docs/progress.md 의 "알려진 이슈 / TODO" 섹션을 다시 정독.

---

**제출 완료 후**: README 의 향후 계획 섹션을 보고 Android 버전 / B2B / AI 추천 중 하나를 다음 학기 후속 과제로.
