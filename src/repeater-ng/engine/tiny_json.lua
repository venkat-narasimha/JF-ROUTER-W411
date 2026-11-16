-- /pfrm2.0/share/lua/5.1/tiny_json.lua
-- Pure Lua 5.1 JSON Decoder/Encoder without unsafe load() or external C dependencies
local tiny_json = {}

local function kind_of(obj)
    if type(obj) ~= 'table' then return type(obj) end
    local i = 1
    for _ in pairs(obj) do
        if obj[i] ~= nil then i = i + 1 else return 'table' end
    end
    if i == 1 then return 'empty_table' else return 'array' end
end

local function escape_str(s)
    local in_char  = {'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'}
    local out_char = {'\\', '"', '/',  'b',  'f',  'n',  'r',  't'}
    for i, c in ipairs(in_char) do
        s = s:gsub(c, '\\' .. out_char[i])
    end
    return s
end

function tiny_json.encode(val)
    local kind = kind_of(val)
    if kind == 'array' then
        local parts = {}
        for _, v in ipairs(val) do
            table.insert(parts, tiny_json.encode(v))
        end
        return '[' .. table.concat(parts, ',') .. ']'
    elseif kind == 'table' or kind == 'empty_table' then
        local parts = {}
        for k, v in pairs(val) do
            table.insert(parts, '"' .. escape_str(tostring(k)) .. '":' .. tiny_json.encode(v))
        end
        return '{' .. table.concat(parts, ',') .. '}'
    elseif kind == 'string' then
        return '"' .. escape_str(val) .. '"'
    elseif kind == 'number' then
        return tostring(val)
    elseif kind == 'boolean' then
        return val and "true" or "false"
    elseif kind == 'nil' then
        return "null"
    else
        return '"' .. tostring(val) .. '"'
    end
end

local function skip_whitespace(str, pos)
    local _, p = str:find("^[ \t\r\n]*", pos)
    return p + 1
end

local parse_value

local function parse_string(str, pos)
    local end_pos = pos + 1
    local res = {}
    while end_pos <= #str do
        local c = str:sub(end_pos, end_pos)
        if c == '"' then
            return table.concat(res), end_pos + 1
        elseif c == '\\' then
            end_pos = end_pos + 1
            local next_c = str:sub(end_pos, end_pos)
            if next_c == 'n' then table.insert(res, '\n')
            elseif next_c == 'r' then table.insert(res, '\r')
            elseif next_c == 't' then table.insert(res, '\t')
            elseif next_c == 'b' then table.insert(res, '\b')
            elseif next_c == 'f' then table.insert(res, '\f')
            elseif next_c == '"' or next_c == '\\' or next_c == '/' then table.insert(res, next_c)
            else table.insert(res, next_c)
            end
        else
            table.insert(res, c)
        end
        end_pos = end_pos + 1
    end
    error("Unterminated string starting at position " .. pos)
end

local function parse_number(str, pos)
    local _, end_pos, num_str = str:find("^([%-]?[%d]+%.?[%d]*[eE]?[%+%-]?%d*)", pos)
    if not num_str or num_str == "" or num_str == "-" then
        error("Malformed number at position " .. pos)
    end
    return tonumber(num_str), end_pos + 1
end

local function parse_array(str, pos)
    local arr = {}
    pos = skip_whitespace(str, pos + 1)
    if str:sub(pos, pos) == ']' then return arr, pos + 1 end
    while pos <= #str do
        local val
        val, pos = parse_value(str, pos)
        table.insert(arr, val)
        pos = skip_whitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == ']' then return arr, pos + 1
        elseif c == ',' then pos = skip_whitespace(str, pos + 1)
        else error("Expected ']' or ',' at position " .. pos) end
    end
    error("Unterminated array")
end

local function parse_object(str, pos)
    local obj = {}
    pos = skip_whitespace(str, pos + 1)
    if str:sub(pos, pos) == '}' then return obj, pos + 1 end
    while pos <= #str do
        if str:sub(pos, pos) ~= '"' then error("Expected string key at position " .. pos) end
        local key
        key, pos = parse_string(str, pos)
        pos = skip_whitespace(str, pos)
        if str:sub(pos, pos) ~= ':' then error("Expected ':' at position " .. pos) end
        pos = skip_whitespace(str, pos + 1)
        local val
        val, pos = parse_value(str, pos)
        obj[key] = val
        pos = skip_whitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == '}' then return obj, pos + 1
        elseif c == ',' then pos = skip_whitespace(str, pos + 1)
        else error("Expected '}' or ',' at position " .. pos) end
    end
    error("Unterminated object")
end

parse_value = function(str, pos)
    pos = skip_whitespace(str, pos)
    local c = str:sub(pos, pos)
    if c == '{' then return parse_object(str, pos)
    elseif c == '[' then return parse_array(str, pos)
    elseif c == '"' then return parse_string(str, pos)
    elseif c == 't' and str:sub(pos, pos + 3) == "true" then return true, pos + 4
    elseif c == 'f' and str:sub(pos, pos + 4) == "false" then return false, pos + 5
    elseif c == 'n' and str:sub(pos, pos + 3) == "null" then return nil, pos + 4
    elseif c:find("[%-%d]") then return parse_number(str, pos)
    else error("Unexpected character '" .. c .. "' at position " .. pos) end
end

function tiny_json.decode(str)
    if type(str) ~= 'string' then return nil, "Expected string" end
    local ok, res, pos = pcall(parse_value, str, 1)
    if not ok then return nil, res end
    return res
end

return tiny_json
