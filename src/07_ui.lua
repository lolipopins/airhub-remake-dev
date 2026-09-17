--// ============================================================================
--// AirHub — 07_ui.lua
--//  Loads the UI library and builds the whole menu.
--//  Requires: all other modules loaded first.
--// ============================================================================

local H = getgenv().AirHub
if not H or not H._CoreLoaded then
    warn("[AirHub] 07_ui: core not loaded")
    return
end

local Util = H.Util
local UserInputService = Util.UserInputService
local TeleportService = Util.TeleportService
local HttpService = Util.HttpService
local LocalPlayer = Util.LocalPlayer
local Track = Util.Track
local UntrackAll = Util.UntrackAll
local ShowError = Util.ShowError
local SafeKeyCode = Util.SafeKeyCode
local SanitizeColor = Util.SanitizeColor

local Aimbot = H.Aimbot
local WallHack = H.WallHack
local AntiAim = H.AntiAim
local ServerPosition = H.ServerPosition
local Fly = H.Fly
local Bhop = H.Bhop
local Speed = H.Speed
local FastStop = H.FastStop
local AutoStrafer = H.AutoStrafer
local Noclip = H.Noclip

--// ---------------------------------------------------------------------------
--// Local aliases (from module tables)
--// ---------------------------------------------------------------------------
local CancelLock = Aimbot.CancelLock
local RemoveRayHook = Aimbot.RemoveRayHook
local RemoveMouseHitHook = Aimbot.RemoveMouseHitHook
local RemoveGunHandlerHook = Aimbot.RemoveGunHandlerHook
local ApplyGlowToAll = WallHack.ApplyGlowToAll
local StartServerPosition = ServerPosition.Start
local StopServerPosition = ServerPosition.Stop
local Fly_ClearInstances = Fly.ClearInstances
local AS_ReleaseAll = AutoStrafer.ReleaseAll
local PickNextDelay = AntiAim.PickNextDelay
local StopDesync = AntiAim.StopDesync
local StartDesync = AntiAim.StartDesync
local CleanupAntiAim = AntiAim.CleanupAntiAim
local AA_BIND_NAME = AntiAim.AA_BIND_NAME

local Config_Save = H.Config.Save
local Config_Load = H.Config.Load
local Config_Delete = H.Config.Delete
local Config_ListFiles = H.Config.ListFiles

--// ---------------------------------------------------------------------------
--// Apply enabled states (post-config load)
--// ---------------------------------------------------------------------------
local function ApplyAllEnabledStates()
    local Hg = getgenv().AirHub
    if not Hg then return end

    if WallHack.Settings.Enabled then ApplyGlowToAll() end

    if Hg.AntiAim and Hg.AntiAim.Desync.Settings.Enabled then
        StopDesync()
        task.defer(function()
            if getgenv().AirHub and getgenv().AirHub.AntiAim.Desync.Settings.Enabled then
                StartDesync()
            end
        end)
    else
        StopDesync()
    end

    if Hg.ServerPosition and Hg.ServerPosition.Settings.Enabled then
        StopServerPosition()
        task.defer(function()
            if getgenv().AirHub and getgenv().AirHub.ServerPosition.Settings.Enabled then
                StartServerPosition()
            end
        end)
    else
        StopServerPosition()
    end

    if Hg.Fly then
        Fly_ClearInstances()
        if Hg.Fly.Settings.Enabled and Hg.Fly.Settings.Toggle then
            Hg.Fly.Internal.Active = true
        else
            Hg.Fly.Internal.Active = false
        end
    end

    if Hg.Bhop then
        Hg.Bhop.Internal.KeyHeld = false
        Hg.Bhop.Internal.Active = false
        Hg.Bhop.Internal.SpiderTouching = false
    end
    if Hg.Speed then Hg.Speed.Internal.Active = false end
    if Hg.Noclip then Hg.Noclip.Internal.Active = false end
    if Hg.AutoStrafer then
        AutoStrafer.Internal.Active = false
        AS_ReleaseAll()
    end
    if Hg.FastStop then FastStop.Internal.LastActive = false end
end

--// ---------------------------------------------------------------------------
--// Load UI library (delayed a bit)
--// ---------------------------------------------------------------------------
task.delay(math.random(1, 3), function()
    if H.ShuttingDown then return end
    local Library
    local pcall_ok, err = pcall(function()
        Library = loadstring(game:GetObjects("rbxassetid://7657867786")[1].Source)()
    end)
    if not pcall_ok or not Library then
        ShowError("UI Library failed to load")
        warn("[AirHub] UI Library failed to load: " .. tostring(err))
        return
    end

    local function SafeShow()
        if not Library then return end
        if type(Library.Show) == "function" then pcall(function() Library:Show() end) return end
        if type(Library.Open) == "function" then pcall(function() Library:Open() end) return end
        if type(Library.Toggle) == "function" then pcall(function() Library:Toggle() end) return end
        local mf = rawget(Library, "MainFrame") or rawget(Library, "Window")
        if mf then
            if type(mf.Show) == "function" then pcall(function() mf:Show() end) return end
            if type(mf.Open) == "function" then pcall(function() mf:Open() end) return end
            if type(mf.Visible) == "boolean" then mf.Visible = true end
        end
    end
    local function SafeHide()
        if not Library then return end
        if type(Library.Hide) == "function" then pcall(function() Library:Hide() end) return end
        if type(Library.Close) == "function" then pcall(function() Library:Close() end) return end
        local mf = rawget(Library, "MainFrame") or rawget(Library, "Window")
        if mf then
            if type(mf.Hide) == "function" then pcall(function() mf:Hide() end) return end
            if type(mf.Close) == "function" then pcall(function() mf:Close() end) return end
            if type(mf.Visible) == "boolean" then mf.Visible = false end
        end
    end
    local function SafeUnload()
        if not Library then return end
        if type(Library.Unload) == "function" then pcall(function() Library:Unload() end) return end
        if type(Library.Destroy) == "function" then pcall(function() Library:Destroy() end) return end
    end

    local teamModes = { "Enemies", "Allies", "All", "IgnoreNeutrals" }
    local aaModes = { "Static", "Spin", "Jitter", "Sway" }
    local refModes = { "Camera", "Movement", "Player" }
    local aaMethods = { "CFrame", "BodyGyro", "Motor6D", "AlignOrientation", "AngularVelocity" }
    local bhopKeys = { "Space", "LeftControl", "LeftShift", "C", "X", "Z" }
    local speedMethods = { "WalkSpeed", "CFrame", "Velocity" }
    local glowModes = { "Outline", "Fill", "Both", "Pulse" }
    local silentAimModes = { "Camera", "GunHandler", "RayHook", "MouseHit" }
    local wallCheckModes = { "Fast", "Perfect" }
    local strafeModes = { "Legit", "Spam" }
    local strafeKeys = { "Space", "LeftShift", "LeftControl", "C", "X", "Z", "Q", "E" }
    local flyMethods = { "BodyVelocity", "LinearVelocity", "Velocity", "CFrame" }
    local flyKeys = { "F", "G", "H", "V", "B", "N", "Space", "LeftShift" }
    local desyncModes = { "Random", "OldPosition" }
    local soundIDs = {
        gamesense = 83717596220569, neverlose = 139452805868562,
        crit = 122699784909910, primordial = 97511223764004,
    }

    local function Rejoin() TeleportService:Teleport(game.PlaceId, LocalPlayer) end
    local function ServerHop()
        local ok, data = pcall(function()
            local body
            if type(game.HttpGet) == "function" then
                body = game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=100")
            elseif type(request) == "function" then
                body = request({ Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=100", Method = "GET" }).Body
            end
            return HttpService:JSONDecode(body or "")
        end)
        if not ok or not data then ShowError("ServerHop failed") return end
        local servers = {}
        for _, v in ipairs(data.data or {}) do
            if v.playing and v.id ~= game.JobId then servers[#servers + 1] = v.id end
        end
        if #servers > 0 then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LocalPlayer)
        else
            ShowError("No other servers")
        end
    end

    local MenuVisible = true
    Track(UserInputService.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.KeyCode == Enum.KeyCode.RightShift then
            MenuVisible = not MenuVisible
            if MenuVisible then SafeShow() else SafeHide() end
        end
    end))

    Library.UnloadCallback = function()
        H.ShuttingDown = true

        Aimbot.Settings.Enabled = false
        Aimbot.Settings.AutoShoot.Enabled = false
        Aimbot.FOVSettings.Enabled = false
        WallHack.Settings.Enabled = false
        WallHack.Visuals.BoxSettings.Enabled = false
        WallHack.Visuals.GlowSettings.Enabled = false
        AntiAim.Settings.Enabled = false
        AntiAim.Desync.Settings.Enabled = false
        ServerPosition.Settings.Enabled = false
        Fly.Settings.Enabled = false
        Bhop.Settings.Enabled = false
        Speed.Settings.Enabled = false
        FastStop.Settings.Enabled = false
        AutoStrafer.Settings.Enabled = false
        Noclip.Settings.Enabled = false

        Fly.Internal.Active = false
        Bhop.Internal.KeyHeld = false
        Bhop.Internal.Active = false
        AutoStrafer.Internal.Active = false
        Speed.Internal.Active = false
        Noclip.Internal.Active = false
        FastStop.Internal.LastActive = false

        pcall(function() CancelLock() end)
        pcall(function() Aimbot.FOVCircle:Remove() end)
        pcall(function() WallHack.Functions.Exit() end)
        pcall(StopServerPosition)
        pcall(StopDesync)
        pcall(Fly_ClearInstances)
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.PlatformStand = false
                    if hum.WalkSpeed ~= 16 then hum.WalkSpeed = 16 end
                end
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = true end
                end
            end
        end)
        pcall(function() if AutoStrafer.Internal.KeyA or AutoStrafer.Internal.KeyD then AS_ReleaseAll() end end)
        pcall(RemoveRayHook)
        pcall(RemoveMouseHitHook)
        pcall(RemoveGunHandlerHook)
        pcall(CleanupAntiAim)
        pcall(function() game:GetService("RunService"):UnbindFromRenderStep(AA_BIND_NAME) end)
        pcall(function() H.ErrorText:Remove() end)
        pcall(function() for _, log in ipairs(H.ActiveLogs) do log.text:Remove() end end)
        H.ActiveLogs = {}
        pcall(function() if H.Sounds.Hitsound then H.Sounds.Hitsound:Destroy() end end)
        pcall(function() if H.Sounds.Killsound then H.Sounds.Killsound:Destroy() end end)
        pcall(UntrackAll)

        getgenv().AirHub = nil
        pcall(function()
            local t = Drawing.new("Text")
            t.Text = "AirHub unloaded"
            t.Size = 20
            t.Color = Color3.fromRGB(255, 80, 80)
            t.Center = true
            t.Outline = true
            t.Position = workspace.CurrentCamera.ViewportSize / 2
            task.delay(2, function() t:Remove() end)
        end)
    end

    local MainFrame = Library:CreateWindow({
        Name = "AirHub",
        Themeable = {
            Image = "96742921028995",
            Info = "Strafe Helper | Silent Aim | Ghost | Fly | Configs", Credit = false,
        },
    })

    local AimbotTab = MainFrame:CreateTab({ Name = "Aimbot" })
    local VisualsTab = MainFrame:CreateTab({ Name = "Visuals" })
    local AntiTab = MainFrame:CreateTab({ Name = "Anti-Aim" })
    local MovementTab = MainFrame:CreateTab({ Name = "Movement" })
    local SettingsTab = MainFrame:CreateTab({ Name = "Settings" })

    --// Aimbot tab
    local secA = AimbotTab:CreateSection({ Name = "Main" })
    secA:AddToggle({ Name = "Enabled", Value = Aimbot.Settings.Enabled, Callback = function(v) Aimbot.Settings.Enabled = v end })
    secA:AddToggle({ Name = "Toggle", Value = Aimbot.Settings.Toggle, Callback = function(v) Aimbot.Settings.Toggle = v end })
    secA:AddToggle({ Name = "360° (Ignore FOV)", Value = Aimbot.Settings.IgnoreFOV, Callback = function(v) Aimbot.Settings.IgnoreFOV = v end })
    secA:AddToggle({ Name = "Check visibility from player on TP", Value = Aimbot.Settings.CheckFromPlayerOnTP, Callback = function(v) Aimbot.Settings.CheckFromPlayerOnTP = v end })
    secA:AddDropdown({ Name = "Lock Part", Value = Aimbot.Settings.LockPart, List = { "Head", "Torso", "Nearest" }, Callback = function(v) Aimbot.Settings.LockPart = v end })
    secA:AddToggle({ Name = "Fallback to visible parts", Value = Aimbot.Settings.FallbackToVisible, Callback = function(v) Aimbot.Settings.FallbackToVisible = v end })
    secA:AddTextbox({ Name = "Aim Key (MouseButton1/2 or KeyCode)", Value = Aimbot.Settings.TriggerKey, Callback = function(v) Aimbot.Settings.TriggerKey = v end })
    secA:AddDropdown({ Name = "Aim Method", Value = Aimbot.Settings.AimMethod, List = { "Smooth", "Instant" }, Callback = function(v) Aimbot.Settings.AimMethod = v end })
    secA:AddSlider({ Name = "Smoothing Speed", Value = Aimbot.Settings.AimSmoothingSpeed, Min = 1, Max = 20, Callback = function(v) Aimbot.Settings.AimSmoothingSpeed = v end })

    local predSec = AimbotTab:CreateSection({ Name = "Prediction" })
    predSec:AddToggle({ Name = "Enabled", Value = Aimbot.Settings.PredictionEnabled, Callback = function(v) Aimbot.Settings.PredictionEnabled = v end })
    predSec:AddSlider({ Name = "Prediction X (%)", Value = Aimbot.Settings.PredictionX, Min = -100, Max = 100, Callback = function(v) Aimbot.Settings.PredictionX = v end })
    predSec:AddSlider({ Name = "Prediction Y (%)", Value = Aimbot.Settings.PredictionY, Min = -100, Max = 100, Callback = function(v) Aimbot.Settings.PredictionY = v end })
    predSec:AddSlider({ Name = "Base Time (s)", Value = Aimbot.Settings.PredictionTime, Min = 0.01, Max = 0.5, Decimals = 2, Callback = function(v) Aimbot.Settings.PredictionTime = v end })

    local secW = AimbotTab:CreateSection({ Name = "Visibility", Side = "Right" })
    secW:AddToggle({ Name = "WallCheck", Value = Aimbot.Settings.WallCheck, Callback = function(v) Aimbot.Settings.WallCheck = v end })
    secW:AddDropdown({ Name = "WallCheck Mode", Value = Aimbot.Settings.WallCheckMode, List = wallCheckModes, Callback = function(v) Aimbot.Settings.WallCheckMode = v end })
    secW:AddToggle({ Name = "Delay Shot", Value = Aimbot.Settings.DelayShot, Callback = function(v) Aimbot.Settings.DelayShot = v end })
    secW:AddToggle({ Name = "Alive Check", Value = Aimbot.Settings.AliveCheck, Callback = function(v) Aimbot.Settings.AliveCheck = v end })
    secW:AddToggle({ Name = "Team Check", Value = Aimbot.Settings.TeamCheck.Enabled, Callback = function(v) Aimbot.Settings.TeamCheck.Enabled = v end })
    secW:AddDropdown({ Name = "Team Mode", Value = Aimbot.Settings.TeamCheck.Mode, List = teamModes, Callback = function(v) Aimbot.Settings.TeamCheck.Mode = v end })
    secW:AddToggle({ Name = "Treat Neutrals as Enemies", Value = Aimbot.Settings.TeamCheck.TreatNeutralAsEnemy, Callback = function(v) Aimbot.Settings.TeamCheck.TreatNeutralAsEnemy = v end })

    local secD = AimbotTab:CreateSection({ Name = "Silent Aim", Side = "Right" })
    secD:AddToggle({ Name = "Enabled", Value = Aimbot.Settings.SilentAim, Callback = function(v) Aimbot.Settings.SilentAim = v end })
    secD:AddDropdown({ Name = "Mode", Value = Aimbot.Settings.SilentAimMode, List = silentAimModes, Callback = function(v)
        Aimbot.Settings.SilentAimMode = v
        if v ~= "RayHook" then RemoveRayHook() end
        if v ~= "MouseHit" then RemoveMouseHitHook() end
    end })

    local secAS = AimbotTab:CreateSection({ Name = "Auto Shoot", Side = "Right" })
    secAS:AddToggle({ Name = "Enabled", Value = Aimbot.Settings.AutoShoot.Enabled, Callback = function(v) Aimbot.Settings.AutoShoot.Enabled = v end })
    secAS:AddToggle({ Name = "Only when aiming", Value = Aimbot.Settings.AutoShoot.OnlyWhenAiming, Callback = function(v) Aimbot.Settings.AutoShoot.OnlyWhenAiming = v end })
    secAS:AddTextbox({ Name = "Manual delay (s)", Value = tostring(Aimbot.Settings.AutoShoot.FireRate), Callback = function(v)
        local num = tonumber(v)
        if num then Aimbot.Settings.AutoShoot.FireRate = math.clamp(num, 0.001, 1) end
    end })
    secAS:AddDropdown({ Name = "Shoot Key", Value = "Left Click", List = { "Left Click", "Right Click" }, Callback = function(v)
        Aimbot.Settings.AutoShoot.ShootKey = (v == "Left Click") and "MouseButton1" or "MouseButton2"
    end })
    secAS:AddToggle({ Name = "AutoStop", Value = Aimbot.Settings.AutoShoot.AutoStop.Enabled, Callback = function(v) Aimbot.Settings.AutoShoot.AutoStop.Enabled = v end })
    secAS:AddSlider({ Name = "Stop time (s)", Value = Aimbot.Settings.AutoShoot.AutoStop.Time, Min = 0.01, Max = 0.5, Decimals = 2, Callback = function(v) Aimbot.Settings.AutoShoot.AutoStop.Time = v end })

    local secE = AimbotTab:CreateSection({ Name = "FOV" })
    secE:AddToggle({ Name = "Enabled", Value = Aimbot.FOVSettings.Enabled, Callback = function(v) Aimbot.FOVSettings.Enabled = v end })
    secE:AddToggle({ Name = "Visible", Value = Aimbot.FOVSettings.Visible, Callback = function(v) Aimbot.FOVSettings.Visible = v end })
    secE:AddSlider({ Name = "Radius", Value = Aimbot.FOVSettings.Amount, Min = 10, Max = 300, Callback = function(v) Aimbot.FOVSettings.Amount = v end })

    --// Visuals tab
    local vis1 = VisualsTab:CreateSection({ Name = "WallHack" })
    vis1:AddToggle({ Name = "Enabled", Value = WallHack.Settings.Enabled, Callback = function(v) WallHack.Settings.Enabled = v; ApplyGlowToAll() end })
    vis1:AddToggle({ Name = "Team Check", Value = WallHack.Settings.TeamCheck, Callback = function(v) WallHack.Settings.TeamCheck = v end })
    vis1:AddToggle({ Name = "Alive Check", Value = WallHack.Settings.AliveCheck, Callback = function(v) WallHack.Settings.AliveCheck = v end })

    local visBox = VisualsTab:CreateSection({ Name = "Boxes" })
    visBox:AddToggle({ Name = "Enabled", Value = WallHack.Visuals.BoxSettings.Enabled, Callback = function(v) WallHack.Visuals.BoxSettings.Enabled = v end })
    visBox:AddDropdown({ Name = "Type", Value = (WallHack.Visuals.BoxSettings.Type == 1 and "3D" or "2D"), List = { "3D", "2D" }, Callback = function(v) WallHack.Visuals.BoxSettings.Type = (v == "3D") and 1 or 2 end })
    visBox:AddColorpicker({ Name = "Color", Value = WallHack.Visuals.BoxSettings.Color, Callback = function(v) WallHack.Visuals.BoxSettings.Color = SanitizeColor(v) end })
    visBox:AddColorpicker({ Name = "Target Color", Value = WallHack.Visuals.BoxSettings.TargetColor, Callback = function(v) WallHack.Visuals.BoxSettings.TargetColor = SanitizeColor(v) end })
    visBox:AddSlider({ Name = "Transparency", Value = WallHack.Visuals.BoxSettings.Transparency, Min = 0, Max = 1, Decimals = 2, Callback = function(v) WallHack.Visuals.BoxSettings.Transparency = v end })
    visBox:AddSlider({ Name = "Thickness", Value = WallHack.Visuals.BoxSettings.Thickness, Min = 1, Max = 5, Callback = function(v) WallHack.Visuals.BoxSettings.Thickness = v end })
    visBox:AddToggle({ Name = "Filled (2D)", Value = WallHack.Visuals.BoxSettings.Filled, Callback = function(v) WallHack.Visuals.BoxSettings.Filled = v end })
    visBox:AddSlider({ Name = "Scale (3D)", Value = WallHack.Visuals.BoxSettings.Increase, Min = 1, Max = 5, Callback = function(v) WallHack.Visuals.BoxSettings.Increase = v end })

    local glowSec = VisualsTab:CreateSection({ Name = "Glow", Side = "Right" })
    glowSec:AddToggle({ Name = "Enabled", Value = WallHack.Visuals.GlowSettings.Enabled, Callback = function(v)
        WallHack.Visuals.GlowSettings.Enabled = v
        ApplyGlowToAll()
    end })
    glowSec:AddColorpicker({ Name = "Color", Value = WallHack.Visuals.GlowSettings.Color, Callback = function(v)
        WallHack.Visuals.GlowSettings.Color = SanitizeColor(v)
        ApplyGlowToAll()
    end })
    glowSec:AddSlider({ Name = "Transparency", Value = WallHack.Visuals.GlowSettings.Transparency, Min = 0, Max = 1, Decimals = 2, Callback = function(v)
        local n = tonumber(v)
        if n then WallHack.Visuals.GlowSettings.Transparency = math.clamp(n, 0, 1) end
        ApplyGlowToAll()
    end })
    glowSec:AddDropdown({ Name = "Mode", Value = WallHack.Visuals.GlowSettings.Mode, List = glowModes, Callback = function(v)
        if type(v) == "string" then WallHack.Visuals.GlowSettings.Mode = v
        else WallHack.Visuals.GlowSettings.Mode = "Outline" end
        ApplyGlowToAll()
    end })

    local spSec = VisualsTab:CreateSection({ Name = "Server Position (Ghost)", Side = "Right" })
    spSec:AddToggle({ Name = "Enabled", Value = ServerPosition.Settings.Enabled, Callback = function(v)
        ServerPosition.Settings.Enabled = v
        if v then StopServerPosition(); StartServerPosition() else StopServerPosition() end
    end })
    spSec:AddToggle({ Name = "RGB Color", Value = ServerPosition.Settings.RGB, Callback = function(v) ServerPosition.Settings.RGB = v end })
    spSec:AddSlider({ Name = "Strength", Value = ServerPosition.Settings.Strength, Min = 0, Max = 5, Decimals = 1, Callback = function(v) ServerPosition.Settings.Strength = v end })
    spSec:AddSlider({ Name = "Max Limb Distance", Value = ServerPosition.Settings.MaxLimb, Min = 1, Max = 20, Callback = function(v) ServerPosition.Settings.MaxLimb = v end })

    --// Anti-Aim tab
    local aaMain = AntiTab:CreateSection({ Name = "Body (Server)" })
    aaMain:AddToggle({ Name = "Enabled", Value = AntiAim.Settings.Enabled, Callback = function(v) AntiAim.Settings.Enabled = v end })
    aaMain:AddDropdown({ Name = "Mode", Value = AntiAim.Settings.Mode, List = aaModes, Callback = function(v) AntiAim.Settings.Mode = v end })
    aaMain:AddDropdown({ Name = "Method", Value = AntiAim.Settings.Method, List = aaMethods, Callback = function(v) AntiAim.Settings.Method = v end })
    aaMain:AddDropdown({ Name = "Reference", Value = AntiAim.Settings.Body.Reference, List = refModes, Callback = function(v) AntiAim.Settings.Body.Reference = v end })
    aaMain:AddSlider({ Name = "Yaw", Value = AntiAim.Settings.Body.Yaw, Min = -180, Max = 180, Callback = function(v) AntiAim.Settings.Body.Yaw = v end })
    aaMain:AddTextbox({ Name = "Spin Speed", Value = tostring(AntiAim.Settings.Body.SpinSpeed), Callback = function(v)
        local num = tonumber(v)
        if num then AntiAim.Settings.Body.SpinSpeed = num end
    end })
    aaMain:AddTextbox({ Name = "Jitter Amount", Value = tostring(AntiAim.Settings.Body.JitterAmount), Callback = function(v)
        local num = tonumber(v)
        if num then AntiAim.Settings.Body.JitterAmount = num end
    end })
    aaMain:AddTextbox({ Name = "Jitter Speed", Value = tostring(AntiAim.Settings.Body.JitterSpeed), Callback = function(v)
        local num = tonumber(v)
        if num then AntiAim.Settings.Body.JitterSpeed = num end
    end })
    aaMain:AddSlider({ Name = "Sway Amount", Value = AntiAim.Settings.Body.SwayAmount, Min = 0, Max = 90, Callback = function(v) AntiAim.Settings.Body.SwayAmount = v end })
    aaMain:AddSlider({ Name = "Sway Speed", Value = AntiAim.Settings.Body.SwaySpeed, Min = 0.1, Max = 10, Decimals = 1, Callback = function(v) AntiAim.Settings.Body.SwaySpeed = v end })
    aaMain:AddToggle({ Name = "Ignore when moving", Value = AntiAim.Settings.Body.IgnoreMoving, Callback = function(v) AntiAim.Settings.Body.IgnoreMoving = v end })
    aaMain:AddSlider({ Name = "Move speed threshold", Value = AntiAim.Settings.Body.MoveSpeedThreshold, Min = 0.1, Max = 5, Decimals = 2, Callback = function(v) AntiAim.Settings.Body.MoveSpeedThreshold = v end })

    local desyncSec = AntiTab:CreateSection({ Name = "Desync (Client)", Side = "Right" })
    desyncSec:AddToggle({ Name = "Enabled", Value = AntiAim.Desync.Settings.Enabled, Callback = function(v)
        AntiAim.Desync.Settings.Enabled = v
        if v then StartDesync() else StopDesync() end
    end })
    desyncSec:AddDropdown({ Name = "Mode", Value = AntiAim.Desync.Settings.Mode, List = desyncModes, Callback = function(v)
        AntiAim.Desync.Settings.Mode = v
        if AntiAim.Desync.Settings.Enabled then
            StopDesync()
            task.wait(0.05)
            StartDesync()
        end
    end })
    desyncSec:AddSlider({ Name = "X Radius", Value = AntiAim.Desync.Settings.RadiusX, Min = -100, Max = 100, Callback = function(v) AntiAim.Desync.Settings.RadiusX = v end })
    desyncSec:AddSlider({ Name = "Y Radius", Value = AntiAim.Desync.Settings.RadiusY, Min = -100, Max = 100, Callback = function(v) AntiAim.Desync.Settings.RadiusY = v end })
    desyncSec:AddSlider({ Name = "Z Radius", Value = AntiAim.Desync.Settings.RadiusZ, Min = -100, Max = 100, Callback = function(v) AntiAim.Desync.Settings.RadiusZ = v end })
    desyncSec:AddSlider({ Name = "Update Interval", Value = AntiAim.Desync.Settings.UpdateInterval, Min = 0.01, Max = 1, Decimals = 2, Callback = function(v) AntiAim.Desync.Settings.UpdateInterval = v end })
    desyncSec:AddSlider({ Name = "Smoothness", Value = AntiAim.Desync.Settings.Smoothness, Min = 0.01, Max = 1, Decimals = 2, Callback = function(v) AntiAim.Desync.Settings.Smoothness = v end })
    desyncSec:AddToggle({ Name = "Only In Air", Value = AntiAim.Desync.Settings.OnlyInAir, Callback = function(v) AntiAim.Desync.Settings.OnlyInAir = v end })
    desyncSec:AddToggle({ Name = "Not In Air", Value = AntiAim.Desync.Settings.NotInAir, Callback = function(v) AntiAim.Desync.Settings.NotInAir = v end })
    desyncSec:AddToggle({ Name = "Freeze Old Position", Value = AntiAim.Desync.Settings.FreezeOldPos, Callback = function(v) AntiAim.Desync.Settings.FreezeOldPos = v end })
    desyncSec:AddToggle({ Name = "Random Delay (Old Position)", Value = AntiAim.Desync.Settings.RandomDelayEnabled, Callback = function(v)
        AntiAim.Desync.Settings.RandomDelayEnabled = v
        AntiAim.Desync.Internal.OldPosTimer = 0
        AntiAim.Desync.Internal.NextUpdate = PickNextDelay(AntiAim.Desync.Settings)
    end })
    desyncSec:AddSlider({ Name = "Delay Min (s)", Value = AntiAim.Desync.Settings.AutoUpdateMin, Min = 0, Max = 5, Decimals = 2, Callback = function(v)
        local n = tonumber(v) or 0.2
        AntiAim.Desync.Settings.AutoUpdateMin = n
        if AntiAim.Desync.Settings.AutoUpdateMax < n then
            AntiAim.Desync.Settings.AutoUpdateMax = n
        end
    end })
    desyncSec:AddSlider({ Name = "Delay Max (s)", Value = AntiAim.Desync.Settings.AutoUpdateMax, Min = 0, Max = 10, Decimals = 2, Callback = function(v)
        local n = tonumber(v) or 1.0
        AntiAim.Desync.Settings.AutoUpdateMax = n
        if AntiAim.Desync.Settings.AutoUpdateMin > n then
            AntiAim.Desync.Settings.AutoUpdateMin = n
        end
    end })
    desyncSec:AddToggle({
        Name = "Refresh position on shot (OldPosition
