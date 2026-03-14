# WeChatTweak

[![README](https://img.shields.io/badge/GitHub-black?logo=github&logoColor=white)](https://github.com/sunnyyoung/WeChatTweak)
[![README](https://img.shields.io/badge/Telegram-black?logo=telegram&logoColor=white)](https://t.me/wechattweak)
[![README](https://img.shields.io/badge/FAQ-black?logo=googledocs&logoColor=white)](https://github.com/sunnyyoung/WeChatTweak/wiki/FAQ)

A command-line tool for tweaking WeChat.

## 功能

- 阻止消息撤回
- 阻止自动更新
- 客户端多开

## 安装&使用

```bash
# 安装
brew install tanranv5/tap/wechattweak

# 更新
brew upgrade tanranv5/tap/wechattweak

# 执行 Patch
wechattweak patch

# 查看所有支持的 WeChat 版本
wechattweak versions
```

## 最新适配

- `wx.app 4.1.8.27 (36559)` 下载地址：
  `https://dldir1v6.qq.com/weixin/Universal/Mac/xWeChatMac_universal_4.1.8.27_36559.dmg?t=1770782406`
- 本次变更仅做了两类最小补充：
  - `config.json` 新增 `36559` 的 x86_64 防撤回和多开配置
  - patch 流程新增 `target.binary` 支持，可直接对 `Contents/Frameworks/wechat.dylib` 打补丁；旧版构建产物只会 patch `Contents/MacOS/WeChat`，不适用于这一版

## 参考

- [微信 macOS 客户端无限多开功能实践](https://blog.sunnyyoung.net/wei-xin-macos-ke-hu-duan-wu-xian-duo-kai-gong-neng-shi-jian/)
- [微信 macOS 客户端拦截撤回功能实践](https://blog.sunnyyoung.net/wei-xin-macos-ke-hu-duan-lan-jie-che-hui-gong-neng-shi-jian/)
- [让微信 macOS 客户端支持 Alfred](https://blog.sunnyyoung.net/rang-wei-xin-macos-ke-hu-duan-zhi-chi-alfred/)

## 贡献者

This project exists thanks to all the people who contribute.

[![Contributors](https://contrib.rocks/image?repo=sunnyyoung/WeChatTweak)](https://github.com/sunnyyoung/WeChatTweak/graphs/contributors)

## License

The [AGPL-3.0](LICENSE).
