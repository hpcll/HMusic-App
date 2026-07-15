#!/usr/bin/env python3
"""批量生成 HMusic 移动端 UI 视觉稿（nano-banana-pro）。"""
import json
import ssl
import urllib.request

KEY = "sk-cbd2f4e8f27821d26725cc51e83e21a5"
API = "https://wisart.kuaileshifu.com/v1/images/generations"
OUT = "/Users/pchu/AICODE/HMusic-App/design/mockups"

STYLE = (
    "High-fidelity mobile app UI design mockup, single portrait phone screen, flat design. "
    "Style: minimalist editorial, refined literary print magazine aesthetic (feather.computer style). "
    "Warm paper-white background #F7F7F8, ink-black text #1A1A1A, white cards #FFFFFF with 1px hairline "
    "borders #E3E3E5 and 10px rounded corners, muted gray #999999 secondary text, generous whitespace, "
    "calm premium feel. Songti-style SERIF font for headings/titles, clean sans-serif for body. "
    "Teal #21B0A5 appears ONLY as tiny playing-status dots, never as decoration. "
    "Crisp readable Chinese text, dribbble quality UI design. "
)

SCREENS = {
    "02-login-light": (
        "This is the LOGIN screen of self-hosted music app HMusic. Top third: large elegant serif wordmark "
        "HMusic in ink black, one line small muted tagline 登录你的音乐服务器. Center: one white card with "
        "hairline border containing: muted label 账号 above an input showing text admin, muted label 密码 "
        "above an input showing password dots, and a full-width ink-black rounded button with white text 登录. "
        "Under the card one tiny hint row: 7px teal dot then muted text 已连接 192.168.2.52. "
        "Bottom footnote small serif muted text 你的音乐，存在你自己的服务器上."
    ),
    "03-search-light": (
        "This is the SEARCH screen. Top: large serif page title 搜索 in ink black aligned left. Below it a "
        "clean search input with hairline border, muted placeholder 搜索歌曲、歌手 and a small ink magnifier icon. "
        "Below: white card with a vertical list of six song rows separated by hairline dividers; each row: "
        "44px rounded square album cover thumbnail (abstract minimal artwork), song title in ink 14px with "
        "artist name in muted 12px underneath, and at the right two small 34px outlined circle icon buttons "
        "(play triangle, plus). Bottom of screen: floating rounded white mini-player bar with small cover, "
        "title 晴天 artist 周杰伦, ink circular play button; beneath it a slim bottom tab bar with five tabs "
        "首页 搜索 队列 歌单 设置, tab 搜索 active in ink black, others muted gray."
    ),
    "04-player-light": (
        "This is the NOW PLAYING screen. Top: small down-chevron at left, tiny muted centered title 正在播放. "
        "Upper half: large square album artwork with 20px rounded corners and soft elegant shadow, artwork is "
        "an abstract ink-wash painting. Below cover: song title 晴天 in large Songti serif ink-black centered "
        "with a tiny teal playing dot beside it, artist 周杰伦 smaller muted centered. Then a thin ink progress "
        "bar with a small round thumb, tiny muted time labels 1:24 left and 4:29 right. Control row centered: "
        "small muted repeat icon, 46px hairline-outlined circle with previous icon, 64px solid ink-black circle "
        "with white pause icon, 46px outlined circle with next icon, small muted queue icon. Bottom: slim "
        "volume slider with small muted speaker icon. All monochrome ink except the single teal dot."
    ),
    "05-queue-light": (
        "This is the PLAY QUEUE screen. Top: large serif page title 播放队列 in ink black aligned left, small "
        "muted text button 清空 at right. Below: four small pill chips in a row: 列表循环 selected with ink "
        "black background and white text, then 单曲循环 随机 顺序 as hairline-outlined muted chips. Below: white "
        "card with vertical list of seven track rows separated by hairlines: each row has a muted index number "
        "at left, song title in ink with artist in muted underneath, and small outlined circular play and close "
        "icons at right; the third row is currently playing — its index is replaced by a tiny teal music-note "
        "dot and its title uses emphasized serif ink. Bottom: floating rounded mini player bar, then slim "
        "bottom tab bar with five tabs 首页 搜索 队列 歌单 设置, tab 队列 active in ink."
    ),
    "06-connect-dark": (
        "This is the first-run CONNECT screen, DARK MODE. Background near-black #131315, card #1B1B1E with "
        "1px hairline border #313135, primary text warm white #F0F0F2, muted text #85858A. Top third: large "
        "serif wordmark HMusic in warm white, small muted tagline 自托管家庭音乐库. Center card contains: muted "
        "label 服务器地址, input field with dark hairline border and muted placeholder http://192.168.1.10:8090, "
        "full-width pale-ivory #E6E6E9 rounded button with near-black text 连接服务器. Under card: tiny row with "
        "7px teal dot #2EC4B8 and muted text 与家庭服务器局域网直连. Bottom footnote small serif muted text "
        "你的音乐，存在你自己的服务器上."
    ),
}

ctx = ssl.create_default_context()

def call(payload: dict) -> dict:
    req = urllib.request.Request(
        API,
        data=json.dumps(payload).encode(),
        headers={"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=300, context=ctx) as resp:
        return json.load(resp)

for name, brief in SCREENS.items():
    try:
        data = call({
            "model": "nano-banana-pro",
            "prompt": STYLE + brief,
            "size": "1024x1536",
            "quality": "auto",
            "n": 1,
            "response_format": "url",
        })
        url = data["data"][0]["url"].replace("http://", "https://")
        with urllib.request.urlopen(url, timeout=120, context=ctx) as img:
            body = img.read()
        path = f"{OUT}/{name}.png"
        with open(path, "wb") as f:
            f.write(body)
        print(f"OK  {name}  {len(body)//1024}KB")
    except Exception as err:  # noqa: BLE001 — 单张失败不断批
        print(f"FAIL {name}: {err}")
