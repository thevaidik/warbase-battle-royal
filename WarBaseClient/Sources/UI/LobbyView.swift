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
        .onAppear { viewModel.checkServer() }
        .onChange(of: viewModel.serverHost) { _ in viewModel.checkServer() }
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
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.08),
                    Color(red: 0.10, green: 0.10, blue: 0.12),
                    Color(red: 0.04, green: 0.04, blue: 0.06)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Tactical grid
            Canvas { ctx, size in
                let step: CGFloat = 44
                ctx.stroke(Path { p in
                    var xx: CGFloat = 0
                    while xx < size.width { p.move(to: CGPoint(x: xx, y: 0)); p.addLine(to: CGPoint(x: xx, y: size.height)); xx += step }
                    var yy: CGFloat = 0
                    while yy < size.height { p.move(to: CGPoint(x: 0, y: yy)); p.addLine(to: CGPoint(x: size.width, y: yy)); yy += step }
                }, with: .color(.white.opacity(0.025)), lineWidth: 1)
            }
            // Red corner accents
            VStack {
                HStack {
                    Rectangle().fill(Color.red.opacity(0.35)).frame(width: 40, height: 2).padding(.leading, 0)
                    Spacer()
                    Rectangle().fill(Color.red.opacity(0.35)).frame(width: 40, height: 2)
                }
                Spacer()
                HStack {
                    Rectangle().fill(Color.red.opacity(0.35)).frame(width: 40, height: 2)
                    Spacer()
                    Rectangle().fill(Color.red.opacity(0.35)).frame(width: 40, height: 2)
                }
            }
            .padding(30)
            // Vignette
            RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center, startRadius: 200, endRadius: 800)
        }
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
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                sectionHeader("MATCH BROWSER (\(viewModel.availableRooms.count) ACTIVE)")
                Spacer()
                Button(action: { viewModel.fetchRooms() }) {
                    HStack(spacing: 4) {
                        if viewModel.isFetchingRooms {
                            ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("REFRESH")
                    }
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }

#if DEBUG
            HStack {
                Image(systemName: "link").foregroundColor(.gray)
                TextField("Server (e.g. war.nxtlap.com or localhost:8081)", text: $viewModel.serverHost)
                    .textFieldStyle(.plain).font(.system(size: 12, design: .monospaced))
                    .autocorrectionDisabled(true)
            }
            .padding(10).background(Color.white.opacity(0.06)).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
#endif

            if !viewModel.availableRooms.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.availableRooms) { room in
                            let isSelected = viewModel.roomID == room.id
                            Button(action: {
                                viewModel.roomID = room.id
                                viewModel.selectedMap = room.map
                            }) {
                                HStack(spacing: 14) {
                                    Circle()
                                        .fill(isSelected ? Color.red : Color.green.opacity(0.8))
                                        .frame(width: 8, height: 8)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(room.name.uppercased())
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(isSelected ? .white : .white.opacity(0.9))

                                        HStack(spacing: 8) {
                                            Text("MAP: \(room.map.uppercased())")
                                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                                .foregroundColor(.gray)
                                            Text("•")
                                                .font(.system(size: 8))
                                                .foregroundColor(.gray.opacity(0.4))
                                            Text("MODE: \((room.mode ?? "FFA").uppercased())")
                                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                                .foregroundColor(.gray)
                                        }
                                    }

                                    Spacer()

                                    HStack(spacing: 8) {
                                        Text("\(room.playerCount)/16 PLAYERS")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(room.playerCount > 0 ? .green : .gray.opacity(0.6))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.04))
                                            .cornerRadius(4)

                                        Text(isSelected ? "READY" : "SELECT")
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                            .foregroundColor(isSelected ? .white : .gray)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(isSelected ? Color.red : Color.white.opacity(0.08))
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(isSelected ? Color.red.opacity(0.12) : Color.white.opacity(0.04))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSelected ? Color.red.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 200)
            } else {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "globe").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                    Text(viewModel.isFetchingRooms ? "Scanning active operations..." : "No active matches found")
                        .font(.system(size: 13, design: .monospaced)).foregroundColor(.gray.opacity(0.6))
                    Text("Create a match or enter a Room ID below").font(.system(size: 11, design: .monospaced)).foregroundColor(.gray.opacity(0.35))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(Color.white.opacity(0.02))
                .cornerRadius(8)
            }

            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Selected Room ID / Custom Room...", text: $viewModel.roomID)
                    .textFieldStyle(.plain).font(.system(size: 12, design: .monospaced))
            }
            .padding(10).background(Color.white.opacity(0.06)).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))

            Button(action: onDeploy) {
                Text(viewModel.roomID.isEmpty ? "DEPLOY (DEFAULT)" : "DEPLOY TO \(viewModel.roomID.uppercased())")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundColor(.white).tracking(3)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(LinearGradient(colors: [.red, .red.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(8).shadow(color: .red.opacity(0.4), radius: 10, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(30)
    }

    // MARK: - Create Match Tab

    private var createMatchTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "text.cursor").foregroundColor(.gray)
                TextField("Match Name (e.g. Alpha Sector)", text: $viewModel.createMatchName)
                    .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
            }
            .padding(12).background(Color.white.opacity(0.06)).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))

            sectionHeader("SELECT MAP")
            HStack(spacing: 16) {
                mapCard(name: "industrial", label: "INDUSTRIAL ZONE", available: true)
                mapCard(name: "village", label: "VILLAGE", available: true)
                mapCard(name: "arena", label: "ARENA", available: true)
            }

            sectionHeader("GAME MODE")
            HStack(spacing: 16) {
                modeCard(label: "FREE FOR ALL", code: "FFA", color: .red)
                modeCard(label: "TEAM DEATHMATCH", code: "TDM", color: .blue)
            }

            if let err = viewModel.createError {
                Text(err)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.red)
            }

            Button(action: {
                viewModel.createMatch {
                    onDeploy()
                }
            }) {
                HStack {
                    if viewModel.isCreatingRoom {
                        ProgressView().scaleEffect(0.8).frame(width: 16, height: 16)
                    }
                    Text(viewModel.isCreatingRoom ? "INITIALIZING..." : "INITIALIZE OPERATION")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.black).tracking(2)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.white).cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isCreatingRoom)
        }
        .padding(30)
    }

    private func mapCard(name: String, label: String, available: Bool) -> some View {
        Button(action: { guard available else { return }; viewModel.selectedMap = name }) {
            VStack(spacing: 8) {
                MapThumbnail(kind: name, selected: viewModel.selectedMap == name, available: available)
                    .frame(width: 160, height: 100)
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
                Circle().fill(viewModel.serverOnline ? Color.green : Color.red).frame(width: 6, height: 6)
                Text(viewModel.serverOnline ? "\(onlineCount) ONLINE" : "OFFLINE")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(viewModel.serverOnline ? .gray : .red.opacity(0.8))
            }
            Text("•")
                .foregroundColor(.gray.opacity(0.4))
#if DEBUG
            Text(viewModel.serverCheckedHost.isEmpty ? viewModel.serverHost : viewModel.serverCheckedHost)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(viewModel.serverOnline ? .gray.opacity(0.6) : .red.opacity(0.6))
#else
            Text(viewModel.serverCheckedHost.isEmpty ? "war.nxtlap.com" : viewModel.serverCheckedHost)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(viewModel.serverOnline ? .gray.opacity(0.6) : .red.opacity(0.6))
#endif
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


// MARK: - Procedural map thumbnails

struct MapThumbnail: View {
    let kind: String
    let selected: Bool
    let available: Bool

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.11)
            Canvas { ctx, size in
                let c: Color = available ? .white.opacity(0.55) : .white.opacity(0.15)
                var p = Path()
                let w = size.width, h = size.height, g = h * 0.78 // ground line
                switch kind {
                case "village":
                    // little houses: two roof triangles + walls
                    p.move(to: CGPoint(x: w*0.10, y: g)); p.addLine(to: CGPoint(x: w*0.10, y: h*0.45))
                    p.addLine(to: CGPoint(x: w*0.24, y: h*0.28)); p.addLine(to: CGPoint(x: w*0.38, y: h*0.45));
                    p.addLine(to: CGPoint(x: w*0.38, y: g))
                    p.move(to: CGPoint(x: w*0.46, y: g)); p.addLine(to: CGPoint(x: w*0.46, y: h*0.52));
                    p.addLine(to: CGPoint(x: w*0.58, y: h*0.36)); p.addLine(to: CGPoint(x: w*0.70, y: h*0.52));
                    p.addLine(to: CGPoint(x: w*0.70, y: g))
                    // church spire
                    p.move(to: CGPoint(x: w*0.82, y: g)); p.addLine(to: CGPoint(x: w*0.82, y: h*0.30)); p.addLine(to: CGPoint(x: w*0.90, y: h*0.18)); p.addLine(to: CGPoint(x: w*0.94, y: h*0.30))
                case "arena":
                    // concentric ring arena
                    let cx = w/2, cy = h*0.52
                    for (i, r) in [w*0.36, w*0.24, w*0.12].enumerated() {
                        let rect = CGRect(x: cx-r, y: cy-r*0.55, width: r*2, height: r*1.1)
                        p.addEllipse(in: rect)
                        if i == 1 { p.addEllipse(in: rect.insetBy(dx: w*0.05, dy: w*0.03)) }
                    }
                default:
                    // industrial: crates + silos skyline
                    p.addRect(CGRect(x: w*0.08, y: g-h*0.30, width: w*0.14, height: h*0.30))
                    p.addRect(CGRect(x: w*0.26, y: g-h*0.48, width: w*0.14, height: h*0.48))
                    p.addRect(CGRect(x: w*0.44, y: g-h*0.22, width: w*0.14, height: h*0.22))
                    // silo with dome
                    p.addRect(CGRect(x: w*0.66, y: g-h*0.55, width: w*0.13, height: h*0.55))
                    p.addEllipse(in: CGRect(x: w*0.66, y: g-h*0.65, width: w*0.13, height: h*0.20))
                    // crane mast
                    p.move(to: CGPoint(x: w*0.88, y: g)); p.addLine(to: CGPoint(x: w*0.88, y: h*0.15)); p.addLine(to: CGPoint(x: w*0.70, y: h*0.15))
                }
                // ground line for all
                p.move(to: CGPoint(x: 0, y: g)); p.addLine(to: CGPoint(x: w, y: g))
                ctx.stroke(p, with: .color(c), lineWidth: 1.5)
            }
            .padding(6)
            if selected {
                RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1.5)
            } else {
                RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1)
            }
            if !available {
                Color.black.opacity(0.45)
                Image(systemName: "lock.fill").foregroundColor(.gray.opacity(0.7)).font(.system(size: 16))
            }
        }
        .cornerRadius(8)
    }
}
