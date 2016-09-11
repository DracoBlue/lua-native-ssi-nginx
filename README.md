# lua-native-ssi-nginx

* Latest Release: [![GitHub version](https://badge.fury.io/gh/DracoBlue%2Flua-native-ssi-nginx.png)](https://github.com/DracoBlue/lua-native-ssi-nginx/releases)
* Build Status: [![Build Status](https://secure.travis-ci.org/DracoBlue/lua-native-ssi-nginx.png?branch=master)](http://travis-ci.org/DracoBlue/lua-native-ssi-nginx)

This is an effort to replace nginx's c ssi implementation with a flexible native lua based version, since nginx ssi does
[not](https://github.com/openresty/lua-nginx-module#mixing-with-ssi-not-supported) work with the lua module.

This solution has some  advantages over the c ssi version:

* it (will) allow regexp for ssi types (because there are [no wildcards](http://stackoverflow.com/questions/34392175/using-gzip-types-ssi-types-in-nginx-with-wildcard-media-types) in c ssi_types)
* it works with lua module
* it generates and handles etags based on md5 *after* all ssi includes have been performed

## Usage

If you started with location like this:

``` txt
location / {
	proxy_pass http://127.0.0.1:4777;
}
```

you have to replace it with something like this:

``` txt
location /ssi-api-gateway/ {
	internal;
	rewrite ^/ssi-api-gateway/(.*)$ /$1  break;
	proxy_pass http://127.0.0.1:4777;
}

location / {
	lua_need_request_body on; # otherwise the request_body is not available for POST requests!
	set $ssi_api_gateway_prefix "/ssi-api-gateway";
	content_by_lua_file "/etc/nginx/lua-ssi-content.lua";
	header_filter_by_lua_file "/etc/nginx/lua-ssi-header.lua";
}
```

The `ssi-api-gateway` location is necessary to use e.g. nginx's caching layer and such things.

## Development

To run the tests locally launch:

``` console
$ ./launch-test-nginx.sh
...
Successfully built 72a844684987
2016/09/11 11:34:02 [alert] 1#0: lua_code_cache is off; this will hurt performance in /etc/nginx/sites-enabled/port-4778-app.conf:12
nginx: [alert] lua_code_cache is off; this will hurt performance in /etc/nginx/sites-enabled/port-4778-app.conf:12
```

Now the nginx processes are running with docker.

Now you can run the tests like this:

``` console
$ ./run-tests.sh
  [OK] echo
  [OK] echo_custom_header
  [OK] echo_method
  [OK] gzip
  [OK] image
  [OK] json
  [OK] json_include
  [OK] one
```

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).

## License

This work is copyright by DracoBlue (<http://dracoblue.net>) and licensed under the terms of MIT License.