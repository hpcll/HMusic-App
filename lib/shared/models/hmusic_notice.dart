// 轻量通知模型：ViewModel 把一次性提示放进 state.notice，视图层 ref.listen
// 后交给 showHMusicToast 展示。kind 对应 docs/03 Toast 的语义左边框。
// 刻意不实现 ==：每次赋值都是新事件，重复文案也要重新触发 listen 再弹一次。
enum HMusicNoticeKind { info, success, error }

class HMusicNotice {
  const HMusicNotice(this.message) : kind = HMusicNoticeKind.info;

  const HMusicNotice.success(this.message) : kind = HMusicNoticeKind.success;

  const HMusicNotice.error(this.message) : kind = HMusicNoticeKind.error;

  final String message;
  final HMusicNoticeKind kind;
}
