# lua-native-ssi-nginx CHANGELOG

## 1.1.0

- added explanation for `proxy_max_temp_file_size 0` vs `proxy_buffering on`
- removed `always_forward_body` because it does not always send all data to the first request

## 1.0.3

- fixed url in inline json validation response

## 1.0.2

- added recursion handling (depth and max includes)

## 1.0.1

- handle header-only invocations (don't crash on empty `ngx.ctx.res`)
- removed necessity for `lua_need_request_body on` in nginx
- forward request body in a native way now (with `always_forward_body`)

## 1.0.0

- initial release
