import Cocoa
import FlutterMacOS
import IOKit
import AudioToolbox
import CoreAudio

@main
class AppDelegate: FlutterAppDelegate {
    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    override func applicationDidFinishLaunching(_ notification: Notification) {
        requestPermissions()

        let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
        let channel = FlutterMethodChannel(name: "com.hybrid.office/monitor", binaryMessenger: controller.engine.binaryMessenger)

        channel.setMethodCallHandler { (call, result) in
            if call.method == "getActiveWindow" {
                let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
                if let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
                    if let info = windowList.first(where: { ($0[kCGWindowLayer as String] as? Int) == 0 }) {
                        let ownerName = info[kCGWindowOwnerName as String] as? String ?? "Unknown App"
                        let windowName = info[kCGWindowName as String] as? String ?? ""
                        if windowName.isEmpty {
                            result("\(ownerName)")
                        } else {
                            result("\(ownerName) - \(windowName)")
                        }
                    } else {
                        result("Desktop")
                    }
                } else {
                    result("Error: Access Denied")
                }
            }
            else if call.method == "forceFocus" {
                NSApp.activate(ignoringOtherApps: true)
                result(nil)
            }
            else if call.method == "getIdleTime" {
                result(Int(self.getSystemIdleTime()))
            }
            else if call.method == "isAudioPlaying" {
                var isRunning: UInt32 = 0
                var size = UInt32(MemoryLayout.size(ofValue: isRunning))

                // Using the raw FourCC code 'runn' for kAudioHardwarePropertyIsRunningSomewhere
                var address = AudioObjectPropertyAddress(
                    mSelector: AudioObjectPropertySelector(0x72756e6e),
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )

                let status = AudioObjectGetPropertyData(
                    AudioObjectID(kAudioObjectSystemObject),
                    &address,
                    0,
                    nil,
                    &size,
                    &isRunning
                )

                if status == noErr {
                    result(isRunning > 0)
                } else {
                    // Fallback or debug status
                    result(false)
                }
            }
            else {
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)

        if #available(macOS 10.15, *) {
            CGPreflightScreenCaptureAccess()
        }
    }

    private func getSystemIdleTime() -> Double {
        var idleTime = TimeInterval(0)
        var iter: io_iterator_t = 0
        let masterPort = kIOMasterPortDefault
        let matching = IOServiceMatching("IOHIDSystem")

        if IOServiceGetMatchingServices(masterPort, matching, &iter) == KERN_SUCCESS {
            let service = IOIteratorNext(iter)
            if service != 0 {
                var dict: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &dict, kCFAllocatorDefault, 0) == KERN_SUCCESS {
                    if let dict = dict?.takeRetainedValue() as NSDictionary? {
                        if let idleObj = dict["HIDIdleTime"] {
                            var nanoseconds: Int64 = 0
                            CFNumberGetValue((idleObj as! CFNumber), .sInt64Type, &nanoseconds)
                            idleTime = Double(nanoseconds) / 1_000_000_000.0
                        }
                    }
                }
                IOObjectRelease(service)
            }
            IOObjectRelease(iter)
        }
        return idleTime
    }
}