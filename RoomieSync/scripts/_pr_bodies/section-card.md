## refactor: SectionCard 공통 컴포넌트 추출

### 배경

`HomeView.swift` 와 `StatsView.swift` 가 동일한 `cardContainer<Content>` private 함수를 각각 정의하고 있었습니다. 둘 다 흰 배경 + 둥근 모서리 + 그림자 + 좌우 padding 동일.

### 변경 내용

- **신규**: `Core/UI/Components/SectionCard.swift`
- **변경**:
  - `Features/Home/HomeView.swift` — `cardContainer {` → `SectionCard {` (3 곳), private 함수 삭제
  - `Features/Stats/StatsView.swift` — 동일 (4 곳)

### 효과

- 중복 28 라인 제거
- 카드 스타일 변경이 필요할 때 1 곳만 수정

### 테스트

기존 `#Preview` 21 개 → 22 개 (SectionCard preview 추가). 시각적 회귀는 학생이 macOS Xcode 에서 ⌘ + ⏎ Preview 로 확인.
