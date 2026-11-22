# 生活账 · 原生 iOS 版

账本 / 预约 / 日程 / 随手记，数据存在 App 沙盒的 `Documents/lifehub.json`。
支持 iOS 原生能力：**背敲三下触发快捷指令 → 截屏 → OCR → 直接把文字传进 App**，以及系统日历写入 + 本地通知提醒。

---

## 一、先搞清楚安装链路

没有 Mac 也能装，但要接受两件事：

1. **编译**：用 GitHub Actions 的免费 macOS 云主机编译出未签名 IPA（仓库代码是公开的就能免费用）。
2. **签名安装**：在 Windows 上用 **Sideloadly**（免费）连数据线，用你自己的 Apple ID 签名装到手机。免费签名 **7 天到期**，每周重签一次（Sideloadly 有 Re-sign / Refresh 选项，重签不丢数据）。不想每周折腾就买 $99/年开发者账号走 TestFlight，签名 90 天有效。

---

## 二、编译 IPA

1. 注册 GitHub，新建一个 **Public** 仓库（比如 `lifehub-ios`）。
2. 把本目录 `life-hub-native/` 里的**所有文件**（含 `.github` 文件夹）上传到仓库根目录。
3. 仓库页面点 **Actions** → 左侧选 `Build unsigned IPA` → **Run workflow** → 绿色按钮运行。
4. 等 3～8 分钟，跑完后点进这次运行，在最下面 **Artifacts** 下载 `LifeHub-unsigned-ipa`，解压得到 `LifeHub-unsigned.ipa`。

> 以后改了 Swift 代码，只要重新上传文件，再跑一次 workflow 就有新 IPA。

---

## 三、Windows 上签名并安装

1. 下载安装 [Sideloadly](https://sideloadly.io/)（Windows 版）。
2. iPhone 用数据线连电脑，手机上点「信任此电脑」。
3. Sideloadly 里：
   - 拖入 `LifeHub-unsigned.ipa`
   - 填你的 Apple ID 邮箱
   - 密码栏填 **App 专用密码**（在 [appleid.apple.com](https://appleid.apple.com) 登录 → 安全 → 生成 App 专用密码，不是 Apple ID 登录密码）
   - 选中你的 iPhone，点 **Start**
4. 第一次签名前，手机上如果出现「无法验证 App」，去 **设置 → 通用 → VPN与设备管理 → 开发者 App → 信任**。
5. 7 天后打开 Sideloadly，选同一 IPA 点 **Re-sign / Refresh**，数据不会丢。

---

## 四、创建「背敲三下 → 截图识别」快捷指令

在 iPhone 的「快捷指令」App 里新建快捷指令，依次添加这些操作：

| 顺序 | 操作 | 设置 |
|---|---|---|
| 1 | **截屏** | 无需设置（会立刻截一张当前画面） |
| 2 | **从图像中提取文本** | 输入接第 1 步的截图 |
| 3 | **URL 编码** | 输入接第 2 步的文字 |
| 4 | **打开 URL** | `lifehub://capture?text=` 后面接第 3 步的输出（点输入框 → 魔法变量 → 选第 3 步结果） |

保存，命名比如「记账截图识别」。

然后去 **设置 → 辅助功能 → 触控 → 轻点背面 → 轻点三下 → 选这个快捷指令**。

用法：看到挂号成功页 / 机票订单 / 消费通知 → **背敲三下手机** → OCR 文字自动传进生活账 → App 弹出表单（日期、时间、金额、类型都填好了）→ 核对点保存。

> 想少一步：先截屏再背敲三下。快捷指令里的「截屏」操作也可以换成「查找照片 → 媒体类型=截屏 → 排序=最新 → 限制 1」，这样用的是你刚截的那张。

---

## 五、代码结构

- `Sources/LifeHubApp.swift` — App 入口，接收 `lifehub://capture?text=…`
- `Sources/Parser.swift` — 从文字里识别日期、时间、金额、类型（和网页版同一套规则）
- `Sources/Models.swift` — 数据模型 + JSON 本地存储
- `Sources/AddRecordView.swift` — 新增/确认表单
- `Sources/ContentView.swift` — 五个页面 + 导入导出备份
- `Sources/Reminders.swift` — 系统日历事件（提前 15 分钟）+ 本地通知
- `project.yml` — XcodeGen 配置，含 URL Scheme `lifehub` 和权限描述
- `.github/workflows/build-ipa.yml` — 云编译脚本

---

## 六、注意

- 首次新增预约/日程会弹权限请求：日历和通知都要允许，否则提醒不生效。
- 提醒同时走两条路：系统日历事件 + 本地通知，其中日历最可靠。
- 数据只在手机本地，用顶部工具栏的上传/下载按钮做 JSON 备份。
- 没有 Mac 就没法本地调试 Swift；改代码后直接推 GitHub 看 Actions 报错信息来修。
