local Explorer = {}
local Methods = import("Modules/Explorer")

if not hasMethods(Methods.RequiredMethods) then
    return Explorer
end

return Explorer
