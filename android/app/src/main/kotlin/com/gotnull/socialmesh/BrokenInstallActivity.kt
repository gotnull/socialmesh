package com.gotnull.socialmesh

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * Recovery screen for an install that is missing the native libraries the
 * Flutter engine loads at startup. Runs in its own process, so it survives the
 * kill of the process that could not start, and builds its views in code so it
 * has no dependency on anything the broken package may also be missing.
 */
class BrokenInstallActivity : Activity() {

    companion object {
        private const val TAG = "BrokenInstall"
        private const val MARKET_URI = "market://details?id="
        private const val WEB_URI = "https://play.google.com/store/apps/details?id="
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildContent())
    }

    private fun buildContent(): View {
        val gutter = dp(24)

        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            // Centred rather than top-aligned: the screen holds one short
            // message, and pinning it to the top leaves the page reading as
            // half-drawn on a tall display.
            gravity = Gravity.CENTER
            setPadding(gutter, dp(48), gutter, dp(48))
        }

        column.addView(
            ImageView(this).apply {
                setImageResource(R.mipmap.ic_launcher)
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
                layoutParams = LinearLayout.LayoutParams(dp(72), dp(72))
            }
        )

        column.addView(
            TextView(this).apply {
                setText(R.string.broken_install_title)
                setTextColor(getColor(R.color.broken_install_title))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
                layoutParams = spacedRow(dp(24))
            }
        )

        column.addView(
            TextView(this).apply {
                setText(R.string.broken_install_body)
                setTextColor(getColor(R.color.broken_install_body))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                gravity = Gravity.CENTER
                setLineSpacing(dp(4).toFloat(), 1f)
                layoutParams = spacedRow(dp(16))
            }
        )

        column.addView(
            Button(this).apply {
                setText(R.string.broken_install_action)
                setTextColor(getColor(R.color.broken_install_action_label))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                setAllCaps(false)
                background = GradientDrawable().apply {
                    cornerRadius = dp(12).toFloat()
                    setColor(getColor(R.color.broken_install_action))
                }
                setPadding(dp(24), dp(14), dp(24), dp(14))
                layoutParams = spacedRow(dp(32))
                setOnClickListener { openStoreListing() }
            }
        )

        return ScrollView(this).apply {
            setBackgroundColor(getColor(R.color.broken_install_background))
            isFillViewport = true
            addView(
                column,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
            )
        }
    }

    private fun openStoreListing() {
        if (startViewIntent(MARKET_URI + packageName)) return
        if (startViewIntent(WEB_URI + packageName)) return
        Log.w(TAG, "No activity on this device can open the store listing")
    }

    private fun startViewIntent(uri: String): Boolean = try {
        startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(uri))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        true
    } catch (unresolved: ActivityNotFoundException) {
        Log.w(TAG, "Could not open $uri", unresolved)
        false
    }

    private fun spacedRow(topMargin: Int): LinearLayout.LayoutParams =
        LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { this.topMargin = topMargin }

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()
}
