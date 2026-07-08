import Foundation

/// `space` in the JSON may be the string "new", a 1-based desktop index (number),
/// or a numeric string. This mirrors the polymorphic handling in spaceManager.lua.
enum SpaceSpec: Equatable {
    case new
    case index(Int)
    case none

    var isNew: Bool { self == .new }

    init(from raw: SpaceRaw?) {
        switch raw {
        case .none:
            self = .none
        case .string(let s):
            let trimmed = s.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased() == "new" {
                self = .new
            } else if let n = Int(trimmed) {
                self = .index(n)
            } else {
                self = .none
            }
        case .number(let n):
            self = .index(n)
        }
    }
}

/// Intermediate type so a single JSON key can decode from either String or Int.
enum SpaceRaw: Decodable {
    case string(String)
    case number(Int)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) {
            self = .number(i)
        } else if let d = try? c.decode(Double.self) {
            self = .number(Int(d))
        } else {
            self = .string(try c.decode(String.self))
        }
    }
}

public enum AppType: String, Decodable {
    case app, chrome, folder, simulator
}

/// One entry in the project's `apps` array.
struct AppConfig: Decodable {
    var type: AppType
    var name: String?
    var path: String?
    var bundleId: String?
    var newWindow: Bool?
    /// "newWindow" | "thisWindow" | false. Decoded leniently.
    var openProjectDialog: DialogChoice?
    var openProjectDialogButton: String?
    var profile: String?
    var profileDirectory: String?
    var device: String?

    private enum CodingKeys: String, CodingKey {
        case type, name, path, bundleId, newWindow
        case openProjectDialog, openProjectDialogButton
        case profile, profileDirectory, device
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.type = (try? c.decode(AppType.self, forKey: .type)) ?? .app
        self.name = try? c.decode(String.self, forKey: .name)
        self.path = try? c.decode(String.self, forKey: .path)
        self.bundleId = try? c.decode(String.self, forKey: .bundleId)
        self.newWindow = try? c.decode(Bool.self, forKey: .newWindow)
        self.openProjectDialog = try? c.decode(DialogChoice.self, forKey: .openProjectDialog)
        self.openProjectDialogButton = try? c.decode(String.self, forKey: .openProjectDialogButton)
        self.profile = try? c.decode(String.self, forKey: .profile)
        self.profileDirectory = try? c.decode(String.self, forKey: .profileDirectory)
        self.device = try? c.decode(String.self, forKey: .device)
    }
}

/// "newWindow" / "thisWindow" / off (false, "off", "none").
enum DialogChoice: Decodable, Equatable {
    case newWindow
    case thisWindow
    case off

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) {
            self = b ? .newWindow : .off
            return
        }
        let s = (try? c.decode(String.self))?.lowercased() ?? ""
        switch s {
        case "newwindow": self = .newWindow
        case "thiswindow": self = .thisWindow
        case "off", "none", "false": self = .off
        default: self = .off
        }
    }
}

struct ProjectConfig: Decodable {
    var name: String?
    var space: SpaceSpec
    var apps: [AppConfig]

    private enum CodingKeys: String, CodingKey {
        case name, space, apps
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try? c.decode(String.self, forKey: .name)
        let raw = try? c.decode(SpaceRaw.self, forKey: .space)
        self.space = SpaceSpec(from: raw)
        self.apps = (try? c.decode([AppConfig].self, forKey: .apps)) ?? []
    }
}
