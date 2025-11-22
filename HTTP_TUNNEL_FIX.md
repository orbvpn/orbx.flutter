# HTTP Tunnel Fix - No Data Passing Issue

## Problem
The VPN was connecting but no data was passing through. The WireGuard tunnel showed as "UP" but internet traffic was blocked.

## Root Cause
The HTTP tunnel establishment code had **two critical issues**:

### 1. Missing Client Public Key
The HTTP tunnel request to `/vpn/tunnel` was missing the client's WireGuard public key in the request headers. Without this:
- The server couldn't register the client as an authorized peer
- When WireGuard tried to connect on port 51820, the server rejected the packets
- No handshake could complete, blocking all traffic

### 2. Socket Not Protected from VPN Routing
The HTTP tunnel socket wasn't being protected from routing through the VPN itself, which would create a circular routing loop.

### 3. Missing Socket Timeout
The code was hanging indefinitely when the server didn't respond, with no timeout configured.

## Changes Made

### Android (OrbVpnService.kt)

1. **Added public key to HTTP requests** (Lines 388-543)
   - Updated all `build*Request()` functions to accept `publicKey` parameter
   - Added `X-WireGuard-PublicKey` header to all HTTP tunnel requests
   - This allows the server to register the client peer before WireGuard connection

2. **Protected socket from VPN routing** (Lines 264-270)
   ```kotlin
   // Protect socket from routing through VPN
   if (!protect(sslSocket)) {
       Log.e(TAG, "❌ Failed to protect socket from VPN routing")
       sslSocket.close()
       return@launch
   }
   ```

3. **Added socket timeout** (Line 259)
   ```kotlin
   sslSocket.soTimeout = 30000 // 30 second timeout
   ```

4. **Added timeout error handling** (Lines 315-321)
   ```kotlin
   val statusLine = try {
       reader.readLine()
   } catch (e: java.net.SocketTimeoutException) {
       Log.e(TAG, "❌ Timeout waiting for server response")
       sslSocket.close()
       return@launch
   }
   ```

5. **Added keepalive loop** (Lines 352-366)
   - Keeps the HTTP tunnel socket open for the VPN session duration
   - Allows server to forward WireGuard packets through the tunnel

6. **Extracted client public key from config** (Lines 128-133, 157)
   - Gets the client's public key from the config map
   - Passes it to `startHttpTunnel()` function

### Flutter (wireguard_channel.dart)

1. **Added public key to native method call** (Line 34)
   ```dart
   'publicKey': config.publicKey, // ✅ Add client's public key for tunnel registration
   ```
   - Now sends the client's public key to Android native code
   - Required for the HTTP tunnel registration

## How It Works Now

### Connection Flow:

1. **Client generates WireGuard keypair**
   - Public key: Shared with server
   - Private key: Kept secret

2. **Client establishes HTTPS tunnel** (Port 8443)
   - Sends POST request to `/vpn/tunnel`
   - Includes auth token (Authorization header)
   - Includes client public key (X-WireGuard-PublicKey header)
   - Socket is protected from routing through VPN

3. **Server registers the peer**
   - Receives client's public key
   - Adds client as authorized peer in WireGuard config
   - Sends 200 OK response

4. **WireGuard handshake completes** (Port 51820)
   - Client sends handshake initiation
   - Server recognizes the public key
   - Handshake succeeds
   - Data can flow!

5. **HTTP tunnel stays open**
   - Keepalive loop maintains the connection
   - Server can optionally use this for packet forwarding
   - Provides protocol mimicry (disguises VPN as HTTPS traffic)

## Testing

Build and install the updated APK:
```bash
flutter build apk --debug
```

Expected logs on successful connection:
```
🔵 Starting HTTP tunnel
   Protocol: https
   Server: orbx-eastus-vm.eastus.cloudapp.azure.com:51820
   Public Key: EDXNLCWPT7PJYKBFqVlT...
✅ Socket protected from VPN routing
🟢 REQUEST SENT, READING RESPONSE
🔵 Waiting for server response...
   Response status: HTTP/1.1 200 OK
✅ HTTP tunnel established successfully
🔵 HTTP tunnel socket is now open and protected
peer(oMqz…qkE8) - Sending handshake initiation
peer(oMqz…qkE8) - Received handshake response
✅ Tunnel is UP
📢 Broadcasting state: connected
```

## Server-Side Requirements

The server's `/vpn/tunnel` endpoint must:
1. Accept the `X-WireGuard-PublicKey` header
2. Validate the auth token
3. Add the client's public key to WireGuard's allowed peers
4. Return 200 OK response
5. Keep the connection open for optional packet forwarding

Example server code (Node.js/Express):
```javascript
app.post('/vpn/tunnel', (req, res) => {
  const authToken = req.headers.authorization?.replace('Bearer ', '');
  const publicKey = req.headers['x-wireguard-publickey'];
  const protocol = req.headers['x-protocol'];

  // Validate token
  if (!validateToken(authToken)) {
    return res.status(401).send('Unauthorized');
  }

  // Add peer to WireGuard
  wg.addPeer({
    publicKey: publicKey,
    allowedIPs: ['10.8.0.2/32'], // Assign IP to client
  });

  // Send success response
  res.status(200).send('Tunnel established');

  // Keep connection open for packet forwarding
  req.socket.setTimeout(0);
});
```

## Notes

- The socket protection (`protect()`) is critical to avoid circular routing
- The timeout prevents the app from hanging if the server is unreachable
- The keepalive loop ensures the tunnel stays open during the VPN session
- All protocol mimicry modes (teams, google, shaparak, etc.) now include the public key
