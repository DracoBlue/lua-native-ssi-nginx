
local prefix = ngx.var.ssi_api_gateway_prefix
local invalidJsonFallback = ngx.var.ssi_invalid_json_fallback or '{"error": "invalid json in ssi", "url": %%URL%%, "message": %%MESSAGE%%}'
local validateJson = false
local validateJsonInline = false
local validateJsonTypes = {}
if ngx.var.ssi_validate_json_types ~= nil and ngx.var.ssi_validate_json_types ~= ""
then
    validateJson = true
    validateJsonTypes = string.gmatch(ngx.var.ssi_validate_json_types, "%S+")
end
if ngx.var.ssi_validate_json_inline ~= nil and ngx.var.ssi_validate_json_inline == "on"
then
    validateJsonInline = true
end
local ssiTypes = string.gmatch(".*", "%S+")
if ngx.var.ssi_types ~= nil and ngx.var.ssi_types ~= ""
then
    ssiTypes = string.gmatch(ngx.var.ssi_types, "%S+")
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

local matchesContentTypesList = function(contentType, contentTypesList)
    if contentType == nil
    then
        return false
    end

    for contentTypeListItem in contentTypesList do
        if string.match(contentType, contentTypeListItem)
        then
            return true
        end
    end
    return false
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
    ngx.log(ngx.ERR, "Even though ssi_validate_json is true, the cjson library is not installed! Skip validation!")
end

ngx.log(ngx.DEBUG, "request_uri: ", prefix .. ngx.var.request_uri)
local captureRegularFileExpression = '<!%-%-#%s*include file="([^"]+)"%s*%-%->'
local captureRegularVirtualExpression = '<!%-%-#%s*include virtual="([^"]+)"%s*%-%->'
local captureRegularFileExpressions = {captureRegularFileExpression,captureRegularVirtualExpression}

local getSsiRequestsAndCount = function(ssiResponses, body)
    local ssiRequests = {}
    local ssiRequestsCount = 0
    local ssiMatchesCount = 0
    local ssiRequestLock = {}

    for i,captureRegularExpression in ipairs(captureRegularFileExpressions) do
        local regularExpression = string.gsub(captureRegularExpression, "([%(%)])", "")
        local matches = string.gmatch(body, regularExpression)
        for match,n in matches do
--          ngx.log(ngx.DEBUG, "matches", match)
            local ssiVirtualPath = string.match(match, captureRegularExpression)
--          ngx.log(ngx.DEBUG, "ssiVirtualPath", ssiVirtualPath)
            if ssiResponses[prefix .. ssiVirtualPath] == nil and ssiRequestLock[prefix .. ssiVirtualPath] == nil
--          if ssiResponses[prefix .. ssiVirtualPath] == nil
            then
                ssiRequestLock[prefix .. ssiVirtualPath] = true
                table.insert(ssiRequests, { prefix .. ssiVirtualPath })
                ssiRequestsCount = ssiRequestsCount + 1
            end
            ssiMatchesCount = ssiMatchesCount + 1
        end
    end

    return ssiRequests, ssiRequestsCount, ssiMatchesCount
end

if res then
    local contentType = getContentTypeFromHeaders(res.header)
    ngx.status = res.status
--    ngx.say("status: ", res.status)
--    ngx.say("body:")
--    ngx.print(res.body)
    local body = res.body

    if (validateJson)
    then
        ngx.log(ngx.DEBUG, "check if content type matches: ", contentType)
        validateJson = matchesContentTypesList(contentType, validateJsonTypes)
    end

    if matchesContentTypesList(contentType, ssiTypes)
    then
        local ssiResponses = {}
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
        --            ngx.log(ngx.DEBUG, "resp ", i, " with ", resp.status, " and body ", resp.body)
        --            ngx.log(ngx.DEBUG, "url ", ssiRequests[i][1])
                    if validateJson and validateJsonInline
                    then
                        local bodyWithoutSsiIncludes = resp.body
                        for i,captureRegularExpression in ipairs(captureRegularFileExpressions) do
                            local regularExpression = string.gsub(captureRegularExpression, "([%(%)])", "")
                            bodyWithoutSsiIncludes = string.gsub(bodyWithoutSsiIncludes, regularExpression, "{}")
                        end
                        local value, errorMessage = cjson.decode(bodyWithoutSsiIncludes)
                        if (errorMessage) then
                            local body = string.gsub(invalidJsonFallback, "%%%%URL%%%%", cjson.encode(ngx.var.request_uri))
                            body = string.gsub(body, "%%%%MESSAGE%%%%", cjson.encode(errorMessage))
                            resp.body = body
                            ssiResponses[ssiRequests[i][1]] = resp
                        else
                            ssiResponses[ssiRequests[i][1]] = resp
                        end
                    end

                    ssiResponses[ssiRequests[i][1]] = resp
        -- process the response table "resp"
                end
            end


            for i,captureRegularExpression in ipairs(captureRegularFileExpressions) do
                local regularExpression = string.gsub(captureRegularExpression, "([%(%)])", "")

                local replacer = function(w)
                    local ssiVirtualPath = string.match(w, captureRegularExpression)
                    if (ssiResponses[prefix .. ssiVirtualPath] == nil)
                    then
                        ngx.log(ngx.ERR, "did not capture multi with ssiVirtualPath ", ssiVirtualPath)
                        return w
                    else
                        return ssiResponses[prefix .. ssiVirtualPath].body
                    end
                end

                body = string.gsub(body, regularExpression, replacer)
            end

            totalSsiSubRequestsCount = totalSsiSubRequestsCount + ssiRequestsCount
            totalSsiIncludesCount = totalSsiIncludesCount + ssiMatchesCount
            ssiRequests, ssiRequestsCount, ssiMatchesCount = getSsiRequestsAndCount(ssiResponses, body)
        end

        if ngx.status == 200
        then
            local md5 = ngx.md5(body)
            ngx.ctx.etag = '"' .. md5 .. '"'
        end

--        ngx.log(ngx.DEBUG, "ssiRequestsCount", totalSsiSubRequestsCount)
        ngx.ctx.ssiRequestsCount = totalSsiSubRequestsCount
        ngx.ctx.ssiIncludesCount = totalSsiIncludesCount

        if cjson and validateJson
        then
            local value, errorMessage = cjson.decode(body)
            if errorMessage then
                body = string.gsub(invalidJsonFallback, "%%%%URL%%%%", cjson.encode(ngx.var.request_uri))
                body = string.gsub(body, "%%%%MESSAGE%%%%", cjson.encode(errorMessage))

                if totalSsiSubRequestsCount ~= 0 and not validateJsonInline
                then
                    local bodyTable = cjson.decode(body)
                    bodyTable.brokenSsiRequests = {}
                    -- loop over the responses table
                    for ssiRequestUrl, ssiResponse in pairs(ssiResponses) do
                        local ssiResponseBody = ssiResponse.body
                        for i,captureRegularExpression in ipairs(captureRegularFileExpressions) do
                            local regularExpression = string.gsub(captureRegularExpression, "([%(%)])", "")
                            ssiResponseBody = string.gsub(ssiResponseBody, regularExpression, "{}")
                        end
                        local ssiResponseDecodedValue, ssiResponseDecodingErrorMessage = cjson.decode(ssiResponseBody)
                        if (ssiResponseDecodingErrorMessage)
                        then
                            table.insert(bodyTable.brokenSsiRequests, {url = string.sub(ssiRequestUrl, string.len(prefix) + 1), message = ssiResponseDecodingErrorMessage })
                        end
                    end

                    body = cjson.encode(bodyTable)
                end

                ngx.ctx.etag = nil
                ngx.ctx.overrideContentType = "application/json";
                ngx.status = 500
            end
        end

    end

    ngx.ctx.res = res
    ngx.print(body)
end