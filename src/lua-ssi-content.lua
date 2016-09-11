
local prefix = ngx.var.ssi_api_gateway_prefix
local invalidJsonFallback = ngx.var.ssi_invalid_json_fallback or '{"error": "invalid json in ssi", "url": %%URL%%, "message": %%MESSAGE%%}'
local validateJson = false
local validateJsonTypes = {}
if ngx.var.ssi_validate_json_types ~= ""
then
    validateJson = true
    validateJsonTypes = string.gmatch(ngx.var.ssi_validate_json_types, "%S+")
end

local res = ngx.location.capture(prefix .. ngx.var.request_uri, {method = ngx["HTTP_" .. ngx.var.request_method], body = ngx.var.request_body})

local getContentTypeFromHeaders = function(headers)
    for k, v in pairs(headers) do
        if (string.lower(k) == "content-type" or string.lower(k) == "content_type")
        then
            return v
        end
    end

    return nil
end

local cjson = (function(validateJson)
    if not validateJson then
        return false
    end

    local hasCjson, cjson = pcall(function()
        return require "cjson.safe"
    end)

    if (hasCjson)
    then
        return cjson
    end

    return false
end)(validateJson)

if validateJson and not cjson then
    ngx.log(ngx.STDERR, "Even though ssi_validate_json is true, the cjson library is not installed! Skip validation!")
end

ngx.log(ngx.STDERR, "request_uri: ", prefix .. ngx.var.request_uri)
local regularExpression = '<!%-%-# include file="[^"]+" %-%->'

local getSsiRequestsAndCount = function(ssiResponses, body)
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
    local contentType = getContentTypeFromHeaders(res.header)
--    ngx.say("status: ", res.status)
--    ngx.say("body:")
--    ngx.print(res.body)
    local ssiResponses = {}
    local body = res.body
    local totalSsiSubRequestsCount = 0
    local totalSsiIncludesCount = 0

    local ssiRequests, ssiRequestsCount, ssiMatchesCount = getSsiRequestsAndCount(ssiResponses, body)

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
        ssiRequests, ssiRequestsCount, ssiMatchesCount = getSsiRequestsAndCount(ssiResponses, body)
    end
    local md5 = ngx.md5(body)
--    ngx.log(ngx.STDERR, "sent?", ngx.headers_sent)
--    ngx.log(ngx.STDERR, "md5", md5)
    ngx.log(ngx.STDERR, "ssiRequestsCount", totalSsiSubRequestsCount)
    ngx.ctx.etag = '"' .. md5 .. '"'
    ngx.ctx.ssiRequestsCount = totalSsiSubRequestsCount
    ngx.ctx.ssiIncludesCount = totalSsiIncludesCount
    ngx.ctx.res = res

    if (validateJson)
    then
        ngx.log(ngx.STDERR, "check if content type matches: ", contentType)
        validateJson = false
        if contentType
        then
            for validateJsonType in validateJsonTypes do
                if string.match(contentType, validateJsonType)
                then
                    validateJson = true
                    break
                end
            end
            if not validateJson
            then
                ngx.log(ngx.STDERR, "disable validation, because content type does not match")
            end
        end
    end

    if cjson and validateJson
    then
        local value, errorMessage = cjson.decode(body)
        if errorMessage then
            body = string.gsub(invalidJsonFallback, "%%%%URL%%%%", cjson.encode(ngx.var.request_uri))
            body = string.gsub(body, "%%%%MESSAGE%%%%", cjson.encode(errorMessage))

            if totalSsiSubRequestsCount ~= 0
            then
                local bodyTable = cjson.decode(body)
                bodyTable.brokenSsiRequests = {}
                -- loop over the responses table
                for ssiRequestUrl, ssiResponse in pairs(ssiResponses) do
                    ssiResponse = string.gsub(ssiResponse.body, regularExpression, "{}")
                    local ssiResponseDecodedValue, ssiResponseDecodingErrorMessage = cjson.decode(ssiResponse)
                    if (ssiResponseDecodingErrorMessage)
                    then
                        table.insert(bodyTable.brokenSsiRequests, {url = string.sub(ssiRequestUrl, string.len(prefix) + 1), message = ssiResponseDecodingErrorMessage })
                    end
                end

                body = cjson.encode(bodyTable)
            end
        end
    end

    ngx.print(body)
end