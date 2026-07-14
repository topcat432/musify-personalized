package com.gokadzev.musify

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : AudioServiceActivity() {
  companion object {
    private const val UPDATE_CHANNEL = "com.topcat432.musifypersonalized/updater"
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    WindowCompat.setDecorFitsSystemWindows(window, false)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      splashScreen.setOnExitAnimationListener { splashScreenView -> splashScreenView.remove() }
    }
    super.onCreate(savedInstanceState)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
      .setMethodCallHandler { call, result ->
        try {
          when (call.method) {
            "getInstalledIdentity" -> result.success(installedIdentity())
            "verifyUpdateApk" -> {
              verifyUpdateApk(call)
              result.success(null)
            }
            "installUpdateApk" -> result.success(installUpdateApk(call))
            else -> result.notImplemented()
          }
        } catch (error: Exception) {
          result.error("UPDATE_VERIFICATION_FAILED", error.message, null)
        }
      }
  }

  private fun installedIdentity(): Map<String, Any> {
    val packageInfo = packageInfoFor(packageName)
      ?: throw IllegalStateException("The installed package identity is unavailable.")
    return mapOf(
      "packageName" to packageName,
      "versionCode" to versionCode(packageInfo),
      "signerSha256" to signerSha256(packageInfo),
    )
  }

  private fun verifyUpdateApk(call: MethodCall) {
    val file = requireUpdateFile(call.argument<String>("path"))
    val expectedPackage = call.argument<String>("expectedPackage")
      ?: throw IllegalArgumentException("Missing expected package.")
    val expectedSigner = call.argument<String>("expectedSignerSha256")?.lowercase()
      ?: throw IllegalArgumentException("Missing expected signer.")
    val minimumVersion = call.argument<Number>("minimumVersionCode")?.toLong()
      ?: throw IllegalArgumentException("Missing expected version.")
    val archiveInfo = archivePackageInfo(file)
      ?: throw IllegalStateException("Android could not inspect the downloaded APK.")
    val archivePackage = archiveInfo.packageName
    val archiveVersion = versionCode(archiveInfo)
    val archiveSigner = signerSha256(archiveInfo)
    val installedSigner = signerSha256(
      packageInfoFor(packageName)
        ?: throw IllegalStateException("The installed signer is unavailable."),
    )

    check(archivePackage == expectedPackage && archivePackage == packageName) {
      "The downloaded APK has the wrong package identity."
    }
    check(archiveVersion == minimumVersion) {
      "The downloaded APK version does not match its signed release manifest."
    }
    check(archiveSigner == expectedSigner && archiveSigner == installedSigner) {
      "The downloaded APK was signed by a different Android key."
    }
  }

  private fun installUpdateApk(call: MethodCall): String {
    val file = requireUpdateFile(call.argument<String>("path"))
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
      !packageManager.canRequestPackageInstalls()
    ) {
      startActivity(
        Intent(
          Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
          Uri.parse("package:$packageName"),
        ),
      )
      return "permission_required"
    }

    val uri = FileProvider.getUriForFile(
      this,
      "$packageName.update_file_provider",
      file,
    )
    val intent = Intent(Intent.ACTION_VIEW).apply {
      setDataAndType(uri, "application/vnd.android.package-archive")
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    startActivity(intent)
    return "launched"
  }

  private fun requireUpdateFile(path: String?): File {
    val updatesDirectory = File(cacheDir, "updates").canonicalFile
    val file = File(path ?: throw IllegalArgumentException("Missing APK path.")).canonicalFile
    check(file.parentFile == updatesDirectory) {
      "The APK is outside Musify's protected update directory."
    }
    check(file.isFile && file.extension.lowercase() == "apk") {
      "The verified update APK is missing."
    }
    return file
  }

  @Suppress("DEPRECATION")
  private fun packageInfoFor(packageName: String): PackageInfo? {
    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      PackageManager.GET_SIGNING_CERTIFICATES
    } else {
      PackageManager.GET_SIGNATURES
    }
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      packageManager.getPackageInfo(
        packageName,
        PackageManager.PackageInfoFlags.of(flags.toLong()),
      )
    } else {
      packageManager.getPackageInfo(packageName, flags)
    }
  }

  @Suppress("DEPRECATION")
  private fun archivePackageInfo(file: File): PackageInfo? {
    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      PackageManager.GET_SIGNING_CERTIFICATES
    } else {
      PackageManager.GET_SIGNATURES
    }
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      packageManager.getPackageArchiveInfo(
        file.path,
        PackageManager.PackageInfoFlags.of(flags.toLong()),
      )
    } else {
      packageManager.getPackageArchiveInfo(file.path, flags)
    }
  }

  @Suppress("DEPRECATION")
  private fun signerSha256(packageInfo: PackageInfo): String {
    val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      val signingInfo = packageInfo.signingInfo
        ?: throw IllegalStateException("Android returned no signing information.")
      signingInfo.apkContentsSigners
    } else {
      packageInfo.signatures
        ?: throw IllegalStateException("Android returned no signatures.")
    }
    check(signatures.size == 1) { "Exactly one Android signer is required." }
    return MessageDigest.getInstance("SHA-256")
      .digest(signatures[0].toByteArray())
      .joinToString("") { byte -> "%02x".format(byte) }
  }

  @Suppress("DEPRECATION")
  private fun versionCode(packageInfo: PackageInfo): Long {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      packageInfo.longVersionCode
    } else {
      packageInfo.versionCode.toLong()
    }
  }
}
