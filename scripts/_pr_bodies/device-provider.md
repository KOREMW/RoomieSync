## refactor: DeviceIdentifierProvider — 테스트 가능 인터페이스

### 배경

`ChoreViewModel.deviceIdentifier()` 가 `#if canImport(UIKit)` 분기 + `UIDevice.current.identifierForVendor` 를 직접 호출. ViewModel 단위 테스트 작성 시 UIKit 의존성 때문에 mock 주입 불가.

### 변경 내용

- **신규**: `Core/Services/DeviceIdentifierProvider.swift`
  - `DeviceIdentifierProviding` protocol
  - `DeviceIdentifierProvider` — 운영용 (UIDevice 래핑)
  - `FixedDeviceIdentifierProvider` — 결정적 테스트용
- **변경**:
  - `Core/UI/RepositoryEnvironment.swift` — `RepositoryBundle` 에 `device` 필드 추가, `.live()` / `.preview()` 모두 갱신
  - `Features/Chore/ChoreViewModel.swift` — `#if canImport(UIKit)` 제거, `device.deviceIdentifier()` 사용

### 효과

- ViewModel 의 UIKit 직접 의존성 0
- 단위 테스트에서 `FixedDeviceIdentifierProvider("test-A")` 주입 → 결정적 결과

### 테스트

회귀 방지: `fixedDevice` / `defaultDevice` 2 케이스.
