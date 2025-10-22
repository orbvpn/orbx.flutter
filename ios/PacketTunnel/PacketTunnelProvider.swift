import NetworkExtension
import WireGuardKit

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var adapter: WireGuardAdapter?
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Get WireGuard configuration from provider configuration
        guard let providerConfig = protocolConfiguration as? NETunnelProviderProtocol,
              let wgConfigString = providerConfig.providerConfiguration?["wgConfig"] as? String else {
            completionHandler(NSError(domain: "OrbVPN", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing WireGuard configuration"]))
            return
        }
        
        // Parse WireGuard config
        guard let tunnelConfiguration = try? TunnelConfiguration(fromWgQuickConfig: wgConfigString) else {
            completionHandler(NSError(domain: "OrbVPN", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid WireGuard configuration"]))
            return
        }
        
        // Create adapter
        adapter = WireGuardAdapter(with: self) { logLevel, message in
            print("[\(logLevel)] \(message)")
        }
        
        // Start WireGuard tunnel
        adapter?.start(tunnelConfiguration: tunnelConfiguration) { error in
            if let error = error {
                completionHandler(error)
            } else {
                completionHandler(nil)
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        adapter?.stop { error in
            if let error = error {
                print("Failed to stop WireGuard: \(error)")
            }
            completionHandler()
        }
    }
}