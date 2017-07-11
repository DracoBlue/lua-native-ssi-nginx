ngx = {
    log = function() end,
    var = { ssi_api_gateway_prefix = "/ssi-api-gateway", request_uri = "/lua-test", request_method = "GET" },
    req = { read_body = function() end, get_body_data = function() end },
    location = { capture = function() end }
}

local assertTable = function(actual, expected, message)
    for k,v in pairs(actual)
    do
        assert(expected[k] == v, message or ("for key '" .. tostring(k) .. "' '" .. tostring(expected[k]) .. "' expected, but '" .. tostring(v) .. "' given"))
    end
    for k,v in pairs(expected)
    do
        assert(actual[k] == v, message or ("for key '" .. tostring(k) .. "' '" .. tostring(v) .. "' expected, but '" .. tostring(actual[k]) .. "' given"))
    end
end

dofile("./src/lua-ssi-content.lua")

assertTable(
    getCacheControlFieldsFromHeaders(
        {
            cache_control = 'stale-while-revalidate="124",max-age=123,stale-if-error=123,public,private'
        }
    ),
    {
        ['stale-while-revalidate']="124",
        ['max-age']="123",
        ['stale-if-error']="123",
        ['public']=true,
        ['private']=true,
    }
)

assertTable(
    getCacheControlFieldsFromHeaders(
        {
            cache_control = 'stale-while-revalidate="124",max-age=123,private'
        }
    ),
    {
        ['stale-while-revalidate']="124",
        ['max-age']="123",
        ['private']=true,
    }
)

assertTable(
    getCacheControlFieldsFromHeaders(
        {
            cache_control = 'stale-while-revalidate="124", max-age=123, private'
        }
    ),
    {
        ['stale-while-revalidate']="124",
        ['max-age']="123",
        ['private']=true,
    }
)

assertTable(
    getCacheControlFieldsFromHeaders(
        {
            cache_control = 'stale-while-revalidate="124"'
        }
    ),
    {
        ['stale-while-revalidate']="124"
    }
)
