# 친구 아이폰에 직접 설치하기 (무료, 케이블 연결)

Apple Developer Program 없이 **무료 Apple ID(개인 팀)**로 친구의 아이폰에 RoomieSync 를
설치하는 방법. 친구 폰을 내 맥에 **직접 연결**할 수 있을 때 사용한다.

> 핵심 제약(무료 개인 팀)
> - **iCloud·푸시·App Group capability 사용 불가** → 이 3가지를 빼고 빌드해야 설치된다.
>   (위젯·Live Activity 의 데이터 공유는 App Group 에 의존하므로 **위젯은 동작하지 않음**)
> - 설치 후 **7일 뒤 만료** → 다시 연결해서 재설치 필요
> - 한 기기에 무료 사이드로드 앱 **최대 3개**
> - **정상 동작**: 모임/가사/지출/정산/공지/통계, Firestore 동기화, 로컬 알림, 토스 송금 링크(실기기)

## 사전 준비
- 내 맥 + Xcode 26.5, 친구 아이폰 + 라이트닝/USB‑C 케이블
- 내 **무료 Apple ID** (Xcode → Settings → Accounts 에 추가)
- `RoomieSync/GoogleService-Info.plist` 가 있어야 함(없으면 Firebase 비활성 → 동기화 안 됨)
- Firebase 콘솔에서 **익명 인증 ON + `firestore.rules` 게시** 완료

## 설치 절차

### 1. 프로젝트 생성
```bash
cd RoomieSync
xcodegen generate
open RoomieSync.xcodeproj
```

### 2. 위젯 타깃 제외 (App Group 때문에 빌드 실패 방지)
- 상단 스킴 선택 → **Edit Scheme… → Build** 에서 `RoomieSyncWidgets` 체크 해제
- `RoomieSync` 타깃 → **General → Frameworks, Libraries, and Embedded Content** 에서
  `RoomieSyncWidgets.appex` 가 있으면 **삭제(−)**

### 3. 서명 & capability 정리 (`RoomieSync` 타깃 → Signing & Capabilities)
- **Team**: 내 무료 Apple ID 선택
- **Bundle Identifier**: 전 세계 유일해야 하므로 변경 (예: `com.<내이름>.roomiesync`)
  - Firebase 는 프로젝트 단위 접근이라 번들 ID 가 달라도 동기화엔 지장 없음(경고 로그만)
- 아래 capability 카드가 있으면 **삭제(×)**:
  - **iCloud** (CloudKit)
  - **Push Notifications**
  - **App Groups**
  - (있다면) **Background Modes 의 Remote notifications** 체크 해제
- 로컬 알림은 capability 가 필요 없으므로 그대로 둬도 됨

### 4. 친구 아이폰 연결 & 신뢰
- 케이블로 연결 → 아이폰에 "이 컴퓨터를 신뢰" 뜨면 **신뢰**
- Xcode 상단 실행 대상에서 **친구의 아이폰** 선택

### 5. 빌드 & 실행
- `⌘R` (Run)
- 처음엔 "신뢰되지 않은 개발자" 로 실행이 막힐 수 있음 → **친구 아이폰에서**
  **설정 → 일반 → VPN 및 기기 관리 → (내 Apple ID) → 신뢰** 후 앱 다시 실행

### 6. 알림 권한 허용
- 앱 첫 실행 시 알림 권한 요청 → **허용** (로컬 알림: 당번/지출/공지 등)

## 같은 모임에서 정산 검증하기
1. 한쪽(내 시뮬레이터 또는 폰)에서 **새 그룹 생성** → 초대코드 공유
2. 친구가 앱에서 **초대코드로 참여**
3. 각자 **지출 입력** → 상대 화면 새로고침하면 반영
4. **정산하기** → 채무 단순화 결과·계좌·송금 링크 확인 → **정산 완료로 표시**

> 같은 Firebase 프로젝트(같은 `GoogleService-Info.plist`)면 **내 시뮬레이터 ↔ 친구 실기기**도
> 같은 그룹에서 동기화된다. 단, #14 격리 규칙 적용 후에는 **새로 만든 그룹**에서 테스트할 것.

## 7일 뒤 만료되면
- 친구 폰을 다시 내 맥에 연결 → `⌘R` 재실행 (데이터는 Firestore 에 있으므로 유지됨)

## 자주 막히는 부분
| 증상 | 원인 / 해결 |
|---|---|
| `Personal development teams do not support … capability` | iCloud/푸시/App Group 미삭제 → 3번 단계 다시 확인 |
| `Failed to register bundle identifier` | 번들 ID 중복 → 더 고유하게 변경 |
| 앱이 실행 직후 "신뢰되지 않음" | 5번의 기기 관리에서 개발자 신뢰 |
| 동기화 안 됨 | GoogleService-Info.plist 누락 / 익명 인증·규칙 미게시 / 네트워크 |
| 위젯이 안 보임 | 무료 설치에선 App Group 불가 → 정상(앱 본체만 동작) |
</content>
