# WeChatTweak macOS x64 适配流程（仅 `config.json`）

这份文档给后续 macOS x64 版 `wx.app` 做防撤回和多开适配用，目标是稳定更新 [`config.json`](/Users/tanran/aiCode/patchWx/WeChatTweak/config.json)，不要再靠“旧签名大概像”去乱试。

## 1. 使用原则
- `config.json` 的 `version` 必须写 `CFBundleVersion`，不是展示版本号
- 先确认真实生效 App、真实运行进程、真实生效二进制
- 默认先对 `wechat.dylib` 做二进制特征搜索，优先不依赖 IDA 是否已经分析完成
- 只有命中不稳、同型块多处命中、需要确认控制流时，再回到 IDA 做最小静态定位；静态还不够稳时，再做 live 验证
- 每次从干净基线或可恢复状态出发，不继承历史误改残留
- 文档里只记录“已验证结论”和“已经踩过的坑”，不要写猜测

## 2. 适配前准备
### 2.1 确认目标版本
```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /Applications/wx.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' /Applications/wx.app/Contents/Info.plist
```

例如：
- 展示版本：`4.1.8`
- 配置版本：`36559`

### 2.2 确认真实运行目标
先确认当前跑的就是正式 App：
```bash
pgrep -fal '/Applications/wx.app/Contents/MacOS/WeChat'
```

然后确认目标逻辑到底在主程序还是 framework：
```bash
PID=$(pgrep -f '^/Applications/wx.app/Contents/MacOS/WeChat$')
vmmap "$PID" | grep 'wx.app/Contents/Frameworks/wechat.dylib'
```

当前 x64 已验证补丁目标是：
```text
/Applications/wx.app/Contents/Frameworks/wechat.dylib
```

因此 `config.json` 要显式写：
```json
"binary": "Contents/Frameworks/wechat.dylib"
```

本仓库已经支持按 `target.binary` 分组 patch：
- [`Command.swift`](/Users/tanran/aiCode/patchWx/WeChatTweak/Sources/WeChatTweak/Command.swift#L26)
- [`Config.swift`](/Users/tanran/aiCode/patchWx/WeChatTweak/Sources/WeChatTweak/Config.swift#L65)

如果不写 `binary`，默认会 patch `Contents/MacOS/WeChat`，这在当前 x64 版本上是错的。

### 2.3 重新验证前先清理历史误改
如果之前已经在正式 `/Applications/wx.app` 上试过错误点位，重新验证前最好先恢复干净状态。

`36559` 上曾误改过的 6 个 call-site，需要先恢复为原始 `call rel32`：
- `0x38B565E -> E82D1306FF`
- `0x3A80DD5 -> E8B65BE9FE`
- `0x3A95A6B -> E8200FE8FE`
- `0x3A95EEC -> E89F0AE8FE`
- `0x3A97054 -> E837F9E7FE`
- `0x3A97A9C -> E8EFEEE7FE`

否则你看到的现象可能是多轮试错叠加后的结果。

### 2.4 IDA 没加载完时不要卡住
刚打开 IDA 时，`lookup_funcs`、`xrefs`、`decompile`、`find_regex` 这类请求可能会因为 auto-analysis 还没完成而超时。

这时候不要为了“等 IDA 就绪”反复硬试；优先改成：
1. 先比对样本和正式 `/Applications/wx.app/Contents/Frameworks/wechat.dylib` 的 hash
2. 直接对磁盘里的 `wechat.dylib` 做二进制特征搜索
3. 命中唯一时，先生成临时配置并做最小 patch / live 验证
4. 只有命中多处、需要确认 `call rel32` 的真实目标、或要核对控制流语义时，再回 IDA

这条 x64 适配线后面默认按“**raw binary search first，IDA fallback**”走，不再把“先开好 IDA”当成前置条件。

## 3. 已验证基线
### `4.1.7 / 34817 / x86_64`
- `revoke`: `0x1049c295b -> 31C0909090`
- `multiInstance`: `0x1001dbbc0 -> B801000000C3`

语义：
- `31C0909090` = `xor eax, eax` 加 `nop`
- `B801000000C3` = `mov eax, 1; ret`

### `4.1.8 / 36559 / x86_64`
- `revoke`: `wechat.dylib@0x4B51260 -> B801000000C3`
- `multiInstance`: `wechat.dylib@0x21F008 -> 909090909090`

### `4.1.8 / 36603 / x86_64`
- `revoke`: `wechat.dylib@0x4B566A0 -> B801000000C3`
- `multiInstance`: `wechat.dylib@0x21F008 -> 909090909090`

### `4.1.8 / 36677 / x86_64`
- `revoke`: `wechat.dylib@0x4B870F0 -> B801000000C3`
- `multiInstance`: `wechat.dylib@0x21F008 -> 909090909090`

### `4.1.8 / 37293 / x86_64`
- `revoke`: `wechat.dylib@0x4C2B310 -> B801000000C3`
- `multiInstance`: `wechat.dylib@0x21EC38 -> 909090909090`

### `4.1.8 / 37303 / x86_64`
- `revoke`: `wechat.dylib@0x4C2CA90 -> B801000000C3`
- `multiInstance`: `wechat.dylib@0x21EC38 -> 909090909090`

### `4.1.8 / 37331 / x86_64`
- `revoke`: `wechat.dylib@0x4C31660 -> B801000000C3`
- `multiInstance`: `wechat.dylib@0x21EC38 -> 909090909090`

对应配置见：
- [`config.json`](/Users/tanran/aiCode/patchWx/WeChatTweak/config.json)

当前最重要的稳定经验：
- 新版 `revoke` 不要机械复用旧版 `xor eax, eax`
- 新版 `multiInstance` 也不要随便跳去 patch 新 helper；优先 patch 条件跳转本身
- `0x21F008` 在 `36559/36603/36677` 上都有效，但 `37293` 已经漂到 `0x21EC38`；旧 offset 只能当基线，不能当结论
- 这条线默认先做二进制特征搜索，再最小回到 IDA 确认；不要一开始就卡在 IDA auto-analysis

## 4. 通用适配流程
### 4.0 默认先做 raw binary search
这条 x64 适配线后面默认先走：
1. 确认正式 App 版本、真实 patch 目标、样本与 live 二进制 hash 一致
2. 直接对 `wechat.dylib` 做字节特征搜索
3. 命中后换算出真正的 patch VA
4. 只有控制流不清楚时，再回到 IDA 做最小确认

也就是说：
- **不是必须先开 IDA 才能适配**
- IDA 更适合做“命中后的确认”，不是每次都当第一步

### 4.1 防撤回先做静态定位
优先从最近一版已验证链路出发，而不是直接从 `34817` 跳。

当前稳定基线：
- `36559`：caller `0x4B51010`，parser `0x4B51260`
- `36603`：caller `0x4B56624`，parser `0x4B566A0`
- `36677`：caller `0x4B87074`，parser `0x4B870F0`
- `37293`：caller `0x4C2B294`，parser `0x4C2B310`
- `37303`：caller `0x4C2CA14`，parser `0x4C2CA90`
- `37331`：caller `0x4C315E4`，parser `0x4C31660`

优先直接搜索磁盘里的：
```text
/Applications/wx.app/Contents/Frameworks/wechat.dylib
```

推荐搜索顺序：
1. 先搜 `revokemsg` 相关字符串或直接搜 caller 特征
2. 如果 caller 特征唯一命中，先从 `call rel32` 算出 parser
3. 再看 parser 附近是否仍然存在 `revokemsg` / `sysmsg` / `type` 这类字符串初始化
4. 只有命中不稳时，再回 IDA 看 xref 和 caller 如何消费返回值

如果 `revokemsg` 这条线因为字符串池/xref 太散，一时收不拢，可以直接补一轮 caller 字节特征搜索：
```text
E8 ?? ?? ?? ?? 84 C0 74 ?? B0 01 80 7D C0 01
```
最近几版 x64 的 caller 都能先靠这条特征快速命中，再回头确认 parser。

这比单纯拿旧 offset 硬套稳得多。

### 4.2 防撤回再做 live 验证（仅静态不稳时）
如果静态分析还不够稳，再附加运行中的微信：
```bash
PID=$(pgrep -f '^/Applications/wx.app/Contents/MacOS/WeChat$')
lldb -p "$PID"
```

常用动作：
```lldb
breakpoint set --address <caller_va_plus_load_base>
breakpoint set --address <parse_func_va_plus_load_base>
continue
```

用户触发一次真实撤回后，重点看两件事：
1. live 命中的到底是不是你猜的函数
2. parse 函数返回 `0/1` 后，caller 分别走哪条分支

做单变量实验时，优先用：
```lldb
thread return 1
register read al
memory read --format x --size 1 --count 1 $rbp-0x40
```

只有把返回值语义搞清楚，才能决定最终 asm 应该是 `31C0909090` 还是 `B801000000C3`。

### 4.3 多开先做静态定位
多开这条线不要套用防撤回的找法，也不要直接从 `34817` 跳到新版。

当前 x64 的多开基线分两层看：
- `36559/36603/36677`：`wechat.dylib@0x21F008 -> 909090909090`
- `37293`：`wechat.dylib@0x21EC38 -> 909090909090`

静态定位时，先看旧 gate 还在不在；如果旧 gate 漂了，再按同型块去找，而不是先猜 helper 入口。

推荐做法：
1. 先看 `0x21F008` 这条旧 gate 还在不在
2. 如果不在，直接搜这条多开块特征：
```text
41 BE FF FF FF FF 84 DB 0F 84 ?? ?? ?? ?? E8 ?? ?? ?? ?? 48 89 C7
```
3. 确认命中块是不是“单实例失败就跳走，继续初始化就落下去”的条件跳转
4. 命中点一般是块起始，不是最终 patch 点；真正 patch 的通常是块内那条 `jz`
5. 只有块语义不清楚时，再回 IDA 看前后控制流；不要直接 patch 前后的 cleanup / helper / 中途落点

`36603/36677` 已验证可用的关键块是：
```text
0x21F000  mov  r14d, -1
0x21F006  test bl, bl
0x21F008  jz   loc_21FB21
0x21F00E  call sub_37B8250
```

`37293` 命中的新块是：
```text
0x21EC30  mov  r14d, -1
0x21EC36  test bl, bl
0x21EC38  jz   loc_21F751
0x21EC3E  call sub_3834550
```

这几版最终收敛的语义都一样：
```text
patch 条件跳转本身 -> 909090909090
```

也就是说，这条多开 patch 的语义不是“改返回值”，而是**直接去掉这条条件跳转**，让流程继续往下走。

### 4.4 多开再做 live 验证
多开 live 验证口径要固定：
```bash
open -a /Applications/wx.app
open -n /Applications/wx.app
pgrep -af '^/Applications/wx.app/Contents/MacOS/WeChat$'
```

判断标准不是“第二个进程出现过”，而是：
1. 首开后主进程数为 `1`
2. `open -n` 后主进程数稳定为 `2`
3. 两个主进程都能持续存活，不是闪退

如果第二实例闪一下就退：
1. 先看最新 `.ips`
2. 再回到 IDA 用崩溃偏移反推是不是 patch 到了错误的中间块
3. 不要先把中间 helper 改成 `ret`

### 4.5 更新 `config.json`
新增 `version = CFBundleVersion` 的条目。

通用格式：
```json
{
  "version": "<CFBundleVersion>",
  "targets": [
    {
      "identifier": "revoke",
      "entries": [
        { "arch": "x86_64", "addr": "<VA>", "asm": "<HEX>" }
      ],
      "binary": "Contents/Frameworks/wechat.dylib"
    },
    {
      "identifier": "multiInstance",
      "entries": [
        { "arch": "x86_64", "addr": "<VA>", "asm": "<HEX>" }
      ],
      "binary": "Contents/Frameworks/wechat.dylib"
    }
  ]
}
```

注意：
- `addr` 是十六进制字符串，不带 `0x`
- 如果逻辑在 framework 里，就必须写 `binary`
- 新版不要默认复用旧版 `asm`

### 4.6 不要把 `fileoff` 抄回 `config.json`
`wechattweak patch` 的输出同时会打印 `VA` 和 `fileoff`。

例如 `36603` 的真实输出：
```text
patch VA=0x4b566a0, fileoff=0x4b5a6a0
```

这里：
- `config.json` 应该写 `VA=0x4B566A0`
- `fileoff=0x4B5A6A0` 只是写入文件时算出来的偏移，不能抄回配置

## 5. 版本经验
### 5.1 `36559` 为什么这样收敛
`36559` 最初试过两类错误方法：
1. 直接拿旧版点位或旧签名硬搜
2. 把命中的 call-site 改成 `31C0909090`

这些点即使 patch 成功，也不能让防撤回真正生效，因为它们不是当前版本真正的 live 撤回处理链。

后面改成：
1. 先做静态定位
2. 再做一次真实撤回 live 验证
3. 确认 `wechat.dylib + 0x4B51260` 就是当前版本的 `revokemsg` XML 解析核心

这版最终结论：
```text
0x4B51260 -> B801000000C3
```

### 5.2 `36603` 和 `36559` 的差异
`36603` 本轮实测通过的结果：
- `revoke`: `wechat.dylib@0x4B566A0 -> B801000000C3`
- `multiInstance`: `wechat.dylib@0x21F008 -> 909090909090`

#### 撤回位差异
- 关键 caller 是 `0x4B56624`
- 被调函数入口是 `0x4B566A0`
- caller 的关键控制流是：
```text
call 0x4B566A0
test al, al
jz   loc_call_4B56635
mov  al, 1
cmp  byte ptr [rbp-0x40], 1
jnz  loc_return
loc_call_4B56635:
call 0x4B57AE0
```

所以这版 `revoke` 仍按“直接返回 1”收敛，而不是复用旧版 `xor eax,eax`。

#### 多开位差异
- `36603` 继续沿用 `0x21F008 -> 909090909090`
- `0x21EFF0 -> 31C0C3` 这条结论是错的，不要再用
- `0x21EFF0` 落在函数体中段，误 patch 后第二实例可能短暂起来又崩

#### 最终验证口径
- `multiInstance`：已 live 验证通过，`open -n` 后双实例稳定存活
- `revoke`：已由用户真实撤回测试确认可用

### 5.3 `36677` 快速适配结果
这版先按 `36603` 的基线快速比对：
- `multiInstance`：`0x21F008` 关键块仍然保持不变
- `revoke`：caller / parser 整体前移到新的同型链

#### 多开线
`36677` 里继续可以看到：
```text
0x21F000  mov  r14d, -1
0x21F006  test bl, bl
0x21F008  jz   loc_21FB21
0x21F00E  call sub_37D4A10
```

所以多开继续收敛成：
```text
wechat.dylib@0x21F008 -> 909090909090
```

这轮已 live 验证：
- 首开后主进程数为 `1`
- `open -n /Applications/wx.app` 后主进程数稳定为 `2`
- 两个主进程持续存活

#### 撤回线
`36677` 命中的新 caller / parser 是：
- caller：`0x4B87074`
- parser：`0x4B870F0`

caller 关键控制流：
```text
call 0x4B870F0
test al, al
jz   loc_4B87085
mov  al, 1
cmp  byte ptr [rbp-0x40], 1
jnz  loc_4B87090
loc_4B87085:
call 0x4B88530
```

parser 开头继续按 `sysmsg/type/...` 这套 XML 键解析，和 `36559/36603` 属于同型链。

因此这轮快速适配先收敛成：
```text
wechat.dylib@0x4B870F0 -> B801000000C3
```

这次 `patch` 的真实输出是：
```text
patch VA=0x4b870f0, fileoff=0x4b8b0f0
```

注意：
- `config.json` 要写 `VA=0x4B870F0`
- 不能把 `fileoff=0x4B8B0F0` 抄回配置

当前验证状态要单独写清楚：
- `multiInstance`：已 live 验证通过
- `revoke`：已由用户真实撤回测试确认可用

这次 `36677` 的关键经验：
- 多开线没有继续漂移，`0x21F008` 这条稳定 gate 仍然有效；先复核这条 gate，比先追新 helper 更快
- 撤回线整体仍是同型链：caller / parser 成对前移，但 parser 仍然沿 `sysmsg/type/...` 这套 XML 键解析
- `patch` 输出里的 `fileoff=0x4B8B0F0` 不能抄回配置；`config.json` 里必须写 `VA=0x4B870F0`
- 这版最终状态是：`multiInstance` 与 `revoke` 都已经过真实验证，可以作为下个版本的直接对照基线


### 5.4 `37293` 快速适配结果
这版和 `36677` 相比，撤回线仍然是同型 caller / parser，但多开 gate 已经不再停在 `0x21F008`。

#### 多开线
这次先按旧基线检查 `0x21F008`，确认那条 gate 已经漂移；随后用多开块特征：
```text
41 BE FF FF FF FF 84 DB 0F 84 ?? ?? ?? ?? E8 ?? ?? ?? ?? 48 89 C7
```
命中新块：
```text
0x21EC30  mov  r14d, -1
0x21EC36  test bl, bl
0x21EC38  jz   loc_21F751
0x21EC3E  call sub_3834550
```

所以这版多开收敛成：
```text
wechat.dylib@0x21EC38 -> 909090909090
```

这轮 live 验证结果：
- 首开后主进程数为 `1`
- `open -n /Applications/wx.app` 后主进程数稳定为 `2`
- 两个主进程持续存活

#### 撤回线
这次继续可以用最近几版的 caller 特征快速收敛：
```text
E8 ?? ?? ?? ?? 84 C0 74 ?? B0 01 80 7D C0 01
```

命中的 caller / parser 是：
- caller：`0x4C2B294`
- parser：`0x4C2B310`

caller 关键控制流：
```text
call 0x4C2B310
test al, al
jz   loc_4C2B2A5
mov  al, 1
cmp  byte ptr [rbp-0x40], 1
jnz  loc_4C2B2B0
loc_4C2B2A5:
call 0x4C2C750
```

parser 内部仍能看到 `revokemsg` 相关字符串初始化，因此这版仍按“parser 直接返回 1”收敛：
```text
wechat.dylib@0x4C2B310 -> B801000000C3
```

这次 `patch` 的真实输出是：
```text
patch VA=0x4c2b310, fileoff=0x4c2f310
patch VA=0x21ec38, fileoff=0x222c38
```

注意：
- `config.json` 要写 `VA=0x4C2B310` 和 `VA=0x21EC38`
- 不能把 `fileoff=0x4C2F310` / `0x222C38` 抄回配置

当前验证状态：
- `multiInstance`：已 live 验证通过
- `revoke`：已由用户真实撤回测试确认可用

这次 `37293` 的关键经验：
- `0x21F008` 虽然连续三版都有效，但已经不是永久稳定点；多开线要优先记“条件跳转块形态”，不要只记旧 offset
- 撤回线仍然是同型 caller / parser；当 `revokemsg` 字符串线索太散时，可以先用 caller 特征搜到新链
- `patch` 输出里的 `fileoff` 只用于核对落盘，不要回写到 `config.json`

### 5.5 `37303` 快速适配结果
这版相对 `37293` 的变化很小：多开 gate 没再漂，撤回链整体继续前移。

这次最重要的流程结论不是“又找到一个新 offset”，而是：
- 一开始 IDA 请求超时，不代表样本不对，更可能是 auto-analysis 还没完成
- 这时继续等 IDA 没意义，直接做 raw binary search 更快
- 这条线后面可以默认不把“先开 IDA”当成硬前置

#### 多开线
多开块特征继续命中：
```text
41 BE FF FF FF FF 84 DB 0F 84 ?? ?? ?? ?? E8 ?? ?? ?? ?? 48 89 C7
```

命中块仍然是：
```text
0x21EC30  mov  r14d, -1
0x21EC36  test bl, bl
0x21EC38  jz   loc_21F751
```

所以这版多开继续沿用：
```text
wechat.dylib@0x21EC38 -> 909090909090
```

这轮 live 验证结果：
- 首开后主进程数为 `1`
- `open -n /Applications/wx.app` 后主进程数稳定为 `2`
- 两个主进程持续存活

#### 撤回线
这次直接先搜 caller 特征：
```text
E8 ?? ?? ?? ?? 84 C0 74 ?? B0 01 80 7D C0 01
```

命中的 caller / parser 是：
- caller：`0x4C2CA14`
- parser：`0x4C2CA90`

caller 关键控制流：
```text
call 0x4C2CA90
test al, al
jz   loc_4C2CA26
mov  al, 1
cmp  byte ptr [rbp-0x40], 1
```

parser 附近继续能看到 `revokemsg` 初始化，因此这版仍按“parser 直接返回 1”收敛：
```text
wechat.dylib@0x4C2CA90 -> B801000000C3
```

这次 `patch` 的真实输出是：
```text
patch VA=0x4c2ca90, fileoff=0x4c30a90
patch VA=0x21ec38, fileoff=0x222c38
```

注意：
- `config.json` 要写 `VA=0x4C2CA90` 和 `VA=0x21EC38`
- 不能把 `fileoff=0x4C30A90` / `0x222C38` 抄回配置

当前验证状态：
- `multiInstance`：已 live 验证通过
- `revoke`：已由用户真实撤回测试确认可用

这次 `37303` 的关键经验：
- IDA 超时时，优先怀疑“还没分析完”，不要默认怀疑样本不对
- caller / multi block 这两条字节特征已经足够支撑首轮快速适配
- 这条线以后默认先 raw binary search，再最小回到 IDA 确认

### 5.6 `37331` 快速适配结果
这版可以完全靠 raw binary search 快速收敛，不需要先等 IDA 分析完成。

这次先确认了：
- `/Users/tanran/Downloads/wx/wechat.dylib`
- `/Applications/wx.app/Contents/Frameworks/wechat.dylib`

两者 hash 一致，因此可以直接把下载目录里的样本当作 live 二进制来适配。

另外这版在二进制里可以直接搜到：
```text
4.1.8.105
```

正式 App 的版本号是：
- `CFBundleVersion = 37331`
- `CFBundleShortVersionString = 4.1.8`

#### 多开线
多开块特征继续命中：
```text
41 BE FF FF FF FF 84 DB 0F 84 ?? ?? ?? ?? E8 ?? ?? ?? ?? 48 89 C7
```

命中块仍然是：
```text
0x21EC30  mov  r14d, -1
0x21EC36  test bl, bl
0x21EC38  jz   loc_21F751
```

所以这版多开继续沿用：
```text
wechat.dylib@0x21EC38 -> 909090909090
```

这轮 live 验证结果：
- 首开后主进程数为 `1`
- `open -n /Applications/wx.app` 后主进程数稳定为 `2`
- 两个主进程持续存活

#### 撤回线
这次直接先搜 caller 特征：
```text
E8 ?? ?? ?? ?? 84 C0 74 ?? B0 01 80 7D C0 01
```

命中的 caller / parser 是：
- caller：`0x4C315E4`
- parser：`0x4C31660`

caller 关键控制流：
```text
call 0x4C31660
test al, al
jz   loc_4C315F5
mov  al, 1
cmp  byte ptr [rbp-0x40], 1
```

parser 附近继续能看到 `revokemsg` 初始化，因此这版仍按“parser 直接返回 1”收敛：
```text
wechat.dylib@0x4C31660 -> B801000000C3
```

这次 `patch` 的真实输出是：
```text
patch VA=0x4c31660, fileoff=0x4c35660
patch VA=0x21ec38, fileoff=0x222c38
```

注意：
- `config.json` 要写 `VA=0x4C31660` 和 `VA=0x21EC38`
- 不能把 `fileoff=0x4C35660` / `0x222C38` 抄回配置

当前验证状态：
- `multiInstance`：已 live 验证通过
- `revoke`：已由用户真实撤回测试确认可用

这次 `37331` 的关键经验：
- 对已知同型链做快速适配时，先比 hash，再直接搜样本二进制，比先等 IDA 更快
- 多开线到这版仍然没有再漂，`0x21EC38` 可以继续作为当前短期基线
- 撤回线继续按 caller 特征先命中，再由 `call rel32` 算 parser，最后用 `revokemsg` 初始化做二次确认

## 6. 当前已验证配置
`36559` 的当前写法：
```json
{
  "version": "36559",
  "targets": [
    {
      "identifier": "revoke",
      "entries": [
        { "arch": "x86_64", "addr": "4B51260", "asm": "B801000000C3" }
      ],
      "binary": "Contents/Frameworks/wechat.dylib"
    },
    {
      "identifier": "multiInstance",
      "entries": [
        { "arch": "x86_64", "addr": "21F008", "asm": "909090909090" }
      ],
      "binary": "Contents/Frameworks/wechat.dylib"
    }
  ]
}
```

`36603` 的当前写法：
```json
{
  "version": "36603",
  "targets": [
    {
      "identifier": "revoke",
      "entries": [
        { "arch": "x86_64", "addr": "4B566A0", "asm": "B801000000C3" }
      ],
      "binary": "Contents/Frameworks/wechat.dylib"
    },
    {
      "identifier": "multiInstance",
      "entries": [
        { "arch": "x86_64", "addr": "21F008", "asm": "909090909090" }
      ],
      "binary": "Contents/Frameworks/wechat.dylib"
    }
  ]
}
```

`36677` 的当前快速适配写法：
```json
{
  "version": "36677",
  "targets": [
    {
      "identifier": "revoke",
      "entries": [
        { "arch": "x86_64", "addr": "4B870F0", "asm": "B801000000C3" }
      ],
      "binary": "Contents/Frameworks/wechat.dylib"
    },
    {
      "identifier": "multiInstance",
      "entries": [
        { "arch": "x86_64", "addr": "21F008", "asm": "909090909090" }
      ],
      "binary": "Contents/Frameworks/wechat.dylib"
    }
  ]
}
```

`37293` 的当前快速适配写法：
```json
{
  "version": "37293",
  "targets": [
    {
      "identifier": "revoke",
      "entries": [
        { "arch": "x86_64", "addr": "4C2B310", "asm": "B801000000C3" }
      ],
      "binary": "Contents/Frameworks/wechat.dylib"
    },
    {
      "identifier": "multiInstance",
      "entries": [
        { "arch": "x86_64", "addr": "21EC38", "asm": "909090909090" }
      ],
      "binary": "Contents/Frameworks/wechat.dylib"
    }
  ]
}
```

`37303` 的当前快速适配写法：
```json
{
  "version": "37303",
  "targets": [
    {
      "identifier": "revoke",
      "entries": [
        { "arch": "x86_64", "addr": "4C2CA90", "asm": "B801000000C3" }
      ],
      "binary": "Contents/Frameworks/wechat.dylib"
    },
    {
      "identifier": "multiInstance",
      "entries": [
        { "arch": "x86_64", "addr": "21EC38", "asm": "909090909090" }
      ],
      "binary": "Contents/Frameworks/wechat.dylib"
    }
  ]
}
```

`37331` 的当前快速适配写法：
```json
{
  "version": "37331",
  "targets": [
    {
      "identifier": "revoke",
      "entries": [
        { "arch": "x86_64", "addr": "4C31660", "asm": "B801000000C3" }
      ],
      "binary": "Contents/Frameworks/wechat.dylib"
    },
    {
      "identifier": "multiInstance",
      "entries": [
        { "arch": "x86_64", "addr": "21EC38", "asm": "909090909090" }
      ],
      "binary": "Contents/Frameworks/wechat.dylib"
    }
  ]
}
```

## 7. 回写前检查清单
- `version` 是否是 `CFBundleVersion`
- `binary` 是否指向 `Contents/Frameworks/wechat.dylib`
- `addr` 写的是不是 `VA`，不是 `fileoff`
- `revoke` 有没有至少完成一次静态链路确认
- `multiInstance` 有没有按“双实例稳定存活”口径验过
- 文档里有没有残留“这次已经证伪”的旧结论
