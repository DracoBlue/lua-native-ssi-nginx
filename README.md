# lua-native-ssi-nginx

* Latest Release: [![GitHub version](https://badge.fury.io/gh/DracoBlue%2Flua-native-ssi-nginx.png)](https://github.com/DracoBlue/lua-native-ssi-nginx/releases)
* Build Status: [![Build Status](https://secure.travis-ci.org/DracoBlue/lua-native-ssi-nginx.png?branch=master)](http://travis-ci.org/DracoBlue/lua-native-ssi-nginx)

This is an effort to replace nginx's c ssi implementation with a flexible native lua based version, since nginx ssi does
[not](https://github.com/openresty/lua-nginx-module#mixing-with-ssi-not-supported) work with the lua module.

This solution has some  advantages over the c ssi version:

* it allows regexp for ssi types (because there are [no wildcards](http://stackoverflow.com/questions/34392175/using-gzip-types-ssi-types-in-nginx-with-wildcard-media-types) in c ssi_types)
* it works with lua module
* it generates and handles etags based on md5 *after* all ssi includes have been performed
* it handles and sanitizes invalid json in subrequests

## Usage

If you started with a location like this:

``` txt
location / {
	proxy_pass http://127.0.0.1:4777;
	# add your proxy_* parameters and so on here
}
```

you have to replace it with something like this:

``` txt
location /ssi-api-gateway/ {
	internal;
	rewrite ^/ssi-api-gateway/(.*)$ /$1  break;
	proxy_pass http://127.0.0.1:4777;
	# add your proxy_* parameters and so on here
}

location / {
	lua_need_request_body on; # otherwise the request_body is not available for POST requests!
	set $ssi_api_gateway_prefix "/ssi-api-gateway";
	set $ssi_validate_json_types "application/json application/.*json";
	set $ssi_invalid_json_fallback '{"error": "invalid json", "url": %%URL%%, "message": %%MESSAGE%%}';
	content_by_lua_file "/etc/nginx/lua-ssi-content.lua";
	header_filter_by_lua_file "/etc/nginx/lua-ssi-header.lua";
}
```

The `ssi-api-gateway` location is necessary to use e.g. nginx's caching layer and such things.

## Activate SSI only for specific content types

If you want to enable ssi only for specific content types, use the following nginx configuration variable in the nginx
location:

``` txt
set $ssi_types "text/.*html application/.*json";
```

The default is:

``` txt
set $ssi_types ".*";
```


## Activate JSON Validation

**Prerequisites**: Install cjson (e.g. `apt-get install lua-cjson` to activate this feature. Otherwise you get the following message:
`Even though ssi_validate_json is true, the cjson library is not installed! Skip validation!`.

If you want to ensure, that subrequested json is always valid, you can activate this in the nginx location:

``` txt
set $ssi_validate_json_types "application/json application/.*json";
set $ssi_invalid_json_fallback '{"error": "invalid json", "url": %%URL%%, "message": %%MESSAGE%%}';
```

If you setup the configuration like this, the following ssi:

``` txt
GET /broken_json_include/
{"thisIsThe": "index", "sub_resources": [<!--# include file="/broken_json_include/broken_sub_resource.json" -->] }

GET /broken_json_include/broken_sub_resource.json
{"thisIsA": "subResource", "with invalud json}
```


will result in the following valid json response:

``` json
{
	"error": "invalid json",
	"brokenSsiRequests": [
		{
			"url": "\/broken_json_include\/broken_sub_resource.json",
			"message": "Expected object key string but found unexpected end of string at character 47"
		}
	],
	"message": "Expected object key string but found unexpected end of string at character 91","url":"\/broken_json_include\/"
}
```

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

## TODOs

See <https://github.com/DracoBlue/lua-native-ssi-nginx/issues> for all open TODOs.

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).

## License

This work is copyright by DracoBlue (<http://dracoblue.net>) and licensed under the terms of MIT License.
