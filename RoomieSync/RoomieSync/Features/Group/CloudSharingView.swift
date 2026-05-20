//
//  CloudSharingView.swift
//  RoomieSync
//
//  계획서 참조: 6.1 #2 룸메이트 합류 (CloudKit Sharing)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-02
//
//  UICloudSharingController 를 SwiftUI 로 래핑.
//  GroupCreateView 의 "이 그룹 공유하기" 액션이 호출.
//

import SwiftUI
import CloudKit
import UIKit

struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let vc = UICloudSharingController(share: share, container: container)
        vc.availablePermissions = [.allowReadWrite, .allowPrivate]
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) { /* OK */ }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) { /* OK */ }
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("⚠️ CKShare 저장 실패: \(error)")
        }
        func itemTitle(for csc: UICloudSharingController) -> String? {
            "RoomieSync — 우리집 공유"
        }
    }
}
