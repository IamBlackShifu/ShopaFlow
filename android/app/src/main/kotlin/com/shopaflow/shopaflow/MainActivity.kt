package com.shopaflow.shopaflow

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	override fun onResume() {
		super.onResume()
		enterKioskModeIfAvailable()
	}

	private fun enterKioskModeIfAvailable() {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
			return
		}

		val devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
		val adminComponent = ComponentName(this, KioskDeviceAdminReceiver::class.java)

		if (devicePolicyManager.isDeviceOwnerApp(packageName) &&
			!devicePolicyManager.isLockTaskPermitted(packageName)
		) {
			devicePolicyManager.setLockTaskPackages(adminComponent, arrayOf(packageName))
		}

		if (devicePolicyManager.isLockTaskPermitted(packageName)) {
			try {
				startLockTask()
			} catch (_: IllegalStateException) {
				// Already in lock task mode or the system rejected the request.
			}
		}
	}
}
