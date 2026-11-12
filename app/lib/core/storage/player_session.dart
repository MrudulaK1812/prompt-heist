import 'session_store.dart';

const _kToken = 'playerToken';

void savePlayerToken(String token) => sessionWrite(_kToken, token);
String? loadPlayerToken() => sessionRead(_kToken);
void forgetPlayerToken() => sessionRemove(_kToken);
