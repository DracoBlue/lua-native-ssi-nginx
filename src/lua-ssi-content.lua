
local prefix = ngx.var.ssi_api_gateway_prefix
local invalidJsonFallback = ngx.var.ssi_invalid_json_fallback or '{"error": "invalid json in ssi", "url": %%URL%%, "message": %%MESSAGE%%}'
local maxSsiDepth = 1024
local maxSsiIncludes = 65535
if ngx.var.ssi_max_includes ~= nil and ngx.var.ssi_max_includes ~= ""
then
    maxSsiIncludes = tonumber(ngx.var.ssi_max_includes)
end
if ngx.var.ssi_max_ssi_depth ~= nil and ngx.var.ssi_max_ssi_depth ~= ""
then
    maxSsiDepth = tonumber(ngx.var.ssi_max_ssi_depth)
end

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
local minimizeMaxAge = false
if ngx.var.ssi_minimize_max_age ~= nil and ngx.var.ssi_minimize_max_age == "on"
then
    minimizeMaxAge = true
end

ngx.req.read_body()

local res = ngx.location.capture(
    prefix .. ngx.var.request_uri, {
        method = ngx["HTTP_" .. ngx.var.request_method],
        body = ngx.req.get_body_data()
    }
)

getSanitizedFieldFromHeaders = function(rawFieldName, headers)
    local sanatizeHeaderFieldName = function(headerFieldName)
        return string.gsub(string.lower(headerFieldName), "_", "-")
    end
    local sanatizedFieldName = sanatizeHeaderFieldName(rawFieldName)
    for k, v in pairs(headers) do
        if sanatizeHeaderFieldName(k) == sanatizedFieldName
        then
            return v
        end
    end

    return nil
end

getCacheControlFieldsFromHeaders = function(headers)
    local cacheControlHeader = getSanitizedFieldFromHeaders("cache-control", headers)
    if not cacheControlHeader then
        return {}
    end

    local cacheControlHeaderPrefixedAndSuffixedWithAWhitespace = ", " .. cacheControlHeader .. " ,"

    local fields = {}
    
    for key in string.gmatch(cacheControlHeaderPrefixedAndSuffixedWithAWhitespace, ',[%s]-([^=%s,]+)[%s]-')
    do
        fields[key] = true
    end

    for key, value in string.gmatch(cacheControlHeaderPrefixedAndSuffixedWithAWhitespace, '[%s,]+([^=%s,]+)%s-=%s-([^%s,]+)[%s,]-')
    do
        fields[key] = value
    end

    for key, value in string.gmatch(cacheControlHeaderPrefixedAndSuffixedWithAWhitespace, '[%s,]+([^=%s,]+)%s-=%s-"([^"]+)"[%s,]-')
    do
        fields[key] = value
    end

    return fields
end

getMaxAgeDecreasedByAgeOrZeroFromHeaders = function(headers)
    local respCacheControlFields = getCacheControlFieldsFromHeaders(headers)
    local respCacheControlMaxAge = (respCacheControlFields["max-age"] ~= nil and tonumber(respCacheControlFields["max-age"])) or nil
    if respCacheControlMaxAge == nil
    then
        if respCacheControlFields["max-age"] ~= nil then
            ngx.log(ngx.ERR, "request cache-control max-age is an invalid number: " .. tostring(respCacheControlFields["max-age"]))
        end
        return 0
    end

    local respCacheAge = tonumber(getSanitizedFieldFromHeaders("age", headers));    
    local respCacheSwr = tonumber(respCacheControlFields["stale-while-revalidate"]);
    
    ngx.log(ngx.DEBUG, "request cache-control: " .. tostring(respCacheControlMaxAge) .. " and age: " .. tostring(respCacheAge) .. " and stale-while-revalidate: " .. tostring(respCacheSwr));

    if respCacheAge ~= nil then
        respCacheControlMaxAge = respCacheControlMaxAge - respCacheAge
    end
    
    if respCacheSwr ~= nil then
        respCacheControlMaxAge = respCacheControlMaxAge + respCacheSwr
    else
        if respCacheControlFields["stale-while-revalidate"] ~= nil then
            ngx.log(ngx.ERR, "request cache-control stale-while-revalidate is an invalid number: " .. tostring(respCacheControlFields["stale-while-revalidate"]))
        end
    end

    if respCacheControlMaxAge < 0 then
        respCacheControlMaxAge = 0
    end

    return respCacheControlMaxAge
end

getContentTypeFromHeaders = function(headers)
    return getSanitizedFieldFromHeaders("content-type", headers)
end

matchesContentTypesList = function(contentType, contentTypesList)
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

local generateJsonErrorFallback = function(url, message)
    local escapedUrl = cjson.encode(url)
    local escapedMessage = cjson.encode(message)

    local body = string.gsub(invalidJsonFallback, "%%%%URL%%%%", function()
        return escapedUrl
    end)
    return string.gsub(body, "%%%%MESSAGE%%%%", function()
        return escapedMessage
    end)
end

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
                if string.sub(ssiVirtualPath, 0, 1) == "/" then
                    table.insert(ssiRequests, { prefix .. ssiVirtualPath })
                    ssiRequestsCount = ssiRequestsCount + 1
                else
                    ssiResponses[prefix .. ssiVirtualPath] = {status = 500, header = {}, body = generateJsonErrorFallback(ssiVirtualPath, "ssi virtual path must start with a /")}
                end
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
    local minimumCacheControlMaxAge = nil
    local rootCacheControlMaxAge = nil
    if minimizeMaxAge then
        rootCacheControlMaxAge = getMaxAgeDecreasedByAgeOrZeroFromHeaders(res.header)
        minimumCacheControlMaxAge = rootCacheControlMaxAge
        if rootCacheControlMaxAge == 0 then
            rootCacheControlMaxAge = nil
        end
        ngx.log(ngx.DEBUG, "cache-control root: " .. tostring(rootCacheControlMaxAge))
    end

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
        local totalSsiDepth = 0

        local ssiRequests, ssiRequestsCount, ssiMatchesCount = getSsiRequestsAndCount(ssiResponses, body)

        while ssiMatchesCount > 0
        do
            totalSsiDepth = totalSsiDepth + 1
            if (totalSsiDepth > maxSsiDepth or totalSsiIncludesCount > maxSsiIncludes) and ssiMatchesCount > 0
            then
                if (totalSsiDepth > maxSsiDepth)
                then
                    ngx.log(ngx.ERR, "max recursion depth exceeded " .. maxSsiDepth .. "(was " .. totalSsiDepth .. ")")
                else
                    ngx.log(ngx.ERR, "max ssi includes exceeded " .. maxSsiIncludes .. "(was " .. totalSsiIncludesCount .. ")")

                end
                for i,captureRegularExpression in ipairs(captureRegularFileExpressions) do
                    local regularExpression = string.gsub(captureRegularExpression, "([%(%)])", "")

                    local replacer = function(w)
                        local ssiVirtualPath = string.match(w, captureRegularExpression)
                        if (totalSsiDepth > maxSsiDepth)
                        then
                            return generateJsonErrorFallback(ssiVirtualPath, "max recursion depth exceeded " .. maxSsiDepth .. "(was " .. totalSsiDepth .. ")")
                        else
                            return generateJsonErrorFallback(ssiVirtualPath, "max ssi includes exceeded " .. maxSsiIncludes .. "(was " .. totalSsiIncludesCount .. ")")
                        end
                    end

                    body = string.gsub(body, regularExpression, replacer)
                end

                ssiMatchesCount = 0
            else
                if (ssiRequestsCount > 0)
                then
                    -- FIXME: handle ssiRequestsCount > 200, because this is the internal nginx limit
                    -- issue all the requests at once and wait until they all return
                    local resps = { ngx.location.capture_multi(ssiRequests) }

                    -- loop over the responses table
                    for i, resp in ipairs(resps) do
                        --            ngx.log(ngx.DEBUG, "resp ", i, " with ", resp.status, " and body ", resp.body)
                        ngx.log(ngx.DEBUG, "sub request url ", ssiRequests[i][1], " and status ", resp.status)
                        if validateJson and validateJsonInline
                        then
                            if minimizeMaxAge and minimumCacheControlMaxAge ~= nil then
                                local respCacheControlMaxAge = getMaxAgeDecreasedByAgeOrZeroFromHeaders(resp.header)
                                if respCacheControlMaxAge < minimumCacheControlMaxAge then
                                    ngx.log(ngx.DEBUG, "sub request cache-control: " .. tostring(respCacheControlMaxAge))
                                    minimumCacheControlMaxAge = respCacheControlMaxAge
                                end
                            end

                            local bodyWithoutSsiIncludes = resp.body
                            for i,captureRegularExpression in ipairs(captureRegularFileExpressions) do
                                local regularExpression = string.gsub(captureRegularExpression, "([%(%)])", "")
                                bodyWithoutSsiIncludes = string.gsub(bodyWithoutSsiIncludes, regularExpression, "{}")
                            end
                            local value, errorMessage = cjson.decode(bodyWithoutSsiIncludes)
                            if (errorMessage) then
                                resp.body = generateJsonErrorFallback(string.sub(ssiRequests[i][1], string.len(prefix) + 1), errorMessage)
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
        end

        if ngx.status == 200
        then
            local md5 = ngx.md5(body)
            ngx.ctx.etag = '"' .. md5 .. '"'
        end

--        ngx.log(ngx.DEBUG, "ssiRequestsCount", totalSsiSubRequestsCount)
        ngx.ctx.ssiRequestsCount = totalSsiSubRequestsCount
        ngx.ctx.ssiIncludesCount = totalSsiIncludesCount
        ngx.ctx.ssiDepth = totalSsiDepth

        if cjson and validateJson
        then
            local value, errorMessage = cjson.decode(body)
            if errorMessage then
                body = generateJsonErrorFallback(ngx.var.request_uri, errorMessage)

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

   if minimizeMaxAge then
       if minimumCacheControlMaxAge > 0
       then
           ngx.ctx.overrideCacheControl = "max-age=" .. minimumCacheControlMaxAge;
       else
           ngx.ctx.overrideCacheControl = "nocache, max-age=0";
       end
   end

    ngx.ctx.res = res
    ngx.print(body)
end
