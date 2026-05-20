## refactor: AvatarColorPicker — 6색 팔레트 선택 UI 추출

### 배경

`GroupCreateView` 와 `GroupJoinView` 가 동일한 6 색 팔레트 ForEach UI 와 `colorHex(at:)` 헬퍼를 각자 정의. 색상 추가 시 두 곳을 동시에 고쳐야 함.

### 변경 내용

- **신규**: `Core/UI/Components/AvatarColorPicker.swift`
  - `AvatarColorPicker` — Binding 기반 SwiftUI 컴포넌트
  - `AvatarPalette.hexValues` / `hex(at:)` — Domain 호환 hex 문자열 (wrap-around 안전)
- **변경**:
  - `Features/Group/GroupCreateView.swift` — 팔레트 UI 2 곳 + colorHex 헬퍼 제거

### 효과

- 중복 33 라인 제거
- 팔레트 색 변경 시 1 곳 (`Tokens.avatarPalette` + `AvatarPalette.hexValues`)
- 접근성 라벨 추가 (`accessibilityLabel("아바타 색상 N")`)

### 테스트

회귀 방지: `avatarPalette` 테스트 — 6 색 정확성 + wrap-around (index 100 → 100 % 6) + `Tokens.avatarPalette` 와의 개수 일치.
