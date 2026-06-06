//
//  CurrentMemberStore.swift
//  RoomieSync
//
//  "이 기기의 사용자가 어떤 멤버인지"를 그룹별로 로컬에 저장/해석한다.
//  예전엔 현재 사용자를 members.first(가장 먼저 가입=호스트)로 가정했는데,
//  친구가 초대코드로 합류하면 그 기기에서도 members.first=호스트 로 잡혀
//  '친구가 호스트 이름으로 표시'되는 버그가 있었다. 그룹 생성/합류 시 내 멤버 id 를
//  기기에 저장하고, 이후 그 id 로 현재 사용자를 식별한다.
//

import Foundation

public enum CurrentMemberStore {
    private static func key(_ groupID: UUID) -> String { "myMemberID.\(groupID.uuidString)" }

    /// 이 기기에 저장된 '내 멤버 id'.
    public static func id(for groupID: UUID) -> UUID? {
        UserDefaults.standard.string(forKey: key(groupID)).flatMap(UUID.init(uuidString:))
    }

    /// 그룹 생성/합류 시 내 멤버 id 를 저장.
    public static func set(_ memberID: UUID, for groupID: UUID) {
        UserDefaults.standard.set(memberID.uuidString, forKey: key(groupID))
    }

    /// 멤버 목록에서 '나'를 해석.
    /// 1) 기기에 저장된 내 멤버 id (가장 빠름)
    /// 2) 익명 로그인 uid 와 멤버 ownerUID 매칭 (재합류 없이도 동작, 재설치에도 안전)
    /// 3) 첫 멤버로 폴백 (레거시/로컬 단독)
    public static func resolve(_ members: [Member], groupID: UUID) -> Member? {
        if let myID = id(for: groupID), let me = members.first(where: { $0.id == myID }) {
            return me
        }
        if let uid = FirebaseBootstrap.currentUID(),
           let me = members.first(where: { $0.ownerUID == uid }) {
            // 다음을 위해 저장해 둔다(빠른 경로).
            set(me.id, for: groupID)
            return me
        }
        return members.first
    }

    /// 그룹 나갈 때 정리.
    public static func clear(for groupID: UUID) {
        UserDefaults.standard.removeObject(forKey: key(groupID))
    }
}
