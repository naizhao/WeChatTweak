# 维护指南

每次微信发布新版本，`config.json` 里的函数 VA 都要重新定位。这份文档记录了寻址流程、patch 字节构造方法，以及常见坑。

---

## 适用范围

- macOS WeChat 4.1+（业务代码搬到 `Contents/Resources/wechat.dylib` 之后）
- 同时维护 arm64（Apple Silicon 原生）和 x86_64（Intel / Rosetta）两个 slice

---

## 工作流：跟版新 build

### 1. 拿到新 build 号

```bash
defaults read /Applications/WeChat.app/Contents/Info.plist CFBundleVersion
```

输出形如 `268575`，这就是 `config.json` 里 `"version"` 字段要填的值。

### 2. 提取 thin slice

`Resources/wechat.dylib` 是 universal（同时含 x86_64/i386/armv7/arm64），用 `lipo` 抽出单架构方便分析：

```bash
SRC=/Applications/WeChat.app/Contents/Resources/wechat.dylib

# arm64 切片
lipo -thin arm64 "$SRC" -output /tmp/wechat-arm64.dylib

# x86_64 切片（如果 fork 主线还没适配该 build 的 x86_64，需要自己找）
lipo -thin x86_64 "$SRC" -output /tmp/wechat-x86_64.dylib
```

### 3. Ghidra 加载并自动分析

1. New Project → `File → Import File` → 选 `/tmp/wechat-arm64.dylib`
2. Loader: **Mach-O AArch64**（x86_64 切片选 `Mach-O x86_64`）
3. 双击导入的文件 → 提示 "Analyze now?" 选 **Yes**
4. 默认分析选项即可。**取消勾选** "Decompiler Parameter ID" 可加速 30-50%
5. M2 Max 上 arm64 切片大约 15-30 分钟，期间不要操作 Ghidra

### 4. 用字符串锚点定位 revoke 函数

撤回处理函数（同时引用 `subtype` / `content` / `revokemsg` / `chat_id` / `replacement` 字段名）有一个稳定的 cstring 锚点，跨版本通常都在：

```
TryParseMessageXunknown subtype:content_templaterevoke_climsgid
```

操作步骤：

1. `Search → For Strings...`（或 `Window → Defined Strings`）
2. Filter 输入 `revoke_climsgid` 或 `TryParseMessageX`
3. 双击命中的字符串地址（每版本 VA 不同）
4. **右键 → References → Show References to Address**
5. 弹窗里通常显示 4-6 条引用（对应 cstring 内 4 个不同子串的偏移），地址都在同一个函数附近
6. 双击其中**地址最低**的那条 → 跳进代码
7. 按 `Home` 滚到当前函数顶部
8. Listing 第一行的地址（`FUN_05xxxxxx` 形式）就是 **arm64 revoke 函数入口 VA**

### 5. 验证特征

正确的撤回处理函数应该满足：

- ✅ 大栈帧：prologue 里 `sub sp, sp, #0x2X0` 或类似（约 0x290 字节）
- ✅ 接收 3 个参数：`mov x{19,20,21}, x{0,1,2}` 把传入参数保存到 callee-saved
- ✅ 函数体内多次 `bl` 到 `std::__1::basic_string::assign` 之类的字符串操作
- ✅ Decompiler 视图能看到字符级常量赋值（编译器把短字面量拆成单字节 store）：
  ```c
  DAT_xxxx._0_1_ = 's';
  DAT_xxxx._1_1_ = 'u';
  DAT_xxxx._2_1_ = 'b';
  ...
  ```

如果看到的是 ORM 字段注册之类（引用 `message_id` / `sender_id` / `chat_id` 等结构化字段名），那是别的函数，不要 patch；回到 References 列表换一条引用试。

### 6. （可选）找 x86_64 同源函数

x86_64 切片重复步骤 3-5，找同一个字符串的引用 → 函数入口。

通常 fork 主线（tanranv5）会先完成 x86_64 适配，可以直接抄它的 entry。

### 7. 写进 config.json

复制 `268575` 项作为模板，改 `version` 和 `addr`：

```json
{
  "version": "新build号",
  "targets": [
    {
      "identifier": "revoke",
      "entries": [
        { "arch": "arm64",  "addr": "你找到的arm64 VA",  "asm": "20008052C0035FD6" },
        { "arch": "x86_64", "addr": "x86_64同源VA",      "asm": "B801000000C3"     }
      ],
      "binary": "Contents/Resources/wechat.dylib"
    }
  ]
}
```

`asm` 字段保持不变即可（`mov w0, #1; ret` 跨版本语义稳定）。

### 8. 编译 + patch + 测试

```bash
cd /path/to/WeChatTweak
make build

killall WeChat 2>/dev/null
./wechattweak patch -c ./config.json

open /Applications/WeChat.app
```

让朋友撤回一条消息测试是否生效。

---

## ARM64 patch 字节构造

ARM64 指令固定 4 字节，**小端**存储。常用 patch 字节：

| 目的 | 汇编 | 字节 (hex) |
|---|---|---|
| 函数返回 1 | `mov w0, #1` + `ret` | `20008052C0035FD6` |
| 函数返回 0 | `mov w0, #0` + `ret` | `00008052C0035FD6` |
| 函数返回 -1 | `movn w0, #0` + `ret` | `00008012C0035FD6` |
| 单条 NOP | `nop` | `1F2003D5` |
| 直接 ret（4 字节，原指令必须 4 字节） | `ret` | `C0035FD6` |

### MOVZ 编码原理

`MOVZ Wd, #imm16` 32-bit no-shift 编码（ARMv8 ARM C6.2.219）：

```
0x52800000 | (imm16 << 5) | Rd
```

其中 imm16 是 0..0xFFFF 的立即数，Rd 是 W0..W30（编号 0..30）。

例：

- `MOVZ W0, #1` = `0x52800000 | (1 << 5) | 0` = `0x52800020` → 小端字节 `20 00 80 52`
- `MOVZ W0, #0x42` = `0x52800000 | (0x42 << 5) | 0` = `0x52800840` → 小端字节 `40 08 80 52`

### 一行 Python 算字节

```python
python3 -c "
import struct
imm16, rd = 1, 0
inst = 0x52800000 | (imm16 << 5) | rd
print(struct.pack('<I', inst).hex())
# 后接 ret = C0035FD6
"
```

### RET 编码

固定 `0xD65F03C0`，小端字节 `C0 03 5F D6`。

---

## x86_64 patch 字节速查

fork 主线维护的 x86_64 patch 通常用：

| 目的 | 字节 (hex) | 解释 |
|---|---|---|
| 函数返回 1 | `B801000000C3` | `mov eax, 1; ret` |
| 函数返回 0 | `31C0C3` | `xor eax, eax; ret`（3 字节） |
| 6 字节 NOP（覆盖一条 `je rel32`） | `909090909090` | 6 个 NOP |

x86_64 指令变长，patch 字节数必须**严格等于**原指令字节数，否则会破坏后续指令边界。

---

## 常见问题

### 启动崩溃 `EXC_BAD_ACCESS (SIGKILL (Code Signature Invalid))`

错误特征：

```
Termination Reason: Namespace CODESIGNING, Code 2, Invalid Page
Kernel Triage: VM - A memory corruption was found in executable text
```

**原因**：`codesign --force --deep --sign -` 在 macOS 14+ 上不会对 `Contents/Resources/` 下的 dylib 重新计算页 hash。bundle 整体 verify 通过，但加载到 patch 那一页时 kernel 检查页 hash 不匹配 → SIGKILL。

**解决**：本仓库的 `Command.swift::resign` 已经修复——会在 `--deep` 整体重签后，对每个被 patch 的 binary 单独 `codesign --force --sign -` 一次。如果你跑的是旧版二进制，重新 `make build`。

如果是手动 patch（没用本工具），手动跑：

```bash
sudo codesign --force --sign - /Applications/WeChat.app/Contents/Resources/wechat.dylib
sudo codesign --force --deep --sign - /Applications/WeChat.app
xattr -cr /Applications/WeChat.app
```

### 临时回退方案：强制 Rosetta

新版本还没适配 arm64 时，可以让微信走 x86_64（Rosetta）跑，复用 fork 主线已有的 x86_64 patch：

```bash
# 备份启动壳
sudo cp /Applications/WeChat.app/Contents/MacOS/WeChat \
        /Applications/WeChat.app/Contents/MacOS/WeChat.universal.bak

# 删掉启动壳的 arm64 切片
sudo lipo -remove arm64 \
    /Applications/WeChat.app/Contents/MacOS/WeChat \
    -output /Applications/WeChat.app/Contents/MacOS/WeChat

# 然后跑 wechattweak patch（只会 patch x86_64 entries）
./wechattweak patch
```

恢复时把备份覆盖回去，再 `codesign --force --deep --sign -` 重签。

---

## 锚点字符串备选清单

如果 `TryParseMessageX...revoke_climsgid` 这条合并 cstring 哪天被微信改了或拆了，可以用以下备选定位 revoke 函数：

| 字符串 | 备注 |
|---|---|
| `<?xml version="1.0"?>\n<sysmsg type=""><subtype>%d</subtype>` | sysmsg XML 模板，引用次数少 |
| `unknown subtype:` | revoke / sysmsg 解析的错误日志 |
| `content_template` | 撤回消息内容模板字段 |
| `revoke_climsgid` | 客户端 message_id（撤回目标） |

ARM64 切片里这些字符串常被合并存放，引用的代码用不同偏移指向同一基址，所以 References 通常会指向同一组函数。

---

## 风险评估

| 风险 | 概率 | 应对 |
|---|---|---|
| 字符串锚点失效（被改名/拆分） | 低 | 用备选锚点（见上节） |
| 微信改架构（sysmsg 处理移出 dylib） | 低 | 整个工作流重做，跟 fork 主线走 |
| 函数语义变（return 1 不再表示"已处理"） | 中 | 实测撤回是否还防得住；失效则需 patch 别的函数 |
| Apple 收紧代码签名 | 中 | resign 流程已修复过一次，后续可能还要改 |
| `codesign --force` 在更新 macOS 上行为变化 | 低 | 改 `Command.swift::resign` |

每次微信小版本升级，**只**需要重做步骤 1-8（约 30-60 分钟，主要等 Ghidra 分析）。代码层一般不用动。
