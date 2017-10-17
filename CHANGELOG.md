# lua-native-ssi-nginx CHANGELOG

## 1.6.0

- added `X-Ssi-Debug: true` request header to debug max age minimize behaviour
- fixed `nocache` to `no-cache` in `cache-control` header

## 1.5.0

- added config to override stale-while-revalidate for minimized cache
- handle stale-while-revalidate when minimizing max-cache
- log subrequest url in debug log

## 1.4.2

- set age to 0 if cache control max age is minizimed

## 1.4.1

- allow spaces around cache control directives

## 1.4.0

- added possibility to minimize `max-age` of the response by `age` and `max-age` of all sub requests

## 1.3.0

- render ssi error, if relative path is in ssi include

## 1.2.0

- fixed internal server error on percent in url or message

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
