# Firebase Firestore 백엔드 설정 (CloudKit 대안)

RoomieSync는 그룹 공유·동기화 백엔드로 **CloudKit**과 **Cloud Firestore**를 모두 지원합니다.
Firestore 백엔드는 **유료 Apple Developer Program 없이도** 여러 사람이 시뮬레이터/기기에서
같은 그룹을 공유할 수 있게 해줍니다.

## 백엔드 선택 방식

앱 시작 시 `FirebaseBootstrap.configureIfAvailable()`가 번들에 `GoogleService-Info.plist`가
있는지 확인합니다.

| GoogleService-Info.plist | 사용 백엔드 |
|---|---|
| 있음 | **Cloud Firestore** (그룹/가사/지출 동기화) |
| 없음 | 기존 **SwiftData(+CloudKit)** / iCloud 미로그인 시 로컬 전용 |

즉, plist를 추가하면 Firestore로, 빼면 기존 동작으로 자동 전환됩니다. Firebase SDK가
링크되지 않아도(`#if canImport`) 앱은 그대로 컴파일됩니다.

## 설정 단계

1. **Firebase 프로젝트 생성** — https://console.firebase.google.com → "프로젝트 추가".
2. **iOS 앱 등록** — Bundle ID에 `com.roomiesync.app` 입력.
3. **`GoogleService-Info.plist` 다운로드** → `RoomieSync/RoomieSync/` 폴더에 넣고
   `project.yml`의 메인 앱 `sources` 에 포함되도록 함(Resources 그룹 아래 두면 자동 포함).
   - 민감 정보이므로 `.gitignore`에 추가 권장: `GoogleService-Info.plist`
4. **Firestore 데이터베이스 생성** — 콘솔 → Firestore Database → "데이터베이스 만들기".
5. **보안 규칙** — PoC는 인증 없이 동작하므로 임시로 테스트 규칙 사용:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{db}/documents {
       match /{document=**} {
         allow read, write: if true;   // ⚠️ PoC 전용. 운영 전 반드시 인증 기반 규칙으로 교체
       }
     }
   }
   ```
6. **`xcodegen generate` → 빌드 → 실행.** 콘솔 로그에 `✅ Firebase 구성 완료`가 보이면 Firestore 사용 중.

## 데이터 구조

```
groups/{groupId}                 # name, inviteCode, createdAt, memberIDs
  members/{memberId}
  chores/{choreId}
  choreCompletions/{completionId}
  expenses/{expenseId}
  settlements/{settlementId}
```

- **초대 코드 합류가 서버에서 동작**: `findGroup(byInviteCode:)`가 Firestore를 조회하므로,
  다른 사람이 코드만 입력하면 그 그룹의 가사·지출을 함께 보고 편집할 수 있습니다.

## PoC 제약 / 운영 전 보완 사항

- **인증 없음**: 위 테스트 규칙은 누구나 읽기/쓰기가 가능합니다. 운영에서는 익명 인증 또는
  Sign in with Apple + 멤버십 기반 보안 규칙이 필요합니다.
- **`fetchAllGroups()`**는 전체 `groups`를 반환합니다(사용자 스코프 없음). 인증 도입 후
  `memberIDs` arrayContains 쿼리로 한정해야 합니다.
- **영수증 이미지(`receiptImageData`)는 동기화 제외**: Firestore 문서 1MB 제한 때문.
  필요 시 Cloud Storage로 분리하세요.
- **실시간 업데이트**: 현재는 fetch 기반(요청-응답). `addSnapshotListener`로 실시간 반영을
  추가할 수 있습니다(기존 Repository 프로토콜은 요청-응답이라 별도 반응형 레이어 필요).
- **금액**은 `Double`(원 단위 정수)로 저장됩니다.

## 아키텍처 메모

Repository 패턴 덕분에 백엔드 교체가 **구현체 추가만으로** 끝납니다:
`InMemory*` / `SwiftData*` 와 동일한 `*RepositoryProtocol`을 구현한
`Firestore*Repository`(`Core/Repository/Firestore/`)를 추가했고, ViewModel·View는 변경하지 않았습니다.
