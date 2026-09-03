package com.hupc.hmusic

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// audio_service 要求宿主 Activity 由它提供的基类承载，
// 否则后台/锁屏时 Flutter 引擎与前台服务的绑定会断。
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // App 内自更新（见 lib/core/upgrade/apk_updater.dart）：Dart 侧用 dio 把
        // APK 下到这里给出的缓存目录，再让系统安装器接手。Android 8+ 装包要
        // 「安装未知应用」授权，没授权就把用户送到那个开关页。
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "hmusic/apk_installer",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "cacheDir" -> result.success(cacheDir.absolutePath)
                "canInstall" -> result.success(canRequestInstall())
                "requestPermission" -> {
                    startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName"),
                        ),
                    )
                    result.success(null)
                }
                "install" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("PATH_MISSING", "缺少 APK 路径", null)
                    } else {
                        install(path)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canRequestInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()

    // content:// 交给系统安装器：APK 落在自家 cacheDir，file:// 从 Android 7 起
    // 会被 FileUriExposedException 挡下，必须经 FileProvider 授权。
    private fun install(path: String) {
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.updates",
            File(path),
        )
        startActivity(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_ACTIVITY_NEW_TASK,
                )
            },
        )
    }
}
