# lua-native-ssi-nginx

* Latest Release: [![GitHub version](https://badge.fury.io/gh/DracoBlue%2Flua-native-ssi-nginx.png)](https://github.com/DracoBlue/lua-native-ssi-nginx/releases)
* Build Status: [![Build Status](https://secure.travis-ci.org/DracoBlue/lua-native-ssi-nginx.png?branch=master)](http://travis-ci.org/DracoBlue/lua-native-ssi-nginx)

This is an effort to replace nginx's c ssi implementation with a flexible native lua based version, since nginx ssi does
[not](https://github.com/openresty/lua-nginx-module#mixing-with-ssi-not-supported) work with the lua module.

This solution has some advantages over the c ssi version:

* it allows regexp for ssi types (because there are [no wildcards](http://stackoverflow.com/questions/34392175/using-gzip-types-ssi-types-in-nginx-with-wildcard-media-types) in c ssi_types)
* it works with lua module
* for `200 OK` responses it generates and handles etags based on md5 *after* all ssi includes have been performed
* it handles and sanitizes invalid json in subrequests (inline or as summary)
* it handles **only**: `<!--#include file="PATH" -->` and `<!--#include virtual="PATH" -->` and no other ssi features
* it minimizes `max-age` of `Cache-Control` to the lowest value 

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


## Activate JSON Summary Validation

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

## Activate JSON Inline Validation

If you don't want to replace the entire SSI response with an error summary (like in the previous section), you can add:

```
set $ssi_validate_json_inline on;
```

and only the broken SSI will be replaced with the `$ssi_invalid_json_fallback`.

**Important**: Please don't forget to define `$ssi_validate_json_types` and `$ssi_invalid_json_fallback` like described
in the previous section!.

So:

``` txt
GET /broken_json_include/
{"thisIsThe": "index", "sub_resources": [<!--# include file="/broken_json_include/broken_sub_resource.json" -->] }

GET /broken_json_include/broken_sub_resource.json
{"thisIsA": "subResource", "with invalud json}
```

will result in the following valid json response:

``` json
{
  "thisIsThe": "index",
  "sub_resources": [
    {
      "error": "invalid json",
      "url": "/broken_json_include/",
      "message": "Expected object key string but found unexpected end of string at character 47"
    }
  ]
}
```

## Limit recursion depth

The default values for the maximum depth (1024) and the maximum amount of includes (65535) can be changed with the following
configuration parameters:

```
set $ssi_max_includes 512;
set $ssi_max_ssi_depth 16;
```

If the limit is exceeded, the ssi will be replaced with:

``` json
{
	"error": "invalid json",
	"url": "\/recursion_cap_depth\/sub_resource.json",
	"message": "max recursion depth exceeded 16(was 17)"
}
```

or

``` json
{
	"error": "invalid json",
	"url": "\/recursion_cap\/sub_resource.json",
	"message": "max ssi includes exceeded 512(was 728)"
}
```


You can change the response with:

``` json
set $ssi_invalid_json_fallback '{"error": "invalid json", "url": %%URL%%, "message": %%MESSAGE%%}';
```

## Minimize `max-age` in `Cache-Control`

You can calculate the lowest `max-age` of the root document and all sub resources and return the lowest value. Additionally
 it takes the `age` response header of the sub resources into account and decreases the `max-age` by this value. This
 feature is opt-in only and you can activate it like this:

``` txt
set $ssi_minimize_max_age on;
```

The default is:

``` txt
set $ssi_minimize_max_age off;
```

An example:

    /users (max-age=60, age=0 -> ttl=60), includes:
       -> /users/1 (max-age=10, age=7 -> ttl=3)
       -> /users/2 (max-age=5, age=0 -> ttl=5)

will return in `max-age=3` since 3 is the lowest ttl and thus the `max-age` value for the entire request.

**Important**: If you activate this feature, all other Cache-Control directives will be removed and only `Cache-Control: max-age=300`
(if the minimum max-age was 300) or `Cache-Control: max-age=0, nocache` (if the minimum was negative) will be served.
 Additional Cache-Control features like `stale-while-revalidate` or `stale-if-error` will be removed.
 
Invalid max-age values will be replaced with `Cache-Control: nocache, max-age=0`.

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

## FAQ

### Subrequests hang when used with lua native ssi

The following setup is often used, to avoid buffering on disk:

``` text
proxy_buffer_size          16k;
proxy_buffering         on;
proxy_max_temp_file_size 0;
```

but it will result in hanging requests, if the response size is bigger then 16k.

That's why you should either use (means: disable buffering at all):

``` text
proxy_buffer_size          16k;
proxy_buffering         off;
```

or (means: store up to 1024m in temp file)

``` text
proxy_buffer_size          16k;
proxy_buffering         on;
proxy_max_temp_file_size 1024m;
```

to work around this issue.


## TODOs

See <https://github.com/DracoBlue/lua-native-ssi-nginx/issues> for all open TODOs.

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).

## License

This work is copyright by DracoBlue (<http://dracoblue.net>) and licensed under the terms of MIT License.
