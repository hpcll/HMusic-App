import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hupc.hmusic"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hupc.hmusic"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    }
    val hasReleaseSigning = keystorePropertiesFile.exists()

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 没有 release key 时保持 unsigned；正式发布工作流必须注入签名配置。
            if (hasReleaseSigning) {
                signingConfigs.getByName("release")
                    .also { signingConfig = it }
            }
        }
        // debug/profile 包也用 release 签名：真机调试（flutter run --debug /
        // --profile）要无损盖装 release 签名的正式安装，默认 debug 签名会撞
        // 签名冲突导致必须卸载重装丢数据。
        if (hasReleaseSigning) {
            getByName("debug") {
                signingConfigs.getByName("release")
                    .also { signingConfig = it }
            }
            getByName("profile") {
                signingConfigs.getByName("release")
                    .also { signingConfig = it }
            }
        }
    }
}

flutter {
    source = "../.."
}

// 把分架构包的 versionCode 掰回构建号本身，让四个安卓包同号。
//
// flutter build apk --split-per-abi 会给每个带芯片标记的产物把 versionCode 改写成
// 「芯片基数 * 1000 + 构建号」（基数见 Flutter Gradle 插件的 FlutterPluginConstants.ABI_VERSION：
// armeabi-v7a=1 / arm64-v8a=2 / x86_64=4），官方注释写明是为了让多个 APK 能一起传上
// Google Play——Play 要求同一应用的多个 APK 版本号互不相同。代价是四个包版本号不一致，
// 而安卓只允许「版本号不低于已装包」的覆盖安装：装过 arm64 包（2008）的设备再收到通用包（8）
// 会被当降级拒装，只报一句「应用未安装」。网盘里放的就是通用包，手动下载正好踩这个坑。
// 我们只走 GitHub Release + 网盘、不上 Play，不受这条约束。
//
// 时序上必须注册在 plugins 块之后：Flutter 插件是在 apply() 里注册 configureEach 的，
// Gradle 按注册顺序回调，这里晚于它，所以这次赋值会盖掉它的改写。
// 谁把这个前提改坏了（比如以后 Flutter 换成 androidComponents.onVariants），
// tool/build_release.sh 的版本号一致性校验会直接让发布失败。
android.applicationVariants.configureEach {
    outputs.forEach { output ->
        // 只碰 APK 产物：AAB（bundleRelease）的输出不是 ApkVariantOutput，
        // 而且 AAB 的版本号本来就取自 defaultConfig，不需要改。
        @Suppress("DEPRECATION")
        val apkOutput = output as? com.android.build.gradle.api.ApkVariantOutput
        if (apkOutput != null) {
            apkOutput.versionCodeOverride = flutter.versionCode
        }
    }
}
