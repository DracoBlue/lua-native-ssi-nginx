# lua-native-ssi-nginx

* Latest Release: [![GitHub version](https://badge.fury.io/gh/DracoBlue%2Flua-native-ssi-nginx.png)](https://github.com/DracoBlue/lua-native-ssi-nginx/releases)
* Build Status: [![Build Status](https://secure.travis-ci.org/DracoBlue/lua-native-ssi-nginx.png?branch=master)](http://travis-ci.org/DracoBlue/lua-native-ssi-nginx)

This is an effort to replace nginx's c ssi implementation with a flexible native lua based version, since nginx ssi does
[not](https://github.com/openresty/lua-nginx-module#mixing-with-ssi-not-supported) work with the lua module.

This solution has some  advantages over the c ssi version:

* it (will) allow regexp for ssi types (because there are [no wildcards](http://stackoverflow.com/questions/34392175/using-gzip-types-ssi-types-in-nginx-with-wildcard-media-types) in c ssi_types)
* it works with lua module
* it generates and (will) handle etags based on md5 *after* all ssi includes have been performed

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).

## License

This work is copyright by DracoBlue (<http://dracoblue.net>) and licensed under the terms of MIT License.