import SwiftUI

struct ScienceTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HopSpacing.xl) {
                intro
                recommendedRatios
                presetRationale
                sources
            }
            .frame(maxWidth: HopLayout.contentMaxWidth, alignment: .leading)
            .padding(HopSpacing.xl)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: HopSpacing.sm) {
            Text("Why alternate?").font(.headline)
            Text("Prolonged sitting is an independent risk factor for musculoskeletal issues, cardiometabolic disease, and reduced concentration. Prolonged standing is not a fix either — it introduces lower-limb fatigue and varicose risk. The goal is alternation, plus regular micro-breaks to move.")
                .font(.body)
                .lineSpacing(4)
        }
    }

    private var recommendedRatios: some View {
        VStack(alignment: .leading, spacing: HopSpacing.sm) {
            Text("Recommended ratios").font(.headline)
            VStack(alignment: .leading, spacing: HopSpacing.xs) {
                bulletRow("Total: 2–4 h of cumulative standing per 8-h workday")
                bulletRow("Continuous standing: keep under ~45 min; ideally 20–30 min")
                bulletRow("Continuous sitting: keep under ~30 min before a change of position")
                bulletRow("Add a 1–2 min micro-break every 30 min regardless of posture")
            }
            .font(.body)
        }
    }

    private var presetRationale: some View {
        VStack(alignment: .leading, spacing: HopSpacing.sm) {
            Text("Preset rationale").font(.headline)
            VStack(alignment: .leading, spacing: HopSpacing.xs) {
                bulletRow("Beginner (15 stand / 45 sit) — gentle ramp-up; ~1.5 h standing/day.")
                bulletRow("Intermediate (30 / 30) — the 1:1 sweet spot recommended by most ergonomists; ~4 h standing/day.")
                bulletRow("Advanced (45 / 30) — approaches a 3:1 standing-to-sitting ratio; caps continuous standing at 45 min.")
                bulletRow("Follow-the-science default equals Intermediate.")
            }
            .font(.body)
        }
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: HopSpacing.md) {
            Text("Sources").font(.headline)
            GroupBox {
                Text("Buckley JP, Hedge A, Yates T, et al. (2015). The sedentary office: an expert statement on the growing case for change towards better health and productivity. British Journal of Sports Medicine, 49(21), 1357–1362.")
                    .font(.callout)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox {
                Text("University of Waterloo CRE-MSD — Position paper on the use of sit-stand workstations.")
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox {
                Text("Cornell University Ergonomics Web (CUErgo) — micro-break recommendations.")
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: HopSpacing.sm) {
            Text("•").foregroundStyle(.secondary)
            Text(text).lineSpacing(3)
        }
    }
}
