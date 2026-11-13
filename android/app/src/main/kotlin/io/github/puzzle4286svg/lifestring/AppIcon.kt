package io.github.puzzle4286svg.lifestring

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Switches the launcher icon (D50) by enabling exactly one of the
 * activity-aliases declared in AndroidManifest.xml. Android keeps the
 * choice across restarts and app updates.
 *
 * Android closes every screen that was opened through a launcher entry when
 * that entry is disabled, so [set] only records the choice; MainActivity
 * applies it with [applyPending] once the app is in the background.
 */
object AppIcon {
    private const val CHANNEL = "time_tracker/app_icon"
    private const val PREFS = "app_icon"
    private const val PENDING = "pending"

    /** Icon names used by Dart, mapped to their alias class names. */
    private val aliases = linkedMapOf(
        "neon" to ".IconNeon", // manifest default
        "flat" to ".IconFlat",
    )

    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "current" -> result.success(pending(context) ?: enabled(context))
                "set" -> {
                    val name = call.arguments as? String
                    if (name == null || name !in aliases) {
                        result.error("unknown_icon", "Unknown icon: $name", null)
                    } else {
                        set(context, name)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Applies a choice made in Settings, if any. Closes the app's screen. */
    fun applyPending(context: Context) {
        val name = pending(context) ?: return
        prefs(context).edit().remove(PENDING).apply()
        if (name == enabled(context)) return
        val pm = context.packageManager
        // Enable the new entry first, so the app never has no launcher icon.
        pm.setComponentEnabledSetting(
            component(context, name),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for (other in aliases.keys) {
            if (other == name) continue
            pm.setComponentEnabledSetting(
                component(context, other),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }

    private fun set(context: Context, name: String) {
        val editor = prefs(context).edit()
        // Choosing the icon that is already shown cancels a pending change.
        if (name == enabled(context)) editor.remove(PENDING) else editor.putString(PENDING, name)
        editor.apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun pending(context: Context): String? =
        prefs(context).getString(PENDING, null)?.takeIf { it in aliases }

    // Alias class names come from the Kotlin package (the manifest's
    // ".IconNeon" is relative to the namespace), not from the app ID, which
    // has a ".dev" suffix in debug builds.
    private fun component(context: Context, name: String) =
        ComponentName(context, MainActivity::class.java.`package`!!.name + aliases.getValue(name))

    private fun isEnabled(context: Context, name: String, byDefault: Boolean): Boolean =
        when (context.packageManager.getComponentEnabledSetting(component(context, name))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> byDefault
            else -> false
        }

    /** The icon the launcher shows now. */
    private fun enabled(context: Context): String =
        aliases.keys.firstOrNull { it != "neon" && isEnabled(context, it, false) } ?: "neon"
}
