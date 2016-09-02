if not ngx.headers_sent
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
    ngx.header["Content-Length"] = nil
    if ngx.ctx.etag then
        ngx.header["E-Tag"] = ngx.ctx.etag
        local ifNoneMatch = ngx.req.get_headers()["If-None-Match"] or nil
        ngx.log(ngx.STDERR, "If-None-Match: ", ifNoneMatch)
        ngx.log(ngx.STDERR, "E-Tag: ", ngx.ctx.etag)

        if ifNoneMatch == ngx.ctx.etag
        then
            ngx.header["Content-Length"] = 0
            ngx.exit(ngx.HTTP_NOT_MODIFIED)
            return
        end
    end
end