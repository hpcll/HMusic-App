package com.hupc.hmusic

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service 要求宿主 Activity 由它提供的基类承载，
// 否则后台/锁屏时 Flutter 引擎与前台服务的绑定会断。
class MainActivity : AudioServiceActivity()
