## refactor: ViewModel 에러 메시지 통일 — CKErrorMapper.userMessage(for: Error)

### 배경

각 ViewModel 의 catch 블록이 모두 다른 한국어 prefix 와 `error.localizedDescription` 의 영어 메시지 (예: `The operation couldn't be completed.`) 를 노출. 사용자는 같은 네트워크 오류를 5 가지 다른 문장으로 보게 됨.

### 변경 내용

- **변경**: `Core/Services/CKErrorMapper.swift`
  - `userMessage(for error: Error)` 오버로드 추가 — RepositoryError 변환 후 위임
- **변경** (5 파일, 14 곳):
  - `Features/Home/HomeViewModel.swift`
  - `Features/Chore/ChoreViewModel.swift` (6 곳)
  - `Features/Expense/ExpenseViewModel.swift` (3 곳)
  - `Features/Stats/StatsViewModel.swift`
  - `Features/Group/GroupCreateView.swift` (2 곳)
- **신규**: `RoomieSyncTests/RefactorRegressionTests.swift` (5 케이스)
- **변경**: `docs/progress.md` — "부록 — 코드 리팩토링" 섹션 추가

### 효과

- 사용자 노출 `error.localizedDescription` 12 건 → 0
- 모든 에러 메시지가 일관된 한국어 톤 + 액션 가이드 ("잠시 후 다시 시도", "iCloud 로그인 필요" 등)

### 의도적으로 남긴 것

- `SwiftDataXxxRepository` 내부 6 건의 `error.localizedDescription` — `RepositoryError.persistenceFailure(underlying:)` 의 디버그 정보 보존용, 사용자 노출 X
- `print("⚠️ ...")` 디버그 로그 (CloudSharingView / LiveActivityController) — 운영 로그

### 테스트

회귀 방지: `errorMessageOverload` — RepositoryError.networkUnavailable → "인터넷" 문구 포함.
