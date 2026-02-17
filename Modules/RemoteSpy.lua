local RemoteSpy = {}

-- [ОТЛАДКА] Проверка наличия библиотеки 'oh'
if not oh then
    warn("<OH> КРИТИЧЕСКАЯ ОШИБКА: Глобальная таблица 'oh' не найдена!")
end

-- [ОТЛАДКА] Проверка импорта объекта Remote
local Remote = import("Objects/Remote")
if type(Remote) ~= "table" then
    warn("<OH> ОШИБКА ИМПОРТА: Objects/Remote вернул " .. type(Remote) .. " вместо таблицы. Проверь файл Objects/Remote.lua на наличие 'return Remote'!")
elseif not Remote.new then
    warn("<OH> ОШИБКА: В таблице Remote отсутствует конструктор .new!")
end

-- [ОТЛАДКА] Проверка методов инжектора
local function checkMethod(name)
    local func = getgenv()[name] or _G[name]
    if not func then
        warn("<OH> ОТСУТСТВУЕТ МЕТОД ИНЖЕКТОРА: " .. name .. ". Проверь Init.lua и совместимость твоего чита!")
        return nil
    end
    return func
end

local _hookMetaMethod = checkMethod("hookMetaMethod")
local _getNamecallMethod = checkMethod("getNamecallMethod")
local _getCallingScript = checkMethod("getCallingScript")
local _getInfo = checkMethod("getInfo")
local _hookFunction = checkMethod("hookFunction")
local _newCClosure = checkMethod("newCClosure")

local requiredMethods = {
    ["checkCaller"] = true,
    ["newCClosure"] = true,
    ["hookFunction"] = true,
    ["isReadOnly"] = true,
    ["setReadOnly"] = true,
    ["getInfo"] = true,
    ["getMetatable"] = true,
    ["setClipboard"] = true,
    ["getNamecallMethod"] = true,
    ["getCallingScript"] = true,
}

local remoteMethods = {
    FireServer = true,
    InvokeServer = true,
    Fire = true,
    Invoke = true
}

local remotesViewing = {
    RemoteEvent = true,
    RemoteFunction = false,
    BindableEvent = false,
    BindableFunction = false
}

local methodHooks = {
    RemoteEvent = Instance.new("RemoteEvent").FireServer,
    RemoteFunction = Instance.new("RemoteFunction").InvokeServer,
    BindableEvent = Instance.new("BindableEvent").Fire,
    BindableFunction = Instance.new("BindableFunction").Invoke
}

local currentRemotes = {}
local remoteDataEvent = Instance.new("BindableEvent")
local eventSet = false

local function connectEvent(callback)
    remoteDataEvent.Event:Connect(callback)
    if not eventSet then
        eventSet = true
    end
end

-- Основной хук __namecall
local nmcTrampoline
if _hookMetaMethod then
    nmcTrampoline = _hookMetaMethod(game, "__namecall", function(...)
        local instance = ...
        if typeof(instance) ~= "Instance" then
            return nmcTrampoline(...)
        end

        local method = _getNamecallMethod()

        if method == "fireServer" or method == "FireServer" then
            method = "FireServer"
        elseif method == "invokeServer" or method == "InvokeServer" then
            method = "InvokeServer"
        end
            
        if remotesViewing[instance.ClassName] and instance ~= remoteDataEvent and remoteMethods[method] then
            local remote = currentRemotes[instance]
            local vargs = {select(2, ...)}
                
            if not remote and Remote then
                remote = Remote.new(instance)
                currentRemotes[instance] = remote
            end

            if remote then
                local remoteIgnored = remote.Ignored
                local remoteBlocked = remote.Blocked
                local argsIgnored = remote.AreArgsIgnored(remote, vargs)
                local argsBlocked = remote.AreArgsBlocked(remote, vargs)

                if eventSet and (not remoteIgnored and not argsIgnored) then
                    local call = {
                        script = _getCallingScript((PROTOSMASHER_LOADED ~= nil and 2) or nil),
                        args = vargs,
                        func = _getInfo(3).func
                    }

                    remote.IncrementCalls(remote, call)
                    remoteDataEvent.Fire(remoteDataEvent, instance, call)
                end

                if remoteBlocked or argsBlocked then
                    return
                end
            end
        end

        return nmcTrampoline(...)
    end)
end

-- Хуки методов через hookFunction
local pcall = pcall
local function checkPermission(instance)
    if (instance.ClassName) then end
end

for _name, hook in pairs(methodHooks) do
    local originalMethod
    if _hookFunction and _newCClosure then
        originalMethod = _hookFunction(hook, _newCClosure(function(...)
            local instance = ...
            if typeof(instance) ~= "Instance" then
                return originalMethod(...)
            end
                    
            local success = pcall(checkPermission, instance)
            if (not success) then return originalMethod(...) end

            if instance.ClassName == _name and remotesViewing[instance.ClassName] and instance ~= remoteDataEvent then
                local remote = currentRemotes[instance]
                local vargs = {select(2, ...)}

                if not remote and Remote then
                    remote = Remote.new(instance)
                    currentRemotes[instance] = remote
                end

                if remote then
                    local remoteIgnored = remote.Ignored 
                    local argsIgnored = remote:AreArgsIgnored(vargs)
                    
                    if eventSet and (not remoteIgnored and not argsIgnored) then
                        local call = {
                            script = _getCallingScript((PROTOSMASHER_LOADED ~= nil and 2) or nil),
                            args = vargs,
                            func = _getInfo(3).func
                        }
            
                        remote:IncrementCalls(call)
                        remoteDataEvent:Fire(instance, call)
                    end

                    if remote.Blocked or remote:AreArgsBlocked(vargs) then
                        return
                    end
                end
            end
            
            return originalMethod(...)
        end))

        if oh.Hooks then
            oh.Hooks[originalMethod] = hook
        end
    end
end

RemoteSpy.RemotesViewing = remotesViewing
RemoteSpy.CurrentRemotes = currentRemotes
RemoteSpy.ConnectEvent = connectEvent
RemoteSpy.RequiredMethods = requiredMethods

return RemoteSpy
