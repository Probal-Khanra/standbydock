package com.antigravity.standby_dock

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * MediaNotificationListener — a minimal NotificationListenerService.
 *
 * This service exists solely to satisfy the Android system requirement:
 * MediaSessionManager.getActiveSessions() requires a registered
 * NotificationListenerService component to be passed as the listener.
 *
 * The user must grant "Notification Access" permission in system settings
 * for this service to become active, which in turn unlocks media session access.
 *
 * No notification processing logic is needed here — all media session
 * polling is handled in MainActivity via MediaSessionManager.
 */
class MediaNotificationListener : NotificationListenerService() {

    companion object {
        @Volatile
        var isRunning: Boolean = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        // Intentionally empty — media metadata is captured via MediaSessionManager
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Intentionally empty
    }
}
