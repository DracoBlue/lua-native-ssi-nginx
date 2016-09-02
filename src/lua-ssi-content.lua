
local prefix = ngx.var.ssi_api_gateway_prefix
local res = ngx.location.capture(prefix .. ngx.var.request_uri)
-- ngx.ctx

ngx.log(ngx.STDERR, "request_uri: ", prefix .. ngx.var.request_uri)
local regularExpression = '<!%-%-# include file="[^"]+" %-%->'
local ssiResponses = {}

local getSsiRequestsAndCount = function(body)
    local ssiRequests = {}
    local ssiRequestsCount = 0
    local ssiMatchesCount = 0
    local ssiRequestLock = {}

    local matches = string.gmatch(body, regularExpression)
    for match,n in matches do
--        ngx.log(ngx.STDERR, "matches", match)
        local ssiVirtualPath = string.match(match, '<!%-%-# include file="([^"]+)" %-%->')
--        ngx.log(ngx.STDERR, "ssiVirtualPath", ssiVirtualPath)
        if ssiResponses[prefix .. ssiVirtualPath] == nil and ssiRequestLock[prefix .. ssiVirtualPath] == nil
--        if ssiResponses[prefix .. ssiVirtualPath] == nil
        then
            ssiRequestLock[prefix .. ssiVirtualPath] = true
            table.insert(ssiRequests, { prefix .. ssiVirtualPath })
            ssiRequestsCount = ssiRequestsCount + 1
        end
        ssiMatchesCount = ssiMatchesCount + 1
    end
    return ssiRequests, ssiRequestsCount, ssiMatchesCount
end

if res then
--    ngx.say("status: ", res.status)
--    ngx.say("body:")
--    ngx.print(res.body)
    local body = res.body
    local totalSsiSubRequestsCount = 0
    local totalSsiIncludesCount = 0

    local ssiRequests, ssiRequestsCount, ssiMatchesCount = getSsiRequestsAndCount(body)

    while ssiMatchesCount > 0
    do
        if (ssiRequestsCount > 0)
        then
            -- FIXME: handle ssiRequestsCount > 200, because this is the internal nginx limit
            -- issue all the requests at once and wait until they all return
            local resps = { ngx.location.capture_multi(ssiRequests) }

            -- loop over the responses table
            for i, resp in ipairs(resps) do
    --            ngx.log(ngx.STDERR, "resp ", i, " with ", resp.status, " and body ", resp.body)
    --            ngx.log(ngx.STDERR, "url ", ssiRequests[i][1])
                ssiResponses[ssiRequests[i][1]] = resp
                -- process the response table "resp"
            end
        end

        local replacer = function(w)
            local ssiVirtualPath = string.match(w, '<!%-%-# include file="([^"]+)" %-%->')
            if (ssiResponses[prefix .. ssiVirtualPath] == nil)
            then
                ngx.log(ngx.STDERR, "did not capture multi with ssiVirtualPath ", ssiVirtualPath)
                return w
            else
                return ssiResponses[prefix .. ssiVirtualPath].body
            end
        end

        totalSsiSubRequestsCount = totalSsiSubRequestsCount + ssiRequestsCount
        totalSsiIncludesCount = totalSsiIncludesCount + ssiMatchesCount

        body = string.gsub(body, regularExpression, replacer)
        ssiRequests, ssiRequestsCount, ssiMatchesCount = getSsiRequestsAndCount(body)
    end
    local md5 = ngx.md5(body)
--    ngx.log(ngx.STDERR, "sent?", ngx.headers_sent)
--    ngx.log(ngx.STDERR, "md5", md5)
    ngx.log(ngx.STDERR, "ssiRequestsCount", totalSsiSubRequestsCount)
    ngx.ctx.etag = '"' .. md5 .. '"'
    ngx.ctx.ssiRequestsCount = totalSsiSubRequestsCount
    ngx.ctx.ssiIncludesCount = totalSsiIncludesCount
    ngx.ctx.res = res
    ngx.print(body)
end