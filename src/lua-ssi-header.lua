if not ngx.headers_sent and ngx.ctx.res
then
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
    if ngx.ctx.overrideContentType then
        ngx.header["Content-Type"] = ngx.ctx.overrideContentType
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