# lua-native-ssi-nginx CHANGELOG

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
