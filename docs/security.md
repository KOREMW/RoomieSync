# 보안 조치 (Security)

RoomieSync 에 적용한 취약점 방어와, 운영 전 권장 사항을 정리한다.

## 적용된 방어

| 영역 | 조치 |
|---|---|
| 입력 검증 | `InputValidator` 로 이름/제목/메모/계좌/초대코드의 **공백·제어문자 제거 + 최대 길이 절단**. 각 입력 화면 저장 시 적용. |
| 계좌(민감정보) | 계좌번호 **숫자만 입력 + 기본 마스킹(SecureField)**, '눈' 버튼으로만 노출. 클립보드 복사는 **60초 후 자동 삭제 + 기기 로컬 전용**. |
| Firestore 접근 | 앱 시작 시 **Firebase 익명 인증**(FirebaseBootstrap) → `firestore.rules` 의 *인증 필수* 규칙과 결합. 비인증 공개 접근 차단. |
| Firestore 규칙 | `firestore.rules` — 테스트 모드(전체 공개)를 대체. 인증 필요 + 필드 길이 가드. |
| 로깅 | 진단 로그를 `#if DEBUG` 로 한정해 릴리스 빌드 정보 노출 최소화. (자격증명·계좌는 애초에 로깅하지 않음) |
| 송금 링크 | 토스 딥링크 파라미터를 `URLQueryItem` 으로 인코딩(주입 방지). 은행은 **고정 목록 선택**, 계좌는 숫자만 → 변조 표면 축소. |
| 비밀 파일 | `GoogleService-Info.plist` **.gitignore** 처리(커밋 금지). |

## 운영 전 적용 필요 (사용자 액션)

1. **익명 인증 활성화**: Firebase 콘솔 → Authentication → 로그인 방법 → '익명' 사용.
2. **보안 규칙 배포**: `firestore.rules` 내용을 콘솔 Firestore 규칙에 게시 (테스트 모드 교체).
   - ⚠️ 익명 인증을 먼저 켠 뒤 규칙을 배포해야 앱이 정상 동작한다.

## 그룹별 격리 (#14, 적용됨)

- 그룹 doc 에 `memberUIDs`(익명 uid 목록), 멤버 doc 에 `ownerUID`(생성 uid)를 둔다.
- `isMember(gid)` = uid 가 groups/gid.memberUIDs 에 포함. 자식 컬렉션
  (members/chores/expenses/choreCompletions/settlements/notes)은 멤버만 접근.
- 멤버 doc 은 본인 소유(ownerUID==uid)만 생성/수정.
- `fetchAllGroups` 도 memberUIDs arrayContains 로 내 그룹만 반환(스위처 격리).
- **레거시 주의**: 규칙 적용 전 만든 그룹은 memberUIDs 가 없어 접근 불가 → 새로 생성해 사용.

## 알려진 한계 / 다음 단계

- **그룹 doc 읽기 개방**: 초대코드 검색을 위해 그룹 doc 자체는 인증되면 읽을 수 있다(민감정보는
  자식 컬렉션에만 둠). 그룹 id 를 아는 사용자의 자가 합류가 가능 → 완전 비공개는 초대코드 해시/
  서버 검증(Cloud Functions)이 필요하다.
- **계정 모델**: 익명 인증이라 기기 분실 시 세션 복구 불가. 실제 서비스는 Sign in with Apple 권장.
- **영수증 이미지**: Firestore 동기화 제외(1MB 한계). 필요 시 Cloud Storage + 접근 규칙.
