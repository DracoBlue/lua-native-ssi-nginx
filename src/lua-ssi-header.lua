if not ngx.headers_sent and ngx.ctx.res
then
    local requestHeaders = {}

    local sanatizeHeaderFieldName = function(headerFieldName)
        return string.gsub(string.lower(headerFieldName), "_", "-")
    end

    for k, v in pairs(ngx.req.get_headers()) do
        k = sanatizeHeaderFieldName(k)
        requestHeaders[k] = v
    end

    for k, v in pairs(ngx.ctx.res.header) do
        ngx.header[k] = v
    end
    if ngx.ctx.ssiRequestsCount then
        ngx.header["X-Ssi-Sub-Requests"] = ngx.ctx.ssiRequestsCount
    end
    if ngx.ctx.ssiIncludesCount then
        ngx.header["X-Ssi-Includes"] = ngx.ctx.ssiIncludesCount
    end
    if ngx.ctx.ssiDepth then
        ngx.header["X-Ssi-Depth"] = ngx.ctx.ssiDepth
    end
    if ngx.ctx.ssiMissingCacheControlCount then
        ngx.header["X-Ssi-Missing-CC-Count"] = ngx.ctx.ssiMissingCacheControlCount
    end
    if requestHeaders["x-ssi-debug"] == "true" then
        ngx.header["X-Ssi-Minimize-MaxAge-Url"] = ngx.ctx.ssiMinimizeMaxAgeUrl
        ngx.header["X-Ssi-Minimize-MaxAge-Age"] = ngx.ctx.ssiMinimizeMaxAgeAge
        ngx.header["X-Ssi-Minimize-MaxAge-Cache-Control"] = ngx.ctx.ssiMinimizeMaxAgeCacheControl
    end
    if ngx.ctx.overrideContentType then
        ngx.header["Content-Type"] = ngx.ctx.overrideContentType
    end
    if ngx.ctx.overrideCacheControl then
        ngx.header["Cache-Control"] = ngx.ctx.overrideCacheControl
        ngx.header["Age"] = "0"
    end
    ngx.header["Content-Length"] = nil
    if ngx.ctx.etag then
        ngx.header["ETag"] = ngx.ctx.etag
        local ifNoneMatch = ngx.req.get_headers()["If-None-Match"] or nil
        ngx.log(ngx.DEBUG, "If-None-Match: ", ifNoneMatch)
        ngx.log(ngx.DEBUG, "ETag: ", ngx.ctx.etag)

        if ifNoneMatch == ngx.ctx.etag
        then
            ngx.header["Content-Length"] = 0
            ngx.exit(ngx.HTTP_NOT_MODIFIED)
            return
        end
    end
end
