final _mem = <String, String>{};
String? sessionRead(String key) => _mem[key];
void sessionWrite(String key, String value) => _mem[key] = value;
void sessionRemove(String key) => _mem.remove(key);
