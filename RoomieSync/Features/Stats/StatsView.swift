//
//  StatsView.swift
//  RoomieSync
//
//  계획서 참조: Stitch 시안 ⑤, 1.4 KPI (공정 지수)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import SwiftUI
import Charts

struct StatsView: View {
    let groupID: UUID
    @Environment(\.repositories) private var repositories
    @State private var viewModel: StatsViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                if let vm = viewModel {
                    choreCountCard(vm)
                    achievementCard(vm)
                    monthlyTrendCard(vm)
                    categoryDonutCard(vm)
                    if let mvp = vm.mvp { mvpCard(mvp) }
                } else {
                    ProgressView().padding(Spacing.xxl)
                }
            }
            .padding(.vertical, Spacing.m)
        }
        .background(Tokens.surface.ignoresSafeArea())
        .navigationTitle("통계")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = StatsViewModel(groupID: groupID, repositories: repositories)
            }
            await viewModel?.load()
        }
    }

    // MARK: - 가사 완료 횟수 (시안 ⑤ 첫 카드)

    @ViewBuilder
    private func choreCountCard(_ vm: StatsViewModel) -> some View {
        SectionCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("가사 완료 횟수").font(Typo.sectionTitle())
                    Text("지난 30일간").font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
                }
                Spacer()
                Text("공정 지수: \(vm.fairnessIndex)%")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, Spacing.s).padding(.vertical, 4)
                    .background(Tokens.receiveCardBG)
                    .foregroundStyle(Tokens.success)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: Spacing.s) {
                ForEach(vm.memberCounts) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(row.member.name + (row.isCurrentUser ? " (나)" : ""))
                                .font(Typo.body())
                            Spacer()
                            Text("\(row.count)회")
                                .font(Typo.bodyBold())
                                .foregroundStyle(Tokens.primary)
                        }
                        GeometryReader { geo in
                            let maxCount = max(vm.memberCounts.map(\.count).max() ?? 1, 1)
                            let width = geo.size.width * CGFloat(row.count) / CGFloat(maxCount)
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(Tokens.surfaceMuted)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: row.member.avatarColorHex))
                                    .frame(width: max(width, 0))
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
    }

    // MARK: - 나의 성취 (연속 달성 + 뱃지)

    @ViewBuilder
    private func achievementCard(_ vm: StatsViewModel) -> some View {
        SectionCard {
            HStack {
                Text("나의 성취").font(Typo.sectionTitle())
                Spacer()
            }

            // 연속 달성 + 총 완료
            HStack(spacing: Spacing.m) {
                statPill(icon: "flame.fill",
                         value: "\(vm.myStreakDays)일",
                         label: "연속 달성",
                         tint: vm.myStreakDays > 0 ? .orange : Tokens.textTertiary)
                statPill(icon: "checkmark.seal.fill",
                         value: "\(vm.myTotalCompletions)회",
                         label: "누적 완료",
                         tint: Tokens.primary)
            }

            // 뱃지 그리드
            let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: 4)
            LazyVGrid(columns: columns, spacing: Spacing.m) {
                ForEach(vm.badges) { badge in
                    VStack(spacing: 4) {
                        Image(systemName: badge.icon)
                            .font(.system(size: 26))
                            .foregroundStyle(badge.earned ? Tokens.primary : Tokens.textTertiary.opacity(0.4))
                        Text(badge.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(badge.earned ? Tokens.textPrimary : Tokens.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(badge.earned ? 1 : 0.55)
                }
            }
            .padding(.top, Spacing.xs)
        }
    }

    @ViewBuilder
    private func statPill(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: icon).font(.system(size: 22)).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(Typo.bodyBold())
                Text(label).font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
            }
            Spacer()
        }
        .padding(Spacing.m)
        .background(Tokens.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Radius.m))
    }

    // MARK: - 월별 지출 추이 (Swift Charts line)

    @ViewBuilder
    private func monthlyTrendCard(_ vm: StatsViewModel) -> some View {
        SectionCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("월별 지출 추이").font(Typo.sectionTitle())
                    Text("최근 6개월").font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
                }
                Spacer()
            }
            if vm.monthlySeries.isEmpty {
                Text("아직 데이터가 충분하지 않아요")
                    .font(Typo.caption())
                    .foregroundStyle(Tokens.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                Chart(vm.monthlySeries) { point in
                    LineMark(
                        x: .value("월", point.month, unit: .month),
                        y: .value("금액", (point.total as NSDecimalNumber).doubleValue)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Tokens.primary)
                    PointMark(
                        x: .value("월", point.month, unit: .month),
                        y: .value("금액", (point.total as NSDecimalNumber).doubleValue)
                    )
                    .foregroundStyle(Tokens.primary)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month())
                    }
                }
                .frame(height: 200)
            }
        }
    }

    // MARK: - 카테고리 도넛

    @ViewBuilder
    private func categoryDonutCard(_ vm: StatsViewModel) -> some View {
        SectionCard {
            Text("카테고리별 지출").font(Typo.sectionTitle())

            HStack(spacing: Spacing.l) {
                ZStack {
                    Chart(vm.categorySpendings) { item in
                        SectorMark(
                            angle: .value("금액", (item.total as NSDecimalNumber).doubleValue),
                            innerRadius: .ratio(0.65),
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("카테고리", item.category.displayName))
                    }
                    .frame(width: 130, height: 130)
                    .chartLegend(.hidden)

                    VStack(spacing: 2) {
                        Text("Total").font(Typo.caption()).foregroundStyle(Tokens.textTertiary)
                        Text(CurrencyFormatter.format(vm.totalSpending))
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(vm.categorySpendings) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.category.sfSymbolName)
                                .foregroundStyle(Tokens.primary)
                                .frame(width: 18)
                            Text("\(item.category.displayName) \(Int(item.percentage * 100))%")
                                .font(Typo.caption())
                            Spacer()
                            Text(CurrencyFormatter.format(item.total))
                                .font(Typo.caption())
                                .foregroundStyle(Tokens.textSecondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - MVP 카드

    @ViewBuilder
    private func mvpCard(_ member: Member) -> some View {
        SectionCard {
            HStack(spacing: Spacing.m) {
                Text("🏆").font(.system(size: 40))
                VStack(alignment: .leading) {
                    Text("이번 달 가사 MVP").font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
                    Text(member.name).font(Typo.sectionTitle())
                }
                Spacer()
                MemberAvatarView(member: member, size: 56, highlighted: true)
            }
        }
    }

}

#Preview("시안 ⑤ 통계") {
    let (repos, groupID) = InMemorySeed.preview()
    return NavigationStack {
        StatsView(groupID: groupID)
            .environment(\.repositories, repos)
    }
}
