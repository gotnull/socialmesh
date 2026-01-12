import UserNotifications
import os.log

class NotificationService: UNNotificationServiceExtension {
    
    private let logger = OSLog(subsystem: "com.gotnull.socialmesh.NotificationServiceExtension", category: "NotificationService")
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        os_log("🔔 [NSE] didReceive called - Extension is running!", log: logger, type: .info)
        os_log("🔔 [NSE] Request identifier: %{public}@", log: logger, type: .info, request.identifier)
        
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        // Log all userInfo for debugging
        os_log("🔔 [NSE] Full userInfo keys: %{public}@", log: logger, type: .info, String(describing: request.content.userInfo.keys))
        os_log("🔔 [NSE] Full userInfo: %{public}@", log: logger, type: .debug, String(describing: request.content.userInfo))
        
        guard let bestAttemptContent = bestAttemptContent else {
            os_log("❌ [NSE] Failed to create mutableCopy of content", log: logger, type: .error)
            contentHandler(request.content)
            return
        }
        
        os_log("🔔 [NSE] Title: %{public}@", log: logger, type: .info, bestAttemptContent.title)
        os_log("🔔 [NSE] Body: %{public}@", log: logger, type: .info, bestAttemptContent.body)
        
        // Check for FCM image URL in different possible locations
        var imageURLString: String?
        
        // Try fcm_options.image (standard FCM location)
        if let fcmOptions = request.content.userInfo["fcm_options"] as? [String: Any] {
            os_log("🔔 [NSE] Found fcm_options: %{public}@", log: logger, type: .info, String(describing: fcmOptions))
            if let image = fcmOptions["image"] as? String {
                os_log("✅ [NSE] Found image in fcm_options.image: %{public}@", log: logger, type: .info, image)
                imageURLString = image
            } else if let imageUrl = fcmOptions["imageUrl"] as? String {
                os_log("✅ [NSE] Found image in fcm_options.imageUrl: %{public}@", log: logger, type: .info, imageUrl)
                imageURLString = imageUrl
            }
        } else {
            os_log("🔔 [NSE] No fcm_options found in userInfo", log: logger, type: .info)
        }
        
        // Try data.image
        if imageURLString == nil {
            if let data = request.content.userInfo["data"] as? [String: Any] {
                os_log("🔔 [NSE] Found data dict: %{public}@", log: logger, type: .info, String(describing: data))
                if let image = data["image"] as? String {
                    os_log("✅ [NSE] Found image in data: %{public}@", log: logger, type: .info, image)
                    imageURLString = image
                }
            }
        }
        
        // Try top-level image
        if imageURLString == nil {
            if let image = request.content.userInfo["image"] as? String {
                os_log("✅ [NSE] Found top-level image: %{public}@", log: logger, type: .info, image)
                imageURLString = image
            }
        }
        
        // Try aps.alert.image
        if imageURLString == nil {
            if let aps = request.content.userInfo["aps"] as? [String: Any] {
                os_log("🔔 [NSE] Found aps: %{public}@", log: logger, type: .info, String(describing: aps))
                if let alert = aps["alert"] as? [String: Any],
                   let image = alert["image"] as? String {
                    os_log("✅ [NSE] Found image in aps.alert: %{public}@", log: logger, type: .info, image)
                    imageURLString = image
                }
                // Check mutable-content
                if let mutableContent = aps["mutable-content"] as? Int {
                    os_log("🔔 [NSE] mutable-content value: %d", log: logger, type: .info, mutableContent)
                }
            }
        }
        
        // Try gcm.notification.image (legacy)
        if imageURLString == nil {
            if let gcm = request.content.userInfo["gcm.notification.image"] as? String {
                os_log("✅ [NSE] Found gcm.notification.image: %{public}@", log: logger, type: .info, gcm)
                imageURLString = gcm
            }
        }
        
        // Try imageUrl (our custom key)
        if imageURLString == nil {
            if let imageUrl = request.content.userInfo["imageUrl"] as? String {
                os_log("✅ [NSE] Found imageUrl: %{public}@", log: logger, type: .info, imageUrl)
                imageURLString = imageUrl
            }
        }
        
        guard let finalImageURLString = imageURLString,
              let imageURL = URL(string: finalImageURLString) else {
            os_log("⚠️ [NSE] No valid image URL found, delivering notification without image", log: logger, type: .info)
            contentHandler(bestAttemptContent)
            return
        }
        
        os_log("🔔 [NSE] Starting download from: %{public}@", log: logger, type: .info, finalImageURLString)
        
        // Download the image
        downloadImage(from: imageURL) { [weak self] attachment in
            if let attachment = attachment {
                os_log("✅ [NSE] Successfully attached image!", log: self?.logger ?? OSLog.default, type: .info)
                bestAttemptContent.attachments = [attachment]
            } else {
                os_log("❌ [NSE] Failed to create attachment", log: self?.logger ?? OSLog.default, type: .error)
            }
            os_log("🔔 [NSE] Calling contentHandler", log: self?.logger ?? OSLog.default, type: .info)
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        os_log("⏰ [NSE] serviceExtensionTimeWillExpire called!", log: logger, type: .error)
        // Called just before the extension will be terminated by the system.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    private func downloadImage(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        os_log("🔔 [NSE] downloadImage starting for: %{public}@", log: logger, type: .info, url.absoluteString)
        
        let task = URLSession.shared.downloadTask(with: url) { [weak self] localURL, response, error in
            let logger = self?.logger ?? OSLog.default
            
            if let error = error {
                os_log("❌ [NSE] Download error: %{public}@", log: logger, type: .error, error.localizedDescription)
                completion(nil)
                return
            }
            
            guard let localURL = localURL else {
                os_log("❌ [NSE] No local URL after download", log: logger, type: .error)
                completion(nil)
                return
            }
            
            os_log("✅ [NSE] Download completed to: %{public}@", log: logger, type: .info, localURL.path)
            
            if let httpResponse = response as? HTTPURLResponse {
                os_log("🔔 [NSE] HTTP Status: %d", log: logger, type: .info, httpResponse.statusCode)
                os_log("🔔 [NSE] Content-Type: %{public}@", log: logger, type: .info, httpResponse.mimeType ?? "unknown")
            }
            
            // Determine file extension from response or URL
            let pathExtension: String
            if let mimeType = (response as? HTTPURLResponse)?.mimeType {
                switch mimeType {
                case "image/jpeg":
                    pathExtension = "jpg"
                case "image/png":
                    pathExtension = "png"
                case "image/gif":
                    pathExtension = "gif"
                default:
                    pathExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
                }
            } else {
                pathExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            }
            
            os_log("🔔 [NSE] Using file extension: %{public}@", log: logger, type: .info, pathExtension)
            
            // Create a unique file name
            let uniqueURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(pathExtension)
            
            os_log("🔔 [NSE] Moving to: %{public}@", log: logger, type: .info, uniqueURL.path)
            
            do {
                try FileManager.default.moveItem(at: localURL, to: uniqueURL)
                os_log("✅ [NSE] File moved successfully", log: logger, type: .info)
                
                let attachment = try UNNotificationAttachment(identifier: "image", url: uniqueURL, options: nil)
                os_log("✅ [NSE] Attachment created successfully", log: logger, type: .info)
                completion(attachment)
            } catch {
                os_log("❌ [NSE] Error creating attachment: %{public}@", log: logger, type: .error, error.localizedDescription)
                completion(nil)
            }
        }
        task.resume()
        os_log("🔔 [NSE] Download task resumed", log: logger, type: .info)
    }
}
