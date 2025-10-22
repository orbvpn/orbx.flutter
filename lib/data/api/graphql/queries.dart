class GraphQLQueries {
  // User Authentication
  static const String login = r'''
    mutation Login($email: String!, $password: String!) {
      login(email: $email, password: $password) {
        accessToken
        refreshToken
        user {
          id
          email
          firstName
          lastName
          subscription {
            id
            planName
            maxDevices
            expiryDate
          }
        }
      }
    }
  ''';

  static const String register = r'''
    mutation Register($input: UserInput!) {
      register(input: $input) {
        accessToken
        refreshToken
        user {
          id
          email
          firstName
          lastName
        }
      }
    }
  ''';

  // Server Management
  static const String getServers = r'''
    query GetOrbXServers {
      orbxServers(enabled: true, online: true) {
        id
        name
        ipAddress
        port
        location
        country
        countryCode
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

  static const String getBestServer = r'''
    query GetBestOrbXServer {
      bestOrbXServer {
        id
        name
        ipAddress
        port
        location
        country
        protocols
        latencyMs
      }
    }
  ''';

  static const String getServerById = r'''
    query GetOrbXServer($id: ID!) {
      orbxServer(id: $id) {
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
      me {
        id
        email
        firstName
        lastName
        subscription {
          planName
          maxDevices
          expiryDate
        }
      }
    }
  ''';
}
