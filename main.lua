local startTime = tick()

local function dump(instance, path, counts)
    local folders, checked = {}, {}
    local scripts = {LocalScript = true, Script = true, ModuleScript = true}
    local remotes = {RemoteEvent = true, RemoteFunction = true, BindableEvent = true, BindableFunction = true}
    local methods = {RemoteFunction = "InvokeServer", BindableEvent = "Fire", BindableFunction = "Invoke"}
    
    if checked[instance] then
        return
    end
    checked[instance], counts = checked[instance] or 1, counts or {}
    local name = instance.Name:gsub('[<>:"/\\|%?%*]', "_")
    counts[name] = (counts[name] or 0) + 1
    if counts[name] > 1 then
        name = name .. counts[name]
    end

    local function getroot(inst)
        local parts = inst:GetFullName():split(".")
        local root = inst
        while root and root.Parent and root.Parent ~= game do
            root = root.Parent
        end
        return parts
    end

    local function folder(folderPath)
        if not folders[folderPath] then
            makefolder(folderPath)
            folders[folderPath] = true
        end
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

            local metadata = {func = 0, variable = 0, require = 0, service = 0, event = 0, remote = 0}

            for line in r:gmatch("[^\r\n]+") do
                line = line:match("%s*(.-)%s*$") or line
                if line:match("function%s+%w+") or line:match("function%s*%(") or line:match("%w+%s*=%s*function") then
                    metadata.func = metadata.func + 1
                end
                if line:match("local%s+%w+%s*=") then
                    metadata.variable = metadata.variable + 1
                end
                if line:match("require%(") then
                    metadata.require = metadata.require + 1
                end
                if line:match("GetService%(") then
                    metadata.service = metadata.service + 1
                end
                if line:match(":Connect%(") or line:match(":Fire%(") or line:match(":Invoke%(") then
                    metadata.event = metadata.event + 1
                end
                if
                    line:match("RemoteEvent") or line:match("RemoteFunction") or line:match("FireServer") or
                        line:match("InvokeServer") or
                        line:match("FireClient")
                 then
                    metadata.remote = metadata.remote + 1
                end
            end

            local header = {
                "-- " .. 'game:GetService("' .. parts[1] .. '")' .. table.concat(parts, "", 2),
                "-- ",
                "-- Functions: " .. metadata.func,
                "-- Variables: " .. metadata.variable,
                "-- Requires: " .. metadata.require,
                "-- Services: " .. metadata.service,
                "-- Events: " .. metadata.event,
                "-- Remotes: " .. metadata.remote,
                "-- ClassName: " .. instance.ClassName
            }

            writefile(path .. name .. ".lua", table.concat(header, "\n") .. "\n\n" .. r)
        end
    elseif remotes[instance.ClassName] then
        folder(path)
        local parts = getroot(instance)
        for i = 2, #parts do
            parts[i] = ':WaitForChild("' .. parts[i] .. '")'
        end

        local header = {
            "-- " .. 'game:GetService("' .. parts[1] .. '")' .. table.concat(parts, "", 2),
            "-- ",
            "-- ClassName: " .. instance.ClassName,
            "-- Method: " .. (methods[instance.ClassName] or "FireServer")
        }

        writefile(
            path .. name .. ".remote",
            table.concat(header, "\n") ..
                "\n\n" ..
                    'game:GetService("' ..
                        parts[1] ..
                            '")' ..
                                table.concat(parts, "", 2) ..
                                    ":" .. (methods[instance.ClassName] or "FireServer") .. "()"
        )
    end

    if scripts[instance.ClassName] or remotes[instance.ClassName] then
        local children = instance:GetChildren()
        if #children > 0 then
            local nextpath = path .. name .. " children/"
            folder(nextpath)
            for _, child in pairs(children) do
                dump(child, nextpath, {})
            end
        end
    else
        for _, child in pairs(instance:GetChildren()) do
            dump(child, path, counts)
        end
    end
end

local function process()
    local basepath = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name:gsub("[^%w%s%-]", ""):gsub("%s+", " "):gsub("%s+$", "") .. "@dumped/"
    if isfolder(basepath) then delfolder(basepath) end
    
    for _, serviceName in ipairs({"ReplicatedFirst", "ReplicatedStorage", "Players", "StarterPlayer"}) do
        pcall(function()
            local service = game:GetService(serviceName)
            if service.Name ~= serviceName then pcall(function() service.Name = serviceName end) end
            local root = basepath .. serviceName .. "/"
            if not isfolder(root) then makefolder(root) end
            for _, child in pairs(service:GetChildren()) do dump(child, root, {}) end
        end)
    end
end

process();print("Dumped in " .. string.format("%.2f", tick() - startTime) .. " seconds")
