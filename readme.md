# 📘 WireGuard macOS Toolkit

### *Helper scripts to manage WireGuard on macOS (multi-interface + peer management)*

This repository contains a set of automation scripts designed to simplify the management of **WireGuard on macOS**, including:

* Initializing WireGuard interfaces (`wg0`, `wg1`, …)
* Automatic NAT configuration via macOS `pf`
* Secure server-key handling inside the project folder
* Creating peers with unique names
* Removing interfaces along with all associated peers and NAT rules

All server keys and peer data are stored locally inside the repository, while WireGuard configuration files used by `wg-quick` live in:

```
/opt/homebrew/etc/wireguard/
```

---

# 🗂 Project Structure

```
.
├── init_interface.sh           # Initialize wgX (wg0, wg1…)
├── add_peer.sh                 # Create a peer + add to wgX.conf
├── rm_interface.sh             # Remove wgX (pf cleanup + peers cleanup)
├── keys/                       # Server private/public keys
├── peers/                      # Peer folders (wgX-peerName)
│   ├── wg0-iphone/
│   ├── wg0-macbook/
│   └── wg1-lab/
└── readme.md
```

---

# 🚀 Requirements

### Install WireGuard tools via Homebrew:

```bash
brew install wireguard-tools qrencode
```

Required binaries:

* `wg`
* `wg-quick`
* `qrencode` (for generating QR codes for mobile clients)

---

# 🛠 Initialize an Interface

You can create as many interfaces as you want (`wg0`, `wg1`, …).

Example:

```bash
./init_interface.sh wg0 51820
```

This will:

* Generate server keys (only once) inside `./keys`
* Create `/opt/homebrew/etc/wireguard/wg0.conf`
* Set up NAT rules in:

  ```
  /etc/pf.anchors/wg0
  ```
* Insert the block into `/etc/pf.conf`
* Reload `pf`

Then bring the interface up:

```bash
sudo wg-quick up wg0
```

---

# 👤 Add a Peer

Peers are stored inside:

```
./peers/wg0-mydevice/
```

Example:

```bash
./add_peer.sh wg0 iphone YOUR_PUBLIC_IP_OR_DNS:51820
```

This will:

* Create `./peers/wg0-iphone`
* Generate peer keys
* Create the peer's `.conf`
* Append the peer to `/opt/homebrew/etc/wireguard/wg0.conf`
* Restart the interface
* Show a **QR code** you can scan on iOS/Android

You can also manually copy the `.conf` to another device.

---

# 🗑 Remove an Interface

This removes **everything related to the interface**, including:

* Shutting down the interface
* Removing NAT rules
* Remove the `.conf` file
* Delete the WireGuard config file (`/opt/homebrew/etc/wireguard/wg0.conf`)
* Remove all peer folders matching `peers/wgX-*`

Manual steps: 

* remove anchor file
* clean pf.conf file WireGuard block

Example:

```bash
./rm_interface.sh wg0
```

---

# 🔑 Server Key Location

Server keys always live inside:

```
./keys/server_private.key
./keys/server_public.key
```

These keys **never** get stored in `/opt/homebrew` for security purposes.

⚠️ Do **not** share `server_private.key`.

---

# 🔒 Security Notes

The scripts enforce secure permissions:

* `./keys` & `./peers` directories → `chmod 700`
* Private keys → `chmod 600`
* WireGuard server configs → `chmod 600`

---

# ✨ Recommended Usage Flow

**1. Initialize interface**

```bash
./init_interface.sh wg0 51820
```

**2. Bring interface up**

```bash
sudo wg-quick up wg0
```

**3. Add peers**

```bash
./add_peer.sh wg0 iphone myvpn.ddns.net:51820
./add_peer.sh wg0 ipad myvpn.ddns.net:51820
```

**4. Remove interface (when no longer needed)**

```bash
./rm_interface.sh wg0
```

---

# 🧪 Quick Testing

From a peer:

```bash
ping 10.0.0.1         # Test server reachability
curl http://10.0.0.1  # Access a local service
```

---

# 📝 Additional Notes

* Each interface gets its own subnet:

  * `wg0 → 10.0.0.0/24`
  * `wg1 → 10.0.1.0/24`
  * `wg2 → 10.0.2.0/24`
* Peers are automatically assigned an IP inside that range.
* NAT allows peers to reach any service running on your Mac.
