// 通过原生参数传入值，不拼接密码到脚本；只填写小米主框架内的现有登录表单。
const miLoginPrefillScript = r'''
const allowed = () => window.top === window &&
  location.origin === 'https://account.xiaomi.com' &&
  ['/pass/serviceLogin', '/fe/service/login', '/fe/service/login/password']
    .includes(location.pathname.replace(/\/+$/, ''));
if (!allowed()) return false;
return await new Promise((resolve) => {
  let observer, timeout, done = false;
  const finish = (result) => {
    if (done) return;
    done = true;
    if (observer) observer.disconnect();
    clearTimeout(timeout);
    resolve(result);
  };
  const visible = (field) => !field.disabled && !field.readOnly && field.getClientRects().length > 0;
  const attempt = () => {
    if (done) return true;
    if (!allowed()) { finish(false); return true; }
    const secret = [...document.querySelectorAll('input[type="password"]')].find(visible);
    if (!secret) return false;
    const form = secret.form || document;
    const username = [...form.querySelectorAll([
      'input[name="account"]', 'input[name="user"]', 'input[name="username"]',
      'input[autocomplete="username"]', 'input[type="email"]', 'input[type="tel"]',
      'input[placeholder*="小米"]', 'input[placeholder*="邮箱"]', 'input[placeholder*="手机号"]'
    ].join(','))].find(visible);
    if (!username) return false;
    // 用户已经改写的内容优先；不填验证码、勾选协议或点击登录。
    if ((username.value && username.value !== account) || secret.value) {
      finish(true); return true;
    }
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    const write = (field, value) => {
      setter.call(field, value);
      field.dispatchEvent(new Event('input', {bubbles: true}));
      field.dispatchEvent(new Event('change', {bubbles: true}));
    };
    if (!username.value) write(username, account);
    write(secret, password);
    finish(true);
    return true;
  };
  if (attempt()) return;
  observer = new MutationObserver(attempt);
  observer.observe(document.documentElement, {childList: true, subtree: true, attributes: true});
  timeout = setTimeout(() => finish(false), 8000);
});
''';
