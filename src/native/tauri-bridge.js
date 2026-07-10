// native/tauri-bridge.js —— invoke / event 的薄封装。
// 浏览器环境（无 window.__TAURI__）下全部 no-op，让 boot.js 及调用方无需分支判断。

export function isTauri() {
  return typeof window !== "undefined" && Boolean(window.__TAURI__);
}

// 调 Rust 命令；非 Tauri 环境返回 undefined（静默失活）。
export async function invoke(cmd, args) {
  if (!isTauri()) return undefined;
  return window.__TAURI__.core.invoke(cmd, args);
}

// 监听 Rust 事件；非 Tauri 环境返回空 unlisten。
export async function listen(event, handler) {
  if (!isTauri()) return () => {};
  return window.__TAURI__.event.listen(event, handler);
}
