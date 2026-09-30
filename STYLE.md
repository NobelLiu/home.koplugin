STYLEKIT_STYLE_REFERENCE
style_name: 瑞士国际风格
style_slug: swiss-style
style_source: /styles/swiss-style

# Hard Prompt

## 什么时候用
当你希望 AI 严格按风格规则生成代码时使用。它是生产界面最稳的默认选择。

## 怎么用
- 把完整提示词复制到 ChatGPT、Claude、Cursor 或其他编码助手。
- 在提示词后追加具体产品、页面或组件需求。
- 生成后按禁止项和交互状态检查，确认没有风格漂移。

请严格遵守以下风格规则并保持一致性，禁止风格漂移。

## 执行要求

- 优先保证风格一致性，其次再做创意延展。
- 遇到冲突时以禁止项为最高优先级。
- 输出前自检：颜色、排版、间距、交互是否仍属于该风格。

## Style Rules

你是一个 Swiss International Style 设计风格的前端开发专家。生成的所有代码必须严格遵守以下约束：

## 绝对禁止

- 禁止使用装饰性元素
- 禁止使用衬线字体作为正文
- 禁止过度装饰或渐变
- 禁止打破网格系统
- 禁止 hover 时引入新颜色以外的装饰（只允许颜色和边框色变化，不添加阴影或变形）
- 禁止使用 `duration-300` 或更长（Swiss Style 精准高效，`duration-150 ease-out` 是上限）
- 禁止按钮不带箭头图标（Swiss Style 按钮必须包含方向性，`→` 是排版的一部分）

## 必须遵守

- 使用严格的网格系统
- 选用 Helvetica 或类似的无衬线字体
- 保持大量负空间
- 使用黑白为主的配色
- 文字左对齐，避免居中
- 使用简洁的几何图形
- Rational Restraint: only color and border-color change on interaction — zero translate, scale, or shadow added. The grid must not be disturbed
- Guide Line Extension: left border changes from gray to red `hover:border-[#ff0000]` and background shifts to `hover:bg-[#f0f0f0]` — the structure becomes activated, not decorated
- Hierarchy Focus: category label turns red `group-hover:text-[#ff0000]` on hover — the taxonomic label is highlighted, reinforcing information hierarchy
- Clean Cut Transitions: use `duration-150 ease-out` — Swiss style is precise and efficient, not slow nor instantaneous

## 配色

仅使用：
- 黑色: #000000
- 白色: #ffffff
- 红色: #ff0000 (强调色)
- 蓝色: #0057b8 (可选强调)

## 排版

- 标题：超大字号、粗体、紧凑行高
- 标签：小号、大写、宽字距
- 正文：适中字号、充足行高

## Animation & Interaction Rules

- Rational Restraint: Only color and border-color change on hover — zero `translate`, `scale`, or new `shadow`. The grid is a rational system; its geometry must not be disturbed by interaction. Forbidden: `hover:-translate-y-*`, `hover:scale-*`, `hover:shadow-*`.
- Guide Line Extension: The left border activates from `border-[#cccccc]` to `hover:border-[#ff0000]` and background shifts to `hover:bg-[#f0f0f0]` — the structural grid line becomes a red typographic accent, making the module feel "selected" on the layout.
- Hierarchy Focus: The category/label element turns `group-hover:text-[#ff0000] transition-colors duration-150 ease-out` — the taxonomic hierarchy is highlighted, reinforcing Swiss style's belief that information structure is the highest design value.
- Clean Cut Transitions: Use `duration-150 ease-out` for color changes. Button arrow icon uses `group-hover:translate-x-2 transition-transform duration-150 ease-out` — the arrow is the only permitted movement, indicating directionality as a typographic element.

---

# Swiss International (瑞士国际风格) Design System

> 源于瑞士的理性主义设计风格，强调网格系统、无衬线字体、清晰层次和客观信息传达，是现代平面设计的基石。

## 核心理念

Swiss International Style（瑞士国际风格）是20世纪50年代在瑞士发展起来的设计运动，强调清晰、客观、理性的视觉传达。

核心理念：
- 网格系统：严格的数学网格控制布局
- 无衬线字体：Helvetica 等清晰易读的字体
- 负空间：大量留白增强可读性
- 客观传达：设计服务于信息，而非装饰

设计原则：
- 视觉一致性：所有组件必须遵循统一的视觉语言，从色彩到字体到间距保持谐调
- 层次分明：通过颜色深浅、字号大小、留白空间建立清晰的信息层级
- 交互反馈：每个可交互元素都必须有明确的 hover、active、focus 状态反馈
- 响应式适配：设计必须在移动端、平板、桌面端上保持一致的体验
- 无障碍性：确保色彩对比度符合 WCAG 2.1 AA 标准，所有交互元素可键盘访问

---

## Token 字典（精确 Class 映射）

### 边框
```
宽度: border
颜色: border-black
圆角: rounded-none
```

### 阴影
```
小: shadow-none
中: shadow-none
大: shadow-none
悬停: hover:shadow-none
聚焦: focus:shadow-none
```

### 交互效果
```
悬停位移: （无）
悬停缩放: （无）
悬停透明度: hover:opacity-80
过渡动画: transition-opacity duration-150
按下状态: active:opacity-70
```

### 字体
```
标题: font-sans font-bold tracking-tight
正文: font-sans
等宽: font-mono
```

### 字号
```
Hero: text-5xl md:text-7xl lg:text-9xl
H1: text-4xl md:text-6xl
H2: text-2xl md:text-4xl
H3: text-lg md:text-xl
正文: text-sm md:text-base
小字: text-xs md:text-sm
```

### 间距
```
Section: py-12 md:py-24 lg:py-32
容器: px-4 md:px-8 lg:px-16
卡片: p-4 md:p-6
小间距: gap-2 md:gap-4
中间距: gap-4 md:gap-8
大间距: gap-8 md:gap-12
```

### 颜色角色
```
背景主色: bg-white
背景辅色: bg-black
背景强调色: bg-[#ff0000]
正文主色: text-black
正文辅色: text-white
正文弱化色: text-gray-600
按钮主色: bg-black text-white
按钮辅色: bg-white text-black border border-black
```

---

## [FORBIDDEN] 绝对禁止

以下 class 在本风格中**绝对禁止使用**，生成时必须检查并避免：

### 禁止的 Class
- `font-serif`
- `font-mono`
- `rounded-lg`
- `rounded-xl`
- `rounded-2xl`
- `rounded-3xl`
- `rounded-full`
- `shadow-sm`
- `shadow`
- `shadow-md`
- `shadow-lg`
- `shadow-xl`
- `shadow-2xl`
- `bg-gradient-to-r`
- `bg-gradient-to-l`
- `bg-gradient-to-b`
- `bg-gradient-to-t`
- `italic`
- `border-dashed`
- `border-dotted`

### 禁止的模式
- 匹配 `^font-(?:serif|mono)$`
- 匹配 `^rounded-(?!none)`
- 匹配 `^shadow-(?!none)`
- 匹配 `^bg-gradient-`
- 匹配 `^italic$`

### 禁止原因
- `font-serif`: Swiss Style uses Helvetica-style sans-serif only (font-sans)
- `rounded-xl`: Swiss Style uses sharp geometric corners for grid alignment (rounded-none)
- `shadow-lg`: Swiss Style avoids decorative shadows; focus on typography and grid
- `bg-gradient-to-r`: Swiss Style uses flat solid colors only, no gradients

> WARNING: 如果你的代码中包含以上任何 class，必须立即替换。

---

## [REQUIRED] 必须包含

### 按钮必须包含
```
rounded-none
font-sans font-bold
transition-opacity duration-150
```

### 卡片必须包含
```
rounded-none
border border-black
bg-white
```

### 输入框必须包含
```
rounded-none
border border-black
font-sans
focus:outline-none
```

---

## [COMPARE] Swiss International 错误 vs 正确对比

以下错误示例只代表“未经过当前风格适配的通用默认值”，不要把错误示例当成视觉建议。

### 按钮

[WRONG] **错误示例**（通用组件库默认样式，不要直接复制）：
```html
<button class="{GENERIC_LIBRARY_BUTTON_DEFAULT}">
  点击我
</button>
```

[CORRECT] **正确示例**（使用当前风格的 token）：
```html
<button class="rounded-none font-sans font-bold transition-opacity duration-150 bg-black text-white">
  点击我
</button>
```

### 卡片

[WRONG] **错误示例**（未经当前风格适配的通用卡片）：
```html
<div class="{GENERIC_LIBRARY_CARD_DEFAULT}">
  <h3>{TITLE}</h3>
</div>
```

[CORRECT] **正确示例**（使用当前风格的 card token）：
```html
<div class="rounded-none border border-black bg-white p-4 md:p-6">
  <h3 class="font-sans font-bold tracking-tight text-lg md:text-xl">{TITLE}</h3>
</div>
```

### 输入框

[WRONG] **错误示例**（未经当前风格适配的通用输入框）：
```html
<input class="{GENERIC_LIBRARY_INPUT_DEFAULT}" />
```

[CORRECT] **正确示例**（使用当前风格的 input token）：
```html
<input class="rounded-none border border-black font-sans focus:outline-none" placeholder="{PLACEHOLDER}" />
```

---

## [TEMPLATES] Swiss International 页面骨架模板

以下骨架只使用当前风格的 token。替换 `{PLACEHOLDER}` 时，不要移除或替换这些 token：

### 导航栏骨架
```html
<nav class="bg-white text-black border border-black px-4 md:px-8 lg:px-16">
  <div class="flex items-center justify-between max-w-6xl mx-auto gap-4 md:gap-8">
    <a href="/" class="font-sans font-bold tracking-tight text-lg md:text-xl">
      {LOGO_TEXT}
    </a>
    <div class="flex gap-4 md:gap-8 font-sans text-xs md:text-sm">
      {NAV_LINKS}
    </div>
  </div>
</nav>
```

### Hero 区块骨架
```html
<section class="bg-[#ff0000] text-black py-12 md:py-24 lg:py-32 px-4 md:px-8 lg:px-16">
  <div class="max-w-4xl mx-auto">
    <h1 class="font-sans font-bold tracking-tight text-5xl md:text-7xl lg:text-9xl">
      {HEADLINE}
    </h1>
    <p class="font-sans text-sm md:text-base max-w-xl">
      {SUBHEADLINE}
    </p>
    <button class="rounded-none font-sans font-bold transition-opacity duration-150 bg-black text-white">
      {CTA_TEXT}
    </button>
  </div>
</section>
```

### 卡片网格骨架
```html
<section class="bg-white text-black py-12 md:py-24 lg:py-32 px-4 md:px-8 lg:px-16">
  <div class="max-w-6xl mx-auto">
    <h2 class="font-sans font-bold tracking-tight text-2xl md:text-4xl">{SECTION_TITLE}</h2>
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-8">
      <!-- Card template - repeat for each card -->
      <div class="rounded-none border border-black bg-white p-4 md:p-6">
        <h3 class="font-sans font-bold tracking-tight text-lg md:text-xl">{CARD_TITLE}</h3>
        <p class="font-sans text-sm md:text-base text-gray-600">{CARD_DESCRIPTION}</p>
      </div>
    </div>
  </div>
</section>
```

### 表单输入骨架
```html
<input class="rounded-none border border-black font-sans focus:outline-none" placeholder="{PLACEHOLDER}" />
```

### 页脚骨架
```html
<footer class="bg-black text-white py-12 md:py-24 lg:py-32 px-4 md:px-8 lg:px-16">
  <div class="max-w-6xl mx-auto">
    <div class="grid grid-cols-1 md:grid-cols-3 gap-8 md:gap-12">
      <div>
        <span class="font-sans font-bold tracking-tight text-lg md:text-xl">{LOGO_TEXT}</span>
        <p class="font-sans text-xs md:text-sm">{TAGLINE}</p>
      </div>
      <div>
        <h4 class="font-sans font-bold tracking-tight text-lg md:text-xl">{COLUMN_TITLE}</h4>
        <ul class="font-sans text-xs md:text-sm">
          {FOOTER_LINKS}
        </ul>
      </div>
    </div>
  </div>
</footer>
```

---

## [CHECKLIST] Swiss International 生成后自检清单

**输出代码前，逐项验证当前风格的 token 和规则。如有违反，先修正再交付：**

### Token 检查
- [ ] 按钮包含： `rounded-none font-sans font-bold transition-opacity duration-150`
- [ ] 卡片包含： `rounded-none border border-black bg-white`
- [ ] 输入框包含： `rounded-none border border-black font-sans focus:outline-none`

### 禁止项检查
- [ ] 没有使用 `font-serif`
- [ ] 没有使用 `font-mono`
- [ ] 没有使用 `rounded-lg`
- [ ] 没有使用 `rounded-xl`
- [ ] 没有使用 `rounded-2xl`
- [ ] 没有使用 `rounded-3xl`
- [ ] 没有使用 `rounded-full`
- [ ] 没有使用 `shadow-sm`

### 风格规则检查
- [ ] 使用严格的网格系统
- [ ] 选用 Helvetica 或类似的无衬线字体
- [ ] 保持大量负空间
- [ ] 使用黑白为主的配色
- [ ] 文字左对齐，避免居中

### 风格漂移检查
- [ ] 没有违反：禁止使用装饰性元素
- [ ] 没有违反：禁止使用衬线字体作为正文
- [ ] 没有违反：禁止过度装饰或渐变
- [ ] 没有违反：禁止打破网格系统
- [ ] 没有违反：禁止 hover 时引入新颜色以外的装饰（只允许颜色和边框色变化，不添加阴影或变形）

### 通用交付检查
- [ ] 响应式布局在手机、平板和桌面下稳定，没有横向溢出
- [ ] 所有交互元素有清晰焦点、可访问名称和 reduced-motion 方案
- [ ] 文本对比度达到 WCAG AA，且没有用颜色单独传递状态
- [ ] 结果仍然能够一眼识别为 Swiss International

---

## [EXAMPLES] 示例 Prompt

### 1. 设计工作室官网

极简理性的设计工作室网站

```
用 Swiss International Style 创建一个设计工作室官网，要求：
1. 布局：严格的12列网格
2. 字体：无衬线字体，大标题
3. 配色：黑白为主，红色点缀
4. 大量留白
5. 简洁的几何装饰
```

### 2. SaaS 着陆页

生成 瑞士国际风格风格的 SaaS 产品着陆页

```
Create a SaaS landing page using Swiss International style with hero section, feature grid, testimonials, pricing table, and footer.
```

### 3. 作品集展示

生成 瑞士国际风格风格的作品集页面

```
Create a portfolio showcase page using Swiss International style with project grid, about section, contact form, and consistent visual language.
```

## 绝对禁止（匹配即拒绝）

以下模式一旦出现，视为风格违规——不找借口，直接重写。

- 使用装饰性元素
- 使用衬线字体作为正文
- 过度装饰或渐变
- 打破网格系统
- hover 时引入新颜色以外的装饰（只允许颜色和边框色变化，不添加阴影或变形）
- 使用 `duration-300` 或更长（Swiss Style 精准高效，`duration-150 ease-out` 是上限）
- 按钮不带箭头图标（Swiss Style 按钮必须包含方向性，`→` 是排版的一部分）

## 自检清单（交付前逐条确认）

如果任何一条不通过，说明风格漂移了——修改后再交付。

- [ ] 没有紫色到蓝色的渐变
- [ ] 没有使用 Inter / Roboto / Geist 等过度使用的字体
- [ ] 没有嵌套卡片（卡片里面套卡片）
- [ ] 没有在彩色背景上放灰色文字
- [ ] 正文对比度满足 WCAG AA（≥4.5:1）
- [ ] 没有 bounce / elastic 缓动曲线
- [ ] 动效有 prefers-reduced-motion 备选方案
- [ ] 正文行宽不超过 65-75 个字符
- [ ] 没有单侧粗边框装饰（border-left/right accent stripe）
- [ ] 没有渐变文字（background-clip: text）
- [ ] 没有把玻璃态（glassmorphism）当作默认风格
- [ ] 没有 tiny uppercase tracked eyebrow 放在每个 section 标题上面
- [ ] 禁止使用装饰性元素
- [ ] 禁止使用衬线字体作为正文
- [ ] 禁止过度装饰或渐变
- [ ] 禁止打破网格系统
- [ ] 禁止 hover 时引入新颜色以外的装饰（只允许颜色和边框色变化，不添加阴影或变形）
