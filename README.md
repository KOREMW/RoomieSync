<div align="center">

# RoomieSync

> 룸메이트 가사 분담 자동 로테이션 + 공동 지출 자동 정산 iOS 앱

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0%2B-blue.svg)](https://developer.apple.com/ios)
[![Xcode](https://img.shields.io/badge/Xcode-26.5-1575F9.svg)](https://developer.apple.com/xcode)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5-brightgreen.svg)](https://developer.apple.com/xcode/swiftui)
[![SwiftData](https://img.shields.io/badge/SwiftData-iOS17%2B-blueviolet.svg)](https://developer.apple.com/documentation/swiftdata)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%2B%20Auth-FFCA28.svg)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

<p align="center">
  <img src="docs/screens/01_home.png" width="220" alt="홈">
  <img src="docs/screens/02_chore.png" width="220" alt="가사">
  <img src="docs/screens/05_stats.png" width="220" alt="통계">
</p>

[📺 시연 영상 보기 (YouTube)](https://youtube.com/watch?v=PLACEHOLDER) · <a href="docs/qr.png">📦 GitHub QR</a>

</div>

---

## ② 문제 정의

자취·셰어하우스 거주자 사이에서 **가사 분담 불균형** 과 **공동 지출 정산 누락** 두 갈등이 반복적으로 발생합니다. 카톡 메모는 공유는 되지만 자동화가 없고, 가계부 앱은 자동화는 있지만 공유가 없으며, 종이 당번표는 둘 다 없습니다.

> "야, 쓰레기 누구 차례야?" / "휴지 값 누가 냈더라?"

RoomieSync 는 이 두 페인을 **단 하나의 앱**에서 해결합니다. 가사는 멤버 순서대로 자동 회전, 지출은 채무 단순화 알고리즘으로 송금 횟수를 최소화. 게다가 위젯·Live Activity 로 "오늘 한 일"을 **앱을 열지 않고도** 즉시 확인할 수 있습니다.

## ③ 주요 기능

| 화면 | 기능 | 스크린샷 |
|---|---|---|
| 홈 | 모임 전환(헤더 탭) · 상단 **공지 배너** · 오늘 할 일 · 이번 주 정산 · 지출 분포를 한 화면에 | ![Home](docs/screens/01_home.png) |
| 가사 | 멤버 순서대로 **자동 배정** · 주기(매일/매주/매월/한 번) · **난이도** 설정 · 담당자·회전 순서 직접 지정 · **날짜가 지나면** 다음 멤버로 자동 회전(완료해도 그날 담당자는 유지, "취소"로 되돌리기) | ![Chore](docs/screens/02_chore.png) |
| 지출 | 카테고리별 입력 · 참여자 자동/직접 분배 · **검색·정렬** · 정산 대기/완료 필터 | ![Expense](docs/screens/03_expense.png) |
| 지출 추가 | 큰 ₩ 입력 + 결제자/참여자 시각적 선택 + 각자 부담 실시간 계산(더치페이/직접 입력) | ![Add](docs/screens/04_expense_add.png) |
| 통계 | 가사 완료 횟수 · **공정 지수(난이도 가중)** · 월별 추이 · 카테고리 도넛 · 🏆 MVP · **레벨·뱃지** | ![Stats](docs/screens/05_stats.png) |

추가 차별 기능:
- **정산 자동화** — 채무 단순화로 송금 횟수 최소화 + **토스·카카오페이 등 송금 앱 딥링크**/계좌 복사 + **송금 요청 알림** + **정산 히스토리**
- **월별 지출 내역** — 통계에서 진입, ◀▶ 로 달 이동 · 연/월 탭하면 바로 선택 · 해당 월 지출만 모아보기
- **인앱 알림함** — 송금 요청·완료·새 지출·새 가사·공지를 한 곳에 모아보기(스와이프 삭제·전체 삭제·탭하면 해당 화면으로 이동)
- **반복 지출** — "관리비 매월 25일" 같은 고정 지출 템플릿으로 자동 생성
- **공지 보드** — 그룹 공유 공지(고정/삭제) + 새 공지 시 홈 배너 **NEW 강조** + 알림 + 작성자 아바타
- **게이미피케이션** — 난이도 가중 포인트 기반 **레벨/타이틀**, 연속 달성(현재·최고), 주간 목표, 진행형 뱃지(탭하면 획득 방법 설명)
- **멀티 그룹** — 초대 코드로 합류(최대 6인), 여러 모임 전환, **그룹별 데이터 격리**(멤버십 기반 보안 규칙)
- **개인화** — 모임 이름·아이콘·색, 멤버 아바타 색·이모지(동물/모양), 마이페이지 탭 아이콘에 내 아바타 반영
- **위젯 4종** — Small / Medium 홈 위젯, accessoryCircular / Inline / Rectangular 잠금화면 위젯 (위젯에서 직접 완료)
- **Live Activity 2종** — 가사 진행 중 + 정산 카운트다운 (Dynamic Island compact / expanded / minimal)
- **로컬 알림 7종** — 오전 당번 · 저녁 미완료 · 룸메 완료 · 지출 입력 · 새 가사 · 새 공지 · 송금 요청 (배너 + 알림에서 바로 완료/교대, 탭하면 해당 화면으로 이동)
- **클라우드 동기화** — Firebase Firestore(익명 인증)로 같은 그룹 멤버 간 기기 동기화 (상대가 앱을 열면 동기화 시점에 로컬 알림 발송)

> 현재 미구현(향후): 영수증 사진 첨부(데이터 모델만 존재). 알림은 로컬 알림이며, 다른 기기로의 원격 푸시는 Apple Developer Program(APNs)이 있어야 동작합니다.

## ④ 기술 스택

| 분류 | 선택 | 이유 |
|---|---|---|
| 언어 | Swift 6.0 (strict concurrency) | @Observable + @MainActor + Sendable, actor 기반 동시성 안전 |
| UI | SwiftUI + iOS 17 @Observable | 보일러플레이트 최소, Combine 의존 제거 |
| 영속(로컬) | SwiftData | CoreData 대비 코드 양 절반, @Model 기반 |
| 동기화(운영) | **Firebase Firestore + Auth(익명)** | 서버 무구축, 무료 한도 충분, 기기 간 공유 + 보안 규칙으로 그룹 격리 |
| 동기화(선택) | CloudKit Private + Shared | 폴백 경로. iCloud/CloudKit·푸시는 Apple Developer Program 필요 |
| 차트 | Swift Charts | 네이티브 LineMark / SectorMark, 외부 라이브러리 0 |
| 알림 | UserNotifications (Local) | APNs 인증서 불필요, 7 시나리오 모두 로컬로 처리 + 알림 액션·라우팅 |
| 위젯 | WidgetKit + AppIntent | iOS 17 configurable widget + 위젯에서 직접 완료 |
| Live Activity | ActivityKit | Dynamic Island 3 레이아웃 + 잠금화면 |
| 의존성 관리 | XcodeGen (project.yml) + SPM(firebase-ios-sdk) | .xcodeproj 충돌 0, 폴더 구조 변경에 유연 |

## ⑤ 아키텍처

**MVVM + Repository Pattern** — 도메인은 백엔드에 의존하지 않고, 동일 프로토콜의 3가지 구현(InMemory/SwiftData/Firestore)을 런타임에 주입한다.

```
┌───────────────────────────────────────────────────┐
│ Presentation                                      │
│  SwiftUI Views + @Observable ViewModels           │
└─────────────────────────┬─────────────────────────┘
                          │ async/await
┌─────────────────────────▼─────────────────────────┐
│ Domain                                            │
│  Group · Member · Chore · Expense · Settlement ·  │
│  GroupNote / SettlementCalculator(그리디 매칭) ·    │
│  ChoreRotation · ConflictResolver                 │
└─────────────────────────┬─────────────────────────┘
                          │ protocol (Group/Chore/Expense Repository)
┌─────────────────────────▼─────────────────────────┐
│ Repository (3 protocol × 3 구현)                   │
│  InMemory(Preview/테스트) · SwiftData(로컬) ·       │
│  Firestore(클라우드, 익명 인증 게이트)               │
└─────────────────────────┬─────────────────────────┘
                          │
┌─────────────────────────▼─────────────────────────┐
│ Platform Services                                 │
│  Firebase(Firestore/Auth) · CloudKit(선택) ·       │
│  UserNotifications · WidgetKit · ActivityKit ·    │
│  HapticManager · NetworkMonitor                   │
└───────────────────────────────────────────────────┘
```

폴더 트리(요약):

```
RoomieSync/
├── README.md · LICENSE(MIT) · project.yml(XcodeGen) · firestore.rules
├── docs/        (progress · firebase-setup · cloudkit-setup · security · video-script · handoff · screens/)
├── RoomieSync/
│   ├── App/          (@main · RootView · MainTabView)
│   ├── Features/     (Group · Chore · Expense · Stats · Home · Notes · Onboarding · Settings)
│   ├── Core/
│   │   ├── Domain/        (Pure Swift struct: Group/Member/Chore/Expense/Settlement/GroupNote)
│   │   ├── Repository/    (Protocols + InMemory + SwiftData + Firestore + Entities)
│   │   ├── Services/      (Settlement · Rotation · Conflict · Notification · CloudKit · Haptic …)
│   │   ├── Shared/        (위젯 ↔ 메인앱 AppGroup DTO · InputValidator · AppKeys)
│   │   └── UI/            (DesignSystem + 공통 컴포넌트: 아바타/색·아이콘 피커 등)
│   ├── Widget/       (WidgetKit Extension)
│   ├── LiveActivity/ (ActivityKit)
│   └── Resources/    (Localizable.strings · Assets.xcassets)
└── RoomieSyncTests/  (Swift Testing)
```

## ⑥ 빌드 방법

### 사전 조건

- macOS 26 (Tahoe) 이상 · Xcode 26.5 (Swift 6, iOS 17 SDK)
- Apple ID (Personal Team 으로 시뮬레이터 실행 충분 — Firestore·로컬 알림은 유료 프로그램 불필요)
- Homebrew (XcodeGen)

### 빌드 단계

```bash
# 1. XcodeGen 설치 (최초 1회)
brew install xcodegen

# 2. 클론
git clone https://github.com/KOREMW/RoomieSync.git
cd RoomieSync

# 3. Firebase 설정 파일 추가 (필수)
#    Firebase 콘솔에서 받은 GoogleService-Info.plist 를 RoomieSync/ 에 배치
#    (보안상 .gitignore 처리되어 저장소에는 포함되지 않음)

# 4. Xcode 프로젝트 생성 + 실행
xcodegen generate
open RoomieSync.xcodeproj   # ⌘R 실행
```

Firebase 백엔드 사용 시(권장):
1. Firebase 콘솔 → **Authentication → 익명 로그인 사용**
2. **Firestore Database** 생성 후, [`firestore.rules`](firestore.rules) 내용을 규칙 탭에 게시
3. 자세한 절차는 [`docs/firebase-setup.md`](docs/firebase-setup.md) · 보안 설계는 [`docs/security.md`](docs/security.md)

> `GoogleService-Info.plist` 가 없으면 Firebase 는 비활성화되고 앱은 로컬(SwiftData) 백엔드로 동작합니다. CloudKit 동기화는 선택 경로이며 Apple Developer Program 이 필요합니다.

## ⑦ 핵심 알고리즘 — 채무 단순화 (Debt Simplification)

각 멤버의 순잔액 (받을 돈 − 줄 돈) 을 계산한 뒤 그리디 매칭으로 채권자·채무자를 연결하여 송금 횟수를 최소화. 최악의 경우 **N-1** 번 송금으로 정산 종료. (참여자별 커스텀 분배도 `expense.share(for:)` 로 반영)

### 의사 코드

```
function calculate(expenses, members):
    # 1. 각 멤버 net_balance = (받을 돈) - (줄 돈)
    net = {}
    for e in expenses:
        net[e.paidBy] += e.amount
        for p in e.participants:
            net[p] -= e.share(for: p)   # 균등 또는 커스텀 분배

    # 2. 양수 큐(채권자), 음수 큐(채무자) 분리·정렬
    creditors = sorted([(m, b) for m, b in net if b > 0], desc=b)
    debtors   = sorted([(m, -b) for m, b in net if b < 0], desc=b)

    # 3. 두 큐의 head 끼리 min(|채권|, |채무|) 매칭
    settlements = []
    while creditors and debtors:
        c = creditors[0]; d = debtors[0]
        pay = min(c.amount, d.amount)
        settlements.append(Settlement(from=d.member, to=c.member, amount=pay))
        c.amount -= pay
        d.amount -= pay
        if c.amount == 0: creditors.pop(0)   # 4. 0 이 된 쪽 제거
        if d.amount == 0: debtors.pop(0)

    return settlements
```

### 입출력 예시

**입력**: 3 인 그룹, 5 건 지출
```
김지훈 결제: 휴지 9,900 (3명 참여)
박서연 결제: 세제 15,800 (3명)
이민호 결제: 전기요금 42,000 (3명)
박서연 결제: 가스요금 31,800 (3명)
김지훈 결제: 장보기 38,000 (3명)
```

총 합 137,500원 ÷ 3명 = 1인당 부담 45,833원 (소수점 절사).

각자 결제한 금액:
- 김지훈: 9,900 + 38,000 = 47,900원
- 박서연: 15,800 + 31,800 = 47,600원
- 이민호: 42,000원

**net_balance** (결제 − 부담):
- 김지훈: 47,900 − 45,833 = **+2,067**
- 박서연: 47,600 − 45,833 = **+1,767**
- 이민호: 42,000 − 45,833 = **−3,833**

KRW 단위 절사로 생기는 미세 잔차는 `SettlementCalculator` 가 epsilon 으로 흡수.

**출력 (그리디 매칭)**:
1. 이민호 → 김지훈 2,067원
2. 이민호 → 박서연 1,766원

3 인 그룹의 최악(단순 1:1 매칭) 3 회 송금이 **2 회** 로 단축. N 인 그룹 일반화 시 ≤ N−1 회 보장.

복잡도: O(N log N) 정렬 + O(N) 매칭. N = 멤버 수.

## ⑧ 테스트

```bash
# Xcode UI
⌘U

# 또는 CLI
xcodebuild test -scheme RoomieSync \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

**Swift Testing**(`@Test`) 기반 단위 테스트로 핵심 순수 로직을 검증:
- `SettlementCalculatorTests` — 3·4·5 인 정산 시나리오(파라미터화) + 잔차 invariant
- `RotationTests` — round-robin / swap / 멤버 추가·제거 / wrap-around
- `ConflictResolverTests` — last-write-wins / settled 우선
- `OfflineQueueTests` — flush / 실패 중단·재시도
- `CKErrorMapperTests` — network / quota / conflict / notAuthenticated 매핑

## ⑨ 보안

- **익명 인증 게이트**: 모든 Firestore 작업 전 익명 로그인 완료를 보장(권한 레이스 방지).
- **그룹별 격리**: `firestore.rules` 가 멤버십(uid ↔ 그룹 memberUIDs) 기반으로 read/write 를 제한.
- **입력 검증**: `InputValidator` 로 길이·제어문자·계좌(숫자) 정규화.
- **민감정보 최소화**: 계좌번호 마스킹·로컬 전용 클립보드(60초 만료), `GoogleService-Info.plist` 는 커밋 제외.
- 자세한 내용: [`docs/security.md`](docs/security.md)

## ⑩ 향후 계획

- **영수증 사진 첨부** — PhotosPicker + (Firestore 1MB 한계로) Cloud Storage 연동.
- **Sign in with Apple** — 익명 인증의 기기 분실 시 복구 한계 보완.
- **원격 푸시(APNs)** — 다른 기기 실시간 알림(개발자 프로그램 필요).
- **Android / KMP** — 도메인·정산 알고리즘 공유, UI 만 Compose 재작성.

## ⑪ 라이선스 & 연락

[MIT License](LICENSE) — 자유로운 사용, 수정, 배포 가능.

- 작성자: **엄민욱** (학번 2091188)
- 소속: 한성대학교 컴퓨터공학
- 과목: iOS 프로그래밍 기말 미니프로젝트
- 이메일: gwangonair@gmail.com

> 학기 중 만든 학생 프로젝트입니다. 버그 리포트 / 개선 제안 환영 — GitHub Issues 로 남겨주세요.
</content>
</invoke>
