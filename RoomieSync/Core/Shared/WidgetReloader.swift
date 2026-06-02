//
//  WidgetReloader.swift
//  RoomieSync
//
//  메인 앱에서 위젯 타임라인 갱신을 요청하는 헬퍼.
//  메인 앱 + 위젯 확장 양쪽에서 참조하므로 Core/Shared 에 둔다.
//

import WidgetKit

public enum WidgetReloader {
    public static func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
