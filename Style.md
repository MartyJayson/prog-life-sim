# OS Style — "Luna Pop"

The shared visual language of the in-game operating system. It is based on Windows XP (Luna) and Windows 7: blue title bars, light panels, rounded cards with drop shadows. Colours are a little more saturated than the originals, with warm orange accents.

The source of truth is the theme [`assets/generated/os_theme.tres`](assets/generated/os_theme.tres). Scenes do not set their own colours; they use the theme's **type variations** (`theme_type_variation`). The reference component is the notification [`scenes/notification_toast.tscn`](scenes/notification_toast.tscn).

> Sites inside the browser (`scenes/web/*`: bank, casino, etc.) are "third-party" web pages. They have their own themes and do not follow this style.

---

## 1. Palette

| Role | Colour | HEX | Used for |
|---|---|---|---|
| **Primary blue** | `Color(0.16, 0.45, 0.85)` | `#2973D9` | Window and card title bars, highlighted menu item |
| Deep blue | `Color(0.18, 0.42, 0.77)` | `#2E6BC4` | Borders of cards, windows, menu, tooltips |
| Taskbar blue | `Color(0.12, 0.37, 0.78)` | `#1F5EC7` | Taskbar background |
| Task button blue | `Color(0.24, 0.53, 0.90)` | `#3D87E6` | Open-window buttons, title bar buttons |
| Soft blue | `Color(0.49, 0.65, 0.86)` | `#7DA6DB` | Borders of regular buttons and inputs |
| **Orange accent** | `Color(1, 0.69, 0.25)` | `#FFB040` | Line under title bars, hover, event stripe |
| Hover orange | `Color(1, 0.60, 0.15)` | `#FF9926` | Card and button border on hover |
| **Close red** | `Color(0.87, 0.33, 0.20)` | `#DE5433` | ✕ button |
| **Start green** | `Color(0.24, 0.66, 0.29)` | `#3DA84A` | "OS" (Start) button, success indicator |
| Panel background | `Color(0.965, 0.98, 1)` | `#F6FAFF` | Window, card and menu bodies, regular buttons |
| Hover background | `Color(0.91, 0.957, 1)` | `#E8F4FF` | Cards and buttons on hover |
| Text | `Color(0.141, 0.231, 0.337)` | `#243B56` | Body text |
| Link text | `Color(0.11, 0.42, 0.80)` | `#1C6BCC` | "Click to…" hints, links |
| Text on blue | `#FFFFFF` + shadow `#082B66CC` | | Titles on blue backgrounds |
| Tooltip | `Color(1, 0.992, 0.88)` | `#FFFDE0` | Pale yellow balloon, as in XP |

**Colour rule:** blue is structure, orange is attention (hover, new, important), red is only for closing or danger, green is for launching or success. One warm accent per component.

## 2. Shapes and depth

| Element | Radius | Border | Shadow |
|---|---|---|---|
| Window, card, Start menu | 8 | 1 px deep blue | `#00000059`, size 7–14, offset (0, 3–6) |
| Title bar (header) | 6 on top, 0 at bottom | 2 px orange at bottom | — |
| Regular button | 5 | 1 px + 2 px at bottom (depth) | — |
| Title bar button (− □ ✕) | 3 | 1 px white (85 %) | — |
| Task button | 4 | 1 px light blue | — |
| Start button | 0 left / 16 right | 1 px top and right + 2 px at bottom, none on the left | subtle, to the right |
| Input field | 5 | 1 px soft blue; 2 px primary blue when focused | — |

- A pressed button has a thicker top border (2 px) and its text shifts 1 px down, so it looks pushed in.
- Card and window inner padding is 2 px, so the header sits almost flush with the frame, as in XP.

## 3. Typography

| Role | Size | Colour |
|---|---|---|
| Window title | 19 | white + shadow (`HeaderTitle`) |
| Card title | 17 | white + shadow (`HeaderTitle`) |
| Start menu title | 28 | white + shadow |
| Body text | 20 (theme default) | text |
| Card text | 16 | text |
| Hint, secondary text | 14 | link text |
| Start button | 22 | white with 3 px green outline |

Long titles are truncated with an ellipsis (`text_overrun_behavior = 3`).

## 4. Components (theme variations)

| Variation | Base | Purpose |
|---|---|---|
| `Card` | PanelContainer | Light card with border and shadow |
| `HeaderPanel` | PanelContainer | Blue header with an orange line at the bottom |
| `HeaderTitle` | Label | White title with shadow |
| `TitleButton` | Button | Blue square "−" and "□" title bar buttons |
| `TitleClose` | Button | Red "✕" button |
| `MenuItem` | Button | Menu entry: transparent; on hover, blue fill, white text and an orange stripe on the left |
| `TaskButton` | Button | Taskbar window button; the active window's button is dark and pushed in |
| `StartButton` | Button | Green Start button, rounded on the right |
| `Button` (base) | | Light button with depth; orange border on hover |
| `Widget` | PanelContainer | Phone-style desktop widget: radius 12, 92 % opaque panel, 1 px deep blue border, soft shadow |
| `MailRibbon` | PanelContainer | Mail toolbar strip: hover-blue background, soft blue line at the bottom |
| `MailSidebar` / `MailList` / `MailReader` | PanelContainer | Mail panes: folder column, white message list, white reading pane |
| `MailFolder` | Button | Folder entry: transparent; selected gets a light blue fill and a 3 px primary blue stripe on the left |
| `MailRow` | Button | Message in the list: white with a thin divider; selected gets a light blue fill and a 4 px primary blue stripe |
| `MailAvatar` | PanelContainer | Round primary blue sender badge with white initials |
| `MailStrong` / `MailAccent` / `MailMuted` | Label | Bold text / bold link-coloured text (unread subject) / 15 px secondary text |
| `MailBody` | RichTextLabel | Letter body, 18 px; links are drawn in link colour and underlined |
| `QaRow` | Button | DEBUG checklist entry: white with a thin divider, hover-blue on hover |
| `QaBox` / `QaBoxPass` / `QaBoxFail` | PanelContainer | 30 px check box: empty with a soft blue border / start green with a white tick / close red with a white cross |
| `QaSubmit` | Button | Green SUBMIT button of the DEBUG window |

### Card anatomy (notification)

```
┌──────────────────────────────────────┐  ← Card: radius 8, #2E6BC4 border, shadow
│ [ic] Title                      [✕] │  ← HeaderPanel + HeaderTitle + TitleClose
├══════════════════════════════════════┤  ← 2 px orange line
│ ▌ [ICON]  Message text…              │  ← 4 px accent stripe (colour set per event)
│ ▌  48px   Click to open              │  ← 14 px hint in link colour
└──────────────────────────────────────┘
```

An app window is built the same way: a `HeaderPanel` with a 22 px icon, title and − □ ✕ buttons, then a body with 8 px padding.
An inactive window has a grey-blue header `#7D97BA` with a grey line `#BAC7D9` under it.

## 5. States

| State | What changes |
|---|---|
| Hover | Border turns orange, background lightens to `#E8F4FF`, card shadow grows |
| Pressed | Background darkens, top border is 2 px |
| Active (window, task) | Saturated blue; task button is dark blue `#174A9E` |
| Inactive | Muted grey-blue |
| Disabled | Background `#ECEFF3`, border `#BFC9D6`, grey text |
| Appear / disappear | Opacity fade: 0.2 s in, 0.15 s out |

## 6. Icons

All icons are generated SVGs in `assets/generated/`.

- 64×64 canvas, `viewBox="0 0 64 64"`, 3–5 px margin from the edge.
- 2 px outline in `#123A73` (dark blue) with rounded joins (`stroke-linejoin="round"`).
- Depth: a linear or radial gradient from light at the top-left to dark at the bottom-right. Highlight: a white spot at 18–35 % opacity.
- Main fills: blues `#7CC4FF → #2F84E0 → #1A4FA6`, lights `#FFFFFF → #DCE9F8`.
- One warm accent per icon: orange `#FFB040`, red `#DE5433` or green `#5CC96F` / `#3CC46B`.
- No text inside icons (symbols are fine).

Set: `browser.svg` (blue globe with green continents), `notepad.svg` (page with a pencil), `about.svg` (monitor with an "i"), `calculator.svg`, `mail.svg` (envelope with a letter and an orange "new" dot), `debug.svg` (report window with an orange bug), `check.svg` / `cross.svg` (white marks for `QaBoxPass` / `QaBoxFail`), `terminal.svg`, `operations.svg`, `bank.svg`, `slots.svg`, needs: `sleep.svg`, `hunger.svg`, `happiness.svg`, `social.svg`.

## 7. Desktop layout

- Taskbar: height 66, background `#1F5EC7`, 2 px light line `#6BADFA` on top. Start sits flush against the left, top and bottom edges of the taskbar (no padding, as in XP). Task buttons are 46 px tall, centred vertically, 6 px apart. Clock and date in white on the right.
- Notifications: a stack on the right above the clock, 12 px from the edge and 12 px above the taskbar, 10 px between cards. Newest on top. Every notification comes from a new letter in Mail; clicking it opens that letter.
- Start menu: a card above the button, with a `HeaderPanel` titled "OS" on top and `MenuItem` entries with 26 px icons below.
- Status widget (`scenes/widgets/needs_widget.tscn`): top-right, 24 px from the edges, under the windows. Each need is a `need_gauge.tscn` ring (46 px, 5 px stroke, starts at 12 o'clock, clockwise) with its icon inside. Ring colours: sleep indigo `#6B5EDB`, hunger orange `#FF9926`, happiness yellow `#F2C230`, social green `#3DA84A`.
- Desktop shortcut selection: semi-transparent primary blue; hovering a selected shortcut gives it an orange border.

### Mail app

Outlook-like three-pane layout (`scenes/apps/mail.tscn`): a `MailRibbon` toolbar with a search field on the right, then folders, message list and reading pane. An unread letter has a 4 px orange stripe, a bold sender and a bold link-coloured subject; the Inbox shows the unread count. Letters are `MailMessage` resources (`data/mail/*.tres`) with a BBCode body. Links (`[url=bank.oc]…[/url]`, or bare `https://…` / `*.oc` addresses) are clickable and open in the Browser. The story opens with three letters sent one by one by the `IntroMail` node in `desktop.tscn`: the OS Mail welcome, the landlord's rent bill (link to `bank.oc/payments`) and a friend's advice to look for work on `stupidjob.oc`. Each reaches a user once.

## 8. Adding new UI

1. First look for a suitable variation in the theme. If there is none, add a new variation to `os_theme.tres` instead of overrides in the scene.
2. Take colours only from the palette (section 1).
3. A new pop-up element is a `Card` + `HeaderPanel`.
4. A new action is a base-type button; a dangerous action uses a red style like `TitleClose`.

### Browser

`BrowserToolbar` holds the Back, Forward, Refresh and Home icons. `BrowserAddress` starts with a globe and ends with a Go arrow. Disabled history buttons stay visible at reduced opacity. `BrowserSurface` provides a white background for the page.

Pages load like on a real network: every navigation, Back/Forward and ↻ Refresh clears the page and fetches it again in 0.5–2 s (`load_time` on `scenes/apps/browser.tscn`). While loading, a 3 px primary blue `BrowserLoadBar` under the address bar fills up and a centred `BrowserStatus` label says "Waiting for <host>…". Only the latest navigation is shown; an older one still in flight is dropped.

### Login screen

`scenes/login.tscn` appears after the boot logo and replaces a main menu. Layout from top to bottom: a dark blue `LoginTopBand` (120 px, light blue line at the bottom), a `LoginBody` blue field with a soft white glow at the top-left, and a `LoginBottomBand` (130 px, 2–3 px orange line on top).

- Left half: italic "Byteforge® / OS" logo (`LoginMaker`, `LoginLogo`) and the `LoginText` prompt, right-aligned. On login it switches to an italic "welcome" with "Loading your personal settings…".
- A faded white vertical divider in the middle.
- Right half: one `LoginTile` per user (`scenes/user_tile.tscn`: 72 px framed avatar, 30 px white name; hover gives a dark translucent fill with an orange border), then the "New user" tile. "New user" opens an inline name field with a green `GoButton` arrow; errors use `LoginError`.
- Bottom band: `LoginPower` "Turn off computer" (quits the game) on the left, "Settings" with a `LoginHint` below on the right.
- Settings (`scenes/settings_dialog.tscn`) is a `Card` over a `ModalDim` backdrop: volume slider, screen size, and a `DangerButton` "Reset saves" that asks for confirmation inline.

Avatars are `avatar_rocket.svg`, `avatar_flower.svg`, `avatar_ball.svg`, `avatar_duck.svg` (framed with a 3 px white border); also `new_user.svg`, `power.svg`, `settings.svg`, `go.svg`.

### DEBUG window (TinySoft QA)

`scenes/apps/qa_debug.tscn` opens to the right of the Browser whenever a `tinysoft.test.oc/{uuid}` test build is loaded. A `MailRibbon` shows the task and session id, then a white `MailList` pane of `QaRow` checks (`scenes/qa/qa_check_row.tscn`). Clicking a check cycles: not tested → green tick (works) → red cross (bug) → not tested. The green `QaSubmit` button unlocks once every check is marked.

The job board `stupidjob.oc` (`work_theme.tres`, navy and teal) and the TinySoft store (`tinysoft_theme.tres`, purple with a yellow "TEST ENVIRONMENT" banner) are third-party sites with their own themes.
