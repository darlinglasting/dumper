local folders, checked, canonicalServiceNames = {}, {}, {}
local scripts = {LocalScript = true, Script = true, ModuleScript = true}
local remotes = {RemoteEvent = true, RemoteFunction = true, BindableEvent = true, BindableFunction = true}
local methods = {RemoteFunction = "InvokeServer", BindableEvent = "Fire", BindableFunction = "Invoke"}
local startTime = tick()

local function getroot(instance)
    local parts = instance:GetFullName():split(".")
    local root = instance
    while root and root.Parent and root.Parent ~= game do
        root = root.Parent
    end
    if root and canonicalServiceNames[root] then
        parts[1] = canonicalServiceNames[root]
    elseif root then
        parts[1] = root.Name
    end
    return parts
end

local function folder(path)
    if folders[path] then
        return
    end
    makefolder(path)
    folders[path] = true
end
local function dump(instance, path, counts)
    if checked[instance] then
        return
    end
    checked[instance], counts = checked[instance] or 1, counts or {}
    local name = instance.Name:gsub('[<>:"/\\|%?%*]', "_")
    counts[name] = (counts[name] or 0) + 1
    if counts[name] > 1 then
        name = name .. counts[name]
    end

    if scripts[instance.ClassName] then
        local s, r =
            pcall(
            function()
                return instance.Source
            end
        )
        if not (s and r and r ~= "") and decompile then
            s, r = pcall(decompile, instance)
        end
        if s and r and r ~= "" then
            local parts = getroot(instance)
            for i = 2, #parts do
                parts[i] = "." .. parts[i]
            end
            writefile(
                path .. name .. ".lua",
                "-- " .. 'game:GetService("' .. parts[1] .. '")' .. table.concat(parts, "", 2) .. "\n\n" .. r
            )
        end
    elseif remotes[instance.ClassName] then
        folder(path)
        local parts = getroot(instance)
        for i = 2, #parts do
            parts[i] = ':WaitForChild("' .. parts[i] .. '")'
        end
        writefile(
            path .. name .. ".remote",
            'game:GetService("' ..
                parts[1] ..
                    '")' .. table.concat(parts, "", 2) .. ":" .. (methods[instance.ClassName] or "FireServer") .. "()"
        )
    end

    if scripts[instance.ClassName] or remotes[instance.ClassName] then
        local nextpath = path .. name .. " children/"
        folder(nextpath)
        for _, child in pairs(instance:GetChildren()) do
            dump(child, nextpath, {})
        end
    else
        for _, child in pairs(instance:GetChildren()) do
            dump(child, path, counts)
        end
    end
end

local basepath =
    game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name:gsub("[^%w%s%-]", ""):gsub("%s+", " "):gsub(
    "%s+$",
    ""
) .. "@dumped/"
if isfolder(basepath) then
    delfolder(basepath)
end

for _, serviceName in ipairs({"ReplicatedFirst", "ReplicatedStorage", "Players", "StarterPlayer"}) do
    pcall(
        function()
            local service = game:GetService(serviceName)
            canonicalServiceNames[service] = serviceName
            if service.Name ~= serviceName then
                pcall(
                    function()
                        service.Name = serviceName
                    end
                )
            end
            local rootpath = basepath .. serviceName .. "/"
            folder(rootpath)
            for _, child in pairs(service:GetChildren()) do
                dump(child, rootpath, {})
            end
        end
    )
end

local time = tick() - startTime
print("Dumped in " .. string.format("%.2f", time) .. " seconds")
