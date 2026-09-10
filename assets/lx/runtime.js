// LX Music 协议适配：脚本只接触自己的请求和结果，原生侧不提供账号或文件访问。
(() => {
  const bridge = (type, data = {}) => sendMessage('HMusicLx', JSON.stringify({ type, ...data }));
  const callbacks = new Map(), timers = new Map();
  let requestHandler, sequence = 0, initialized = false;
  const bytes = value => typeof value === 'string' ? value :
    Array.from(value instanceof ArrayBuffer ? new Uint8Array(value) : value || []);
  const crypto = (operation, args) => {
    const result = bridge('crypto', { operation, args });
    if (result.error) throw new Error(result.error);
    return result.value;
  };
  const buffer = {
    from(value, encoding = 'utf8') {
      const result = new Uint8Array(crypto('decode', [bytes(value), encoding]));
      Object.defineProperty(result, 'toString', { value: (format = 'utf8') => buffer.bufToString(result, format) });
      return result;
    },
    bufToString(value, encoding = 'utf8') {
      return crypto('encode', [Array.from(value), encoding]);
    },
  };
  globalThis.console = Object.fromEntries(['log', 'info', 'debug', 'warn', 'error', 'trace'].map(name => [name, () => {}]));
  globalThis.setTimeout = (callback, delay = 0, ...args) => {
    const id = String(++sequence);
    timers.set(id, () => callback(...args));
    bridge('timer', { id, delay: Math.max(0, Math.min(60000, Number(delay) || 0)) });
    return id;
  };
  globalThis.clearTimeout = id => { timers.delete(String(id)); bridge('cancelTimer', { id: String(id) }); };
  globalThis.__hmusicTimer = id => {
    const callback = timers.get(id);
    timers.delete(id);
    if (callback) callback();
  };
  globalThis.__hmusicHttp = (id, error, response) => {
    const callback = callbacks.get(id);
    callbacks.delete(id);
    if (!callback) return;
    if (response && response.binary) response.body = new Uint8Array(response.body);
    callback(error ? new Error(error) : null, response, response && response.body);
  };
  const request = (url, options = {}, callback) => {
    const id = String(++sequence);
    callbacks.set(id, callback);
    bridge('http', { id, url, options });
    const cancel = () => { callbacks.delete(id); bridge('cancelHttp', { id }); };
    cancel.abort = cancel;
    return cancel;
  };
  globalThis.__hmusicStart = metadata => {
    globalThis.lx = {
      EVENT_NAMES: { request: 'request', inited: 'inited', updateAlert: 'updateAlert' },
      version: '2.0.0', env: 'mobile', currentScriptInfo: metadata,
      request,
      on(event, callback) {
        if (event !== 'request' || typeof callback !== 'function') return Promise.reject(new Error('Unsupported LX event'));
        requestHandler = callback;
        return Promise.resolve();
      },
      send(event, data) {
        if (event === 'inited' && !initialized) {
          initialized = true;
          bridge('init', { data });
          return Promise.resolve();
        }
        if (event === 'updateAlert') return Promise.resolve();
        return Promise.reject(new Error('Unsupported LX event'));
      },
      utils: {
        buffer,
        crypto: {
          md5: value => crypto('md5', [bytes(value)]),
          randomBytes: size => new Uint8Array(crypto('random', [size])),
          aesEncrypt: (value, mode, key, iv) => new Uint8Array(crypto('aes', [bytes(value), mode, bytes(key), bytes(iv)])),
          rsaEncrypt: (value, key) => new Uint8Array(crypto('rsa', [bytes(value), key])),
        },
      },
    };
  };
  globalThis.__hmusicRequest = (id, source, action, info) => {
    Promise.resolve().then(() => {
      if (!requestHandler) throw new Error('Missing LX request handler');
      return requestHandler({ source, action, info });
    }).then(value => bridge('result', { id, value }),
      () => bridge('result', { id, error: '音源未返回可用结果' }));
  };
  globalThis.atob = value => crypto('encode', [crypto('decode', [value, 'base64']), 'binary']);
  globalThis.btoa = value => crypto('encode', [crypto('decode', [value, 'binary']), 'base64']);
  globalThis.Buffer = {
    from: buffer.from,
    alloc: (size, fill = 0) => new Uint8Array(size).fill(fill),
    concat: arrays => new Uint8Array(arrays.flatMap(value => Array.from(value))),
    isBuffer: value => value instanceof Uint8Array,
  };
  globalThis.fetch = (url, options = {}) => new Promise((resolve, reject) => {
    request(url, options, (error, response) => {
      if (error) return reject(error);
      const body = response.body;
      resolve({ status: response.statusCode, ok: response.statusCode >= 200 && response.statusCode < 300,
        headers: { get: name => response.headers[name.toLowerCase()] || null },
        text: async () => typeof body === 'string' ? body : JSON.stringify(body),
        json: async () => typeof body === 'string' ? JSON.parse(body) : body,
      });
    });
  });
})();
