# Git 워크플로우 가이드 — RoomieSync

작성자: 엄민욱 (2091188) · 2026-05-20

> Cowork 세션의 외부 네트워크 제약 (`api.github.com` 차단) + Personal Access Token 보안 위험으로
> **이 세션에서 git push / PR 자동 생성은 수행하지 않았습니다**.
> 학생이 macOS 에서 아래 명령을 순서대로 실행하세요.

---

## 0. 사전 준비 (1 회만)

```bash
# Git 설치 확인
git --version            # 2.30+ 권장

# (선택) GitHub CLI — PR 명령으로 생성하고 싶을 때
brew install gh
gh auth login
```

GitHub 에서 **빈 repository** 미리 생성:
- repo name: `roomiesync`
- visibility: 일단 Private, 제출 직전 Public 전환
- README / .gitignore / license **모두 체크 해제** (이미 있음)

---

## 1. 가장 단순한 워크플로우 — 단일 PR (권장)

학생이 직접 `git rebase -i` 등으로 commit 분리하지 않을 거라면 이 방법이 가장 깔끔.

### 1-1. 초기 push

```bash
cd <repo-root>

# 1) git 초기화
git init
git config user.name  "엄민욱"
git config user.email "gwangonair@gmail.com"

# 2) 첫 commit
git add .
git commit -m "chore: 4주 미니프로젝트 + 5건 리팩토링 완료 (4주차 종료 시점)

- Domain / Repository / Service / SwiftUI 5 화면 / 위젯 4종 / Live Activity 2종
- Swift Testing 28 어노테이션
- 리팩토링: AppKeys / SectionCard / AvatarColorPicker / DeviceIdentifierProvider /
  CKErrorMapper.userMessage 통일
- README / progress / cloudkit-setup / video-script / handoff / git-workflow 문서 6종"

# 3) 원격 등록 + push
git branch -M main
git remote add origin git@github.com:eomminwook/roomiesync.git
git push -u origin main
```

### 1-2. dev 브랜치 + PR

```bash
# dev 분기 + push
git checkout -b dev
git push -u origin dev

# PR 생성 — gh CLI
gh pr create \
  --base main \
  --head dev \
  --title "4주 미니프로젝트 + 리팩토링 5건 통합" \
  --body-file docs/PR_BODY_INTEGRATED.md
```

`docs/PR_BODY_INTEGRATED.md` 가 없으면 `scripts/_pr_bodies/*.md` 5개를 합쳐서 본문으로 사용하거나, 아래 명령으로 한 번에 생성:

```bash
cat scripts/_pr_bodies/*.md > docs/PR_BODY_INTEGRATED.md
```

### 1-3. gh CLI 없으면 — URL 클릭으로 PR

```bash
# push 후 다음 URL 을 브라우저에 붙여넣기
echo "https://github.com/eomminwook/roomiesync/compare/main...dev?expand=1"
```

GitHub 가 PR 작성 화면을 열어주면 본문에 `scripts/_pr_bodies/*.md` 의 내용 복붙.

---

## 2. 고급 워크플로우 — 5 commits 분리 (선택)

평가자에게 리팩토링 5건을 각각 단계적으로 보여주고 싶다면, `git rebase -i` 또는 직접 5 commit 만들기.

### 2-1. 직접 5 commit 만들기 (가장 정확)

```bash
# pre-refactor base 부터 시작하고 싶다면, 일단 위 1-1 의 first commit 직후:

# 5건 리팩토링을 각각 reverse → commit → 다시 forward → commit ... 방식은 복잡
# 차라리 5건 리팩토링 PR 본문을 보고 매번 변경분 일부만 stage 해서 commit 5 개로 분리:

git reset HEAD~1                    # main 의 마지막 commit 을 undo (staging 만 남김)

# 리팩토링 1 — AppKeys
git add RoomieSync/Core/Shared/AppKeys.swift \
        RoomieSync/Core/Shared/SharedSnapshot.swift \
        RoomieSync/Core/Shared/ChoreCompleteIntent.swift \
        RoomieSync/App/RootView.swift \
        RoomieSync/Core/Repository/ModelContainer+RoomieSync.swift
git commit -F scripts/_pr_bodies/app-keys.md

# 리팩토링 2 — SectionCard
git add RoomieSync/Core/UI/Components/SectionCard.swift \
        RoomieSync/Features/Home/HomeView.swift \
        RoomieSync/Features/Stats/StatsView.swift
git commit -F scripts/_pr_bodies/section-card.md

# 리팩토링 3 — AvatarColorPicker
git add RoomieSync/Core/UI/Components/AvatarColorPicker.swift \
        RoomieSync/Features/Group/GroupCreateView.swift
git commit -F scripts/_pr_bodies/avatar-picker.md

# 리팩토링 4 — DeviceIdentifierProvider
git add RoomieSync/Core/Services/DeviceIdentifierProvider.swift \
        RoomieSync/Core/UI/RepositoryEnvironment.swift \
        RoomieSync/Features/Chore/ChoreViewModel.swift
git commit -F scripts/_pr_bodies/device-provider.md

# 리팩토링 5 — CKErrorMapper + 회귀 테스트
git add RoomieSync/Core/Services/CKErrorMapper.swift \
        RoomieSync/Features/Home/HomeViewModel.swift \
        RoomieSync/Features/Expense/ExpenseViewModel.swift \
        RoomieSync/Features/Stats/StatsViewModel.swift \
        RoomieSyncTests/RefactorRegressionTests.swift
git commit -F scripts/_pr_bodies/error-message.md

# 나머지 모든 파일 (도메인 / Service / 화면 / 위젯 / 문서 등) 을 base commit 으로
# 위에 5개 commit 보다 더 오래된 commit 이 필요 — 더 복잡함
```

**솔직히** 이 방식은 git history 가 거꾸로 쌓여 깔끔하지 않습니다. 권장하지 않음.

### 2-2. 깨끗한 5 commit history 가 정말 필요하면

> 학생이 직접 시간 들여서 git checkout 으로 base 부터 단계적으로 만들어야 합니다.
> 이 가이드의 범위를 벗어나는 작업이라, 평가 가치보다 비용이 크다고 판단하면 1-1, 1-2 만 수행.

---

## 3. 5개 리팩토링 별도 PR 5개로 만들고 싶으면

```bash
# 각 리팩토링별로 dev → main 으로 PR 5개 생성 (모두 dev 의 같은 commit)
for R in app-keys section-card avatar-picker device-provider error-message; do
    gh pr create \
        --base main \
        --head dev \
        --title "refactor: $R" \
        --body-file scripts/_pr_bodies/$R.md \
        --draft
done
```

**주의**: dev 가 단일 commit 이라 5개 PR 의 diff 가 모두 동일. 리뷰 UX 가 안 좋음. 1-2 의 단일 PR 권장.

---

## 4. 제출 직전 — repository Public 전환

```bash
gh repo edit eomminwook/roomiesync --visibility public --accept-visibility-change-consequences

# 또는 GitHub 웹 — Settings → Danger Zone → Change visibility
```

---

## 5. PR 본문 5건 위치

`scripts/_pr_bodies/` 에 다음 5개 마크다운 파일이 준비되어 있음:

- `app-keys.md` — AppKeys enum 매직 스트링 통합
- `section-card.md` — SectionCard 공통 컴포넌트 추출
- `avatar-picker.md` — AvatarColorPicker 6색 팔레트 추출
- `device-provider.md` — DeviceIdentifierProvider 테스트 가능 인터페이스
- `error-message.md` — CKErrorMapper.userMessage(for: Error) 통일

학생이 PR 만들 때 그대로 복붙 또는 `--body-file` 옵션으로 사용.

---

## 6. 자주 발생하는 문제

### `git push` 시 `Permission denied (publickey)`
SSH key 미등록. HTTPS 로 전환:
```bash
git remote set-url origin https://github.com/eomminwook/roomiesync.git
```
다음 push 시 GitHub username / Personal Access Token 입력 (브라우저로 인증).

### `gh auth login` 후에도 PR 생성 실패
다음으로 권한 재확인:
```bash
gh auth refresh -h github.com -s repo
```

### 잘못된 commit 을 push 한 경우
```bash
# 마지막 commit 만 undo (변경은 보존)
git reset HEAD~1

# 또는 force push 로 history 덮어쓰기 (위험)
git push --force-with-lease origin main
```
