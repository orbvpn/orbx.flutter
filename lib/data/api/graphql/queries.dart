class GraphQLQueries {
  // User Authentication
  static const String login = r'''
    mutation Login($email: String!, $password: String!) {
      login(email: $email, password: $password) {
        accessToken
        user {
          id
          email
          profile {
            firstName
            lastName
          }
          subscription {
            group {
              id
              name
            }
            multiLoginCount
            expiresAt
          }
        }
      }
    }
  ''';

  static const String register = r'''
    mutation Register($input: UserInput!) {
      register(input: $input) {
        accessToken
        user {
          id
          email
          profile {
            firstName
            lastName
          }
        }
      }
    }
  ''';

  // Server Management - ✅ FIXED: No enabled/online parameters, added countryCode
  static const String getServers = r'''
    query GetOrbXServers {
      orbxServers {
        id
        name
        ipAddress
        port
        location
        country
        protocols
        quantumSafe
        currentConnections
        maxConnections
        latencyMs
        enabled
        online
      }
    }
  ''';

  // ✅ FIXED: Best server query
  static const String getBestServer = r'''
    query GetBestOrbXServer {
      bestOrbXServer {
        id
        name
        ipAddress
        port
        location
        country
        countryCode
        region
        hostname
        protocols
        latencyMs
      }
    }
  ''';

  // ✅ FIXED: Server by ID
  static const String getServerById = r'''
    query GetOrbXServer($id: ID!) {
      orbxConfig(serverId: $id) {
        serverId
        endpoint
        port
        publicKey
        protocols
        tlsFingerprint
        quantumSafe
        region
      }
    }
  ''';

  // Usage Tracking
  static const String recordUsage = r'''
    mutation RecordOrbXUsage($input: OrbXUsageInput!) {
      recordOrbXUsage(input: $input) {
        success
        message
      }
    }
  ''';

  // Device Management
  static const String loginDevice = r'''
    mutation LoginDevice($device: UserDeviceInput!) {
      loginDevice(device: $device) {
        id
        userId
        os
        deviceId
        deviceModel
        deviceName
        fcmToken
        isActive
      }
    }
  ''';

  static const String logoutDevice = r'''
    mutation LogoutDevice($deviceId: String!) {
      logoutDeviceByDeviceId(deviceId: $deviceId) {
        id
        isActive
      }
    }
  ''';

  // User Profile
  static const String getProfile = r'''
    query GetUserProfile {
      getUserInfo {
        id
        email
        profile {
          firstName
          lastName
        }
        subscription {
          group {
            id
            name
          }
          multiLoginCount
          expiresAt
        }
      }
    }
  ''';

  static const String refreshToken = r'''
    mutation RefreshToken($refreshToken: String!) {
      refreshToken(refreshToken: $refreshToken) {
        accessToken
        refreshToken
        user {
          id
          email
          profile {
            firstName
            lastName
          }
          subscription {
            group {
              id
              name
            }
            multiLoginCount
            expiresAt
          }
        }
      }
    }
  ''';
}
