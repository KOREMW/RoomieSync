# CloudKit Setup 가이드 (3주차)

작성자: 엄민욱 (2091188) · 2026-06-02

본 문서는 RoomieSync 가 CloudKit 으로 동기화·공유되도록 Apple Developer Console / Xcode Capabilities / 코드 측 설정을 모두 잡는 단계별 가이드입니다. 그대로 따라 하면 본인 Apple ID 만으로 시뮬레이터 2 대 또는 시뮬레이터 + 실기기 사이에 데이터가 실시간 동기화됩니다.

## 1. 사전 조건

* macOS Tahoe 26.4.1, Xcode 26.5
* Apple ID 1 개 — Personal Team 으로도 CloudKit 가능. 단 `CKShare` 의 "초대 링크 공유" 일부 기능은 Apple Developer Program (유료 $99/yr) 가입자만 안정적으로 동작합니다. 미가입이면 코드 자체는 작동하지만 시연 영상에서 공유 링크 데모는 시뮬레이터 2 대 동기화로 대체.
* iCloud 로그인된 시뮬레이터/기기 (`설정 → 본인 이름 → iCloud Drive ON`)

## 2. Apple Developer Console 컨테이너 생성

> Developer Program 미가입 시 이 단계 건너뛰고 §3 의 "Personal Team 자동 컨테이너" 로.

1. <https://developer.apple.com/account/resources/cloudkit/dashboard> 접속
2. 좌측 `Containers` → `＋` → 다음 값 입력:
   * **Identifier**: `iCloud.com.roomiesync.app`
   * **Description**: `RoomieSync — 룸메이트 가사·지출 공유 컨테이너`
3. 저장 후 `Schema` 탭 → `Record Types` 가 비어있는 것을 확인 (앱 첫 실행 시 SwiftData 가 자동 생성)
4. `Environment` 셀렉터에서 `Development` 가 기본. **배포 전에 `Deploy Schema to Production` 클릭 필수** (4 주차 마무리에서).

## 3. Xcode Signing & Capabilities

### 3.1 Team 선택

1. `RoomieSync.xcodeproj` 열기 → 좌측 RoomieSync 타깃 선택
2. `Signing & Capabilities` 탭 → `Team` 드롭다운에서 본인 Apple ID 선택
3. Bundle Identifier 가 자동으로 `<TeamID>.com.roomiesync.app` 형태로 prefix 붙음

### 3.2 Capability 3 개 추가

좌측 상단 `＋ Capability` 버튼으로 다음 3개 추가:

1. **iCloud**
   * `Services` 체크 → ☑ CloudKit
   * `Containers` 섹션에서 `＋` → 위에서 만든 `iCloud.com.roomiesync.app` 선택 (Personal Team 은 자동으로 `iCloud.$(CFBundleIdentifier)` 사용)
2. **Push Notifications** — 체크박스만 켜면 됨
3. **Background Modes**
   * ☑ Remote notifications (CloudKit silent push 수신)
   * ☑ Background fetch (월말 정산 알림 등 주기 작업)

> Xcode 가 자동으로 `RoomieSync.entitlements` 파일을 생성하고 위 권한들을 기록합니다. 본 리포지토리는 `RoomieSync/RoomieSync.entitlements` 에 동일 내용을 미리 커밋해두었으니, Xcode 가 덮어쓰면 git diff 로 의도된 변경인지 확인하세요.

### 3.3 스크린샷 체크리스트

다음 화면이 모두 정상이면 §4 로 진행:

* `Signing & Capabilities` 탭 → Team 표시됨, Bundle ID 충돌 없음
* `iCloud` 박스 안에 컨테이너 1 개 체크됨, ⚠️ 표시 없음
* `Push Notifications` 박스 존재
* `Background Modes` 안에 Remote notifications / Background fetch 체크됨

## 4. 코드 측 활성화

### 4.1 `ModelContainer` cloudKitDatabase 활성화

3 주차에 다음과 같이 활성화됩니다 (이미 코드에 반영됨, 컨테이너 ID 만 확인):

```swift
let config = ModelConfiguration(
    "RoomieSync",
    schema: schema,
    isStoredInMemoryOnly: false,
    allowsSave: true,
    cloudKitDatabase: .private("iCloud.com.roomiesync.app")
)
```

### 4.2 ShareController — 그룹 공유

`Core/Services/ShareController.swift` 가 `CKShare` 를 생성/수락합니다. UI 는 `UICloudSharingController` 를 SwiftUI 로 래핑한 `CloudSharingView` (`Features/Group/CloudSharingView.swift`) 가 담당.

### 4.3 Universal Link & 초대 코드 백업

CloudKit 공유 URL 이 만료되거나 받는 쪽이 iCloud 미로그인 상태인 경우를 대비해 기존 6 자리 초대 코드는 그대로 유지합니다. CKShare 와 InviteCode 는 서로 독립적인 경로.

## 5. 시뮬레이터/기기 테스트

### 5.1 시뮬레이터 2 대 동기화 확인

1. Xcode → `Window → Devices and Simulators` → 시뮬레이터 2 개 부팅 (`iPhone 15 Pro` + `iPhone 15`)
2. 각 시뮬레이터의 `Settings → Sign in to your iPhone` 에서 동일 Apple ID 로 로그인
3. 첫 번째 시뮬레이터에서 그룹 생성 → 두 번째에서 같은 초대코드 입력
4. 한쪽에서 가사 추가 / 지출 입력 → 다른 쪽에서 ≤ 10 초 내 반영 확인 (CloudKit silent push 트리거)

### 5.2 푸시 알림 시뮬레이터 트리거

푸시 알림 5 종은 `NotificationService.scheduleAll(for: groupID)` 호출 시 모두 예약됩니다. 즉시 트리거 테스트는:

```bash
# 시뮬레이터 활성화 상태에서
xcrun simctl push booted com.roomiesync.app docs/test-notifications/morning_duty.apns
```

각 .apns 페이로드 샘플은 `docs/test-notifications/` 에 4 주차에 추가.

## 6. 알려진 함정

1. **시뮬레이터에서 처음 CloudKit 요청 시 ~30 초 지연** — iCloud Drive 초기 동기화 대기. 정상.
2. **`CKError.notAuthenticated`** — iCloud 미로그인. 사용자에게 "iCloud 로그인 필요" 다이얼로그로 안내.
3. **`CKError.quotaExceeded`** — Personal Team 무료 한도 (1 GB) 초과. 영수증 이미지가 크면 발생.
4. **Development → Production 스키마 누락** — 4 주차 제출 전에 `Deploy Schema` 클릭 잊지 말 것.
5. **Schema migration 시 `inverse` 변경 금지** — Production 배포된 후에는 `@Relationship(inverse:)` 변경이 깨짐. 1 주차에 결정한 inverse 그대로 유지.

## 7. 트러블슈팅 명령

```bash
# 컨테이너 권한 새로고침 (캐시 꼬임 의심 시)
sudo killall -KILL cloudd

# 시뮬레이터 CloudKit reset
xcrun simctl erase all

# 빌드 산출물 클린
cd <repo-root> && rm -rf ~/Library/Developer/Xcode/DerivedData/RoomieSync-*
```
