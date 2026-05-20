## refactor: AppKeys enum — 매직 스트링 통합

### 배경

4 주차 종료 시점, AppStorage 키 / AppGroup ID / CloudKit 컨테이너 ID / URL Scheme / Notification 카테고리 ID 등 같은 의미의 문자열이 여러 파일에 산재되어 있었습니다. 오타 1 글자만 발생해도 위젯이 메인 앱과 데이터 공유를 못 하거나 AppStorage 가 새 변수로 인식하는 등 미묘한 버그 발생 가능.

### 변경 내용

- **신규**: `RoomieSync/Core/Shared/AppKeys.swift` — Storage / AppGroup / CloudKit / URLScheme / NotifyCategory / NotifyAction / WidgetKind namespace 통합
- **변경** (5 파일):
  - `Core/Shared/SharedSnapshot.swift` — appGroupID / userDefaultsKey
  - `Core/Shared/ChoreCompleteIntent.swift` — PendingWidgetActions.key
  - `App/RootView.swift` — `@AppStorage` 키 2 개 + Preview removeObject
  - `Core/Repository/ModelContainer+RoomieSync.swift` — CloudKit 컨테이너 ID

### 효과

- 매직 스트링 11 건 → 단일 namespace
- 새 키 추가 시 한 곳에서 관리, 오타 위험 제거
- 컴파일러가 자동완성 / 타입 체크

### 테스트

회귀 방지: `RefactorRegressionTests.swift` 의 `appKeys` 테스트 — namespace 일관성 검증.
