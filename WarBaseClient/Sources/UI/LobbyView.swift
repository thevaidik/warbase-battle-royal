import SwiftUI

struct LobbyView: View {
    @ObservedObject var viewModel: LobbyViewModel
    var onlineCount: Int
    var onDeploy: () -> Void

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                topBar
                Divider().background(Color.red.opacity(0.3))
                tabBar
                tabContent
                Spacer()
                footerBar
            }
        }
        .alert("EDIT CALLSIGN", isPresented: $viewModel.showCallsignEditor) {
            TextField("Callsign", text: $viewModel.editingCallsign)
                .textFieldStyle(.plain)
            Button("SAVE") { viewModel.saveCallsign() }
            Button("CANCEL", role: .cancel) { }
        } message: {
            Text("Enter your operator callsign (3-16 characters)")
        }
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.06, green: 0.06, blue: 0.08),
                Color(red: 0.10, green: 0.10, blue: 0.12),
                Color(red: 0.04, green: 0.04, blue: 0.06)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("WARBASE")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(.red)
                .tracking(4)
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "person.fill").foregroundColor(.red)
                Text(viewModel.callsign)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Button(action: {
                    viewModel.editingCallsign = viewModel.callsign
                    viewModel.showCallsignEditor = true
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("LOADOUTS", index: 0)
            tabButton("JOIN MATCH", index: 1)
            tabButton("CREATE MATCH", index: 2)
        }
        .padding(.horizontal, 30)
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { viewModel.activeTab = index } }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(viewModel.activeTab == index ? .white : .gray)
                Rectangle()
                    .fill(viewModel.activeTab == index ? Color.red : Color.clear)
                    .frame(height: 2)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.activeTab {
        case 0: loadoutsTab
        case 1: joinMatchTab
        case 2: createMatchTab
        default: loadoutsTab
        }
    }

    // MARK: - Loadouts Tab

    private var loadoutsTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("SELECT OPERATOR CLASS")
                    classButton("ASSAULT", available: true)
                    classButton("SCOUT", available: true)
                    classButton("ENGINEER", available: false)
                    classButton("MEDIC", available: false)
                }
                VStack(alignment: .leading, spacing: 16) {
                    Text(classDescription)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                        .frame(maxWidth: 400, alignment: .leading)
                    sectionHeader("PERKS")
                    HStack(spacing: 16) {
                        perkBadge("⚡ Lightweight")
                        perkBadge("🎯 Steady Aim")
                        perkBadge("💥 Scavenger")
                    }
                    sectionHeader("WEAPONS")
                        .padding(.top, 8)
                    HStack(spacing: 16) {
                        weaponSlot(name: viewModel.selectedClass == "ASSAULT" ? "AK-47" : "M2010", type: "PRIMARY")
                        weaponSlot(name: "PISTOL .50", type: "SIDEARM")
                        weaponSlot(name: "FRAG GRENADE", type: "GADGET")
                    }
                }
            }
        }
        .padding(30)
    }

    private var classDescription: String {
        viewModel.selectedClass == "ASSAULT"
            ? "Balanced assault class. Equipped with AK-47 assault rifle and frag grenades. Effective at all ranges."
            : "Long-range reconnaissance class. Equipped with M2010 sniper rifle. Best at distance."
    }

    private func classButton(_ name: String, available: Bool) -> some View {
        Button(action: { guard available else { return }; viewModel.selectedClass = name }) {
            HStack {
                Text(name)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(viewModel.selectedClass == name ? .white : (available ? .gray : .gray.opacity(0.4)))
                Spacer()
                if !available {
                    Image(systemName: "lock.fill").foregroundColor(.gray.opacity(0.5)).font(.system(size: 10))
                }
                if viewModel.selectedClass == name {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(viewModel.selectedClass == name ? Color.red.opacity(0.15) : Color.white.opacity(0.04))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(viewModel.selectedClass == name ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain).disabled(!available)
    }

    // MARK: - Join Match Tab

    private var joinMatchTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                sectionHeader("MATCH BROWSER")
                Spacer()
                Button(action: {}) {
                    Text("REFRESH").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.red)
                }.buttonStyle(.plain)
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Enter Room ID...", text: $viewModel.roomID)
                    .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
            }
            .padding(12).background(Color.white.opacity(0.06)).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))

            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "globe").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                Text("No active matches found").font(.system(size: 14, design: .monospaced)).foregroundColor(.gray.opacity(0.5))
                Text("Create a match or enter a Room ID to join").font(.system(size: 12, design: .monospaced)).foregroundColor(.gray.opacity(0.3))
                Spacer()
            }
            .frame(maxWidth: .infinity)

            Button(action: onDeploy) {
                Text("DEPLOY")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.white).tracking(4)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LinearGradient(colors: [.red, .red.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(8).shadow(color: .red.opacity(0.4), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(30)
    }

    // MARK: - Create Match Tab

    private var createMatchTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Image(systemName: "text.cursor").foregroundColor(.gray)
                TextField("Match Name", text: $viewModel.createMatchName)
                    .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
            }
            .padding(12).background(Color.white.opacity(0.06)).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))

            sectionHeader("SELECT MAP")
            HStack(spacing: 16) {
                mapCard(name: "industrial", label: "INDUSTRIAL ZONE", available: true)
                mapCard(name: "village", label: "VILLAGE", available: false)
                mapCard(name: "arena", label: "ARENA", available: false)
            }

            sectionHeader("GAME MODE")
            HStack(spacing: 16) {
                modeCard(label: "FREE FOR ALL", code: "FFA", color: .red)
                modeCard(label: "TEAM DEATHMATCH", code: "TDM", color: .blue)
            }

            Button(action: onDeploy) {
                Text("INITIALIZE OPERATION")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.black).tracking(2)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.white).cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(30)
    }

    private func mapCard(name: String, label: String, available: Bool) -> some View {
        Button(action: { guard available else { return }; viewModel.selectedMap = name }) {
            VStack(spacing: 8) {
                Rectangle()
                    .fill(available ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                    .frame(width: 160, height: 100).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(viewModel.selectedMap == name ? Color.red : Color.white.opacity(0.1), lineWidth: 1))
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(available ? .white : .gray.opacity(0.4))
                if !available {
                    Image(systemName: "lock.fill").foregroundColor(.gray.opacity(0.5)).font(.system(size: 10))
                }
            }
        }
        .buttonStyle(.plain).disabled(!available)
    }

    private func modeCard(label: String, code: String, color: Color) -> some View {
        Button(action: { viewModel.selectedGameMode = code }) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(viewModel.selectedGameMode == code ? .white : .gray)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(viewModel.selectedGameMode == code ? color.opacity(0.2) : Color.white.opacity(0.04))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(viewModel.selectedGameMode == code ? color.opacity(0.6) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("\(onlineCount) ONLINE")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
            }
            Spacer()
            Button(action: {
                viewModel.editingCallsign = viewModel.callsign
                viewModel.showCallsignEditor = true
            }) {
                Text("RENAME CALLSIGN")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 30).padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(.gray).tracking(2)
    }

    private func perkBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.white.opacity(0.06)).cornerRadius(6)
    }

    private func weaponSlot(name: String, type: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(type)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.gray).tracking(1)
            WeaponPreview3D(weaponName: viewModel.selectedClass == "ASSAULT" ? "ak47" : "m2010")
                .frame(width: 160, height: 120)
                .background(Color.white.opacity(0.04)).cornerRadius(8)
            Text(name)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}
