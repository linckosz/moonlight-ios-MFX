# Moonlight iOS/tvOS

This fork reimplements the upstream Moonlight client with a few improvements and we hope to upstream it ultimately. (This fork will constantly be updated.)
--
Any new ideas are welcome, it might be a good idea to open an issue to discuss it and maybe be implemented.
-- 
Changes:
* Audio ducking disabled by default.
* Reimplements a brand new Multi-touch passthrough (Sunshine 0.21.0+) functionality. (Up to 10 fingers)
* Moved the old touch functionality to legacy mode.
* Host PC multi-monitor switching. (Up to 3 monitors)
* Apple-pencil support now only available on new Multi-touch passthrough mode.
* Multiple gesture changes & New gestures:
  * Two-finger swipes up to open up the keyboard.
  * Two-finger swipes down to close the keyboard.
  * Two-finger swipes left to switch to previous monitor.
  * Two-finger swipes right to switch to next monitor.

---
本分支是对上游Moonlight客户端的fork，增加了一些改进和希望最终被上游合并。本分支会不断更新。
---
任何新的想法都是欢迎的，最好的办法是打开一个issue讨论它，然后它可能被实现。
---
修改：
* 禁用了串流自动降低其他正在播放的音频。
* 重新实现了一个全新的多触点透传（Sunshine 0.21.0+）功能。（最多10个手指）
* 移动了旧的触控功能到legacy模式。
* 主机PC多屏幕切换。最多3个屏幕
* Apple-pencil支持现在只可用在新多触点透传模式下。
* 修改了多触点功能，新增了以下手势：
  * 两指向上滑动打开键盘。
  * 两指向下滑动关闭键盘。
  * 两指向左滑动切换到上一个屏幕。
  * 两指向右滑动切换到下一个屏幕。


[![AppVeyor Build Status](https://ci.appveyor.com/api/projects/status/kwv8vpwr457lqn25/branch/master?svg=true)](https://ci.appveyor.com/project/cgutman/moonlight-ios/branch/master)

[Moonlight for iOS/tvOS](https://moonlight-stream.org) is an open source client for [Sunshine](https://github.com/LizardByte/Sunshine) and NVIDIA GameStream. Moonlight for iOS/tvOS allows you to stream your full collection of games and apps from your powerful desktop computer to your iOS device or Apple TV.

Moonlight also has a [PC client](https://github.com/moonlight-stream/moonlight-qt) and [Android client](https://github.com/moonlight-stream/moonlight-android).

Check out [the Moonlight wiki](https://github.com/moonlight-stream/moonlight-docs/wiki) for more detailed project information, setup guide, or troubleshooting steps.

[![Moonlight for iOS and tvOS](https://moonlight-stream.org/images/App_Store_Badge_135x40.svg)](https://apps.apple.com/us/app/moonlight-game-streaming/id1000551566)

## Building
* Install Xcode from the [App Store page](https://apps.apple.com/us/app/xcode/id497799835)
* Run `git clone --recursive https://github.com/moonlight-stream/moonlight-ios.git`
  *  If you've already clone the repo without `--recursive`, run `git submodule update --init --recursive`
* Open Moonlight.xcodeproj in Xcode
* To run on a real device, you will need to locally modify the signing options:
    * Click on "Moonlight" at the top of the left sidebar
    * Click on the "Signing & Capabilities" tab
    * Under "Targets", select "Moonlight" (for iOS/iPadOS) or "Moonlight TV" (for tvOS)
    * In the "Team" dropdown, select your name. If your name doesn't appear, you may need to sign into Xcode with your Apple account.
    * Change the "Bundle Identifier" to something different. You can add your name or some random letters to make it unique.
    * Now you can select your Apple device in the top bar as a target and click the Play button to run.
