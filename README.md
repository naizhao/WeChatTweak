# WeChatTweak

[![README](https://img.shields.io/badge/GitHub-black?logo=github&logoColor=white)](https://github.com/sunnyyoung/WeChatTweak)
[![README](https://img.shields.io/badge/Telegram-black?logo=telegram&logoColor=white)](https://t.me/wechattweak)
[![README](https://img.shields.io/badge/FAQ-black?logo=googledocs&logoColor=white)](https://github.com/sunnyyoung/WeChatTweak/wiki/FAQ)

A command-line tool for tweaking WeChat.

## 功能

- 阻止消息撤回
- 阻止自动更新
- 客户端多开

## 说明

- 由于设备限制，本项目当前仅支持 x64 架构的微信最新版。（下载地址：https://dldir1v6.qq.com/weixin/Universal/Mac/xWeChatMac_universal_4.1.7.55_34817.dmg?t=1770782406）

## 安装&使用

```bash
# 安装
brew install sunnyyoung/tap/wechattweak

# 更新
brew upgrade wechattweak

# 执行 Patch（官方配置，默认应用名 WeChat.app）
wechattweak patch

# 执行 Patch（官方配置，应用名改为 wx.app）
wechattweak patch -a /Applications/wx.app

# 执行 Patch（使用 tanranv5 仓库的 config.json）
wechattweak patch -c https://raw.githubusercontent.com/tanranv5/WeChatTweak/refs/heads/master/config.json

#多开
open -n /Applications/wx.app

# 查看所有支持的 WeChat 版本
wechattweak versions
```

## 参考

- [微信 macOS 客户端无限多开功能实践](https://blog.sunnyyoung.net/wei-xin-macos-ke-hu-duan-wu-xian-duo-kai-gong-neng-shi-jian/)
- [微信 macOS 客户端拦截撤回功能实践](https://blog.sunnyyoung.net/wei-xin-macos-ke-hu-duan-lan-jie-che-hui-gong-neng-shi-jian/)
- [让微信 macOS 客户端支持 Alfred](https://blog.sunnyyoung.net/rang-wei-xin-macos-ke-hu-duan-zhi-chi-alfred/)

## 贡献者

This project exists thanks to all the people who contribute.

[![Contributors](https://contrib.rocks/image?repo=sunnyyoung/WeChatTweak)](https://github.com/sunnyyoung/WeChatTweak/graphs/contributors)

## License

The [AGPL-3.0](LICENSE).
