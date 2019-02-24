# PassBy
This is a highly customizable iOS Tweak that lets you avoid being asked for passcode when certain conditions are verified

These safe conditons are determined by the device's connectivity, and include a customizable timeout after which, even if the condition is still true, you will be asked for the passcode/biometrics again
## Unlock Options
- Unlock within a timeframe since last time the device was locked
- Specific WiFi networks
- Specific Bluetooth devices
- Wired Headphones plugged in
- Triggered by Activator Event

It can be chosen whether to enable the bypass upon connection or after the first normal unlock following the verification of the condition.

The tweak also allows to automatically dismiss the LockScreen CoverSheet when no notification or media controls are showing

# Security

The main concern people have with this tweak is whether it lowers the device's security, however that depends on the configuration.
The tweak employs AES128 to store both the device passcode and the WiFi networks/BT devices names.

The tweak will also warn users when they try to add an unprotected network to the whitelist, and this is due to the fact that if an attacker set up an open network with an identical name, your phone will connect to it and unlock itself if set to do so upon connection. This is actually very easy to reproduce due to WiFi Probe Requests.

