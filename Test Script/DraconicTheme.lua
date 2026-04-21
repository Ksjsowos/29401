-- DraconicTheme.lua
-- Host this file and load it with: loadstring(game:HttpGet("YOUR_URL"))()

local ThemeModule = {}
ThemeModule.ThemeName = "DraconicButtons"
ThemeModule._animConnection = nil
ThemeModule._animTime = 0

function ThemeModule.BuildTheme(accentColor)
    local accent = accentColor or Color3.fromRGB(255, 0, 0)

    return {
        Name = ThemeModule.ThemeName,
        Accent = accent,

        AcrylicMain = Color3.fromRGB(22, 22, 22),
        AcrylicBorder = Color3.fromRGB(50, 10, 10),
        AcrylicGradient = ColorSequence.new(Color3.fromRGB(12, 12, 12), Color3.fromRGB(26, 8, 8)),
        AcrylicNoise = 0.92,

        TitleBarLine = Color3.fromRGB(70, 20, 20),
        Tab = Color3.fromRGB(110, 25, 25),

        Element = Color3.fromRGB(85, 20, 20),
        ElementBorder = Color3.fromRGB(30, 30, 30),
        InElementBorder = Color3.fromRGB(125, 35, 35),
        ElementTransparency = 0.84,

        ToggleSlider = Color3.fromRGB(120, 40, 40),
        ToggleToggled = Color3.fromRGB(0, 0, 0),

        SliderRail = Color3.fromRGB(130, 35, 35),

        DropdownFrame = Color3.fromRGB(150, 35, 35),
        DropdownHolder = Color3.fromRGB(28, 18, 18),
        DropdownBorder = Color3.fromRGB(40, 20, 20),
        DropdownOption = Color3.fromRGB(120, 40, 40),

        Keybind = Color3.fromRGB(120, 40, 40),

        Input = Color3.fromRGB(140, 40, 40),
        InputFocused = Color3.fromRGB(10, 10, 10),
        InputIndicator = Color3.fromRGB(170, 60, 60),

        Dialog = Color3.fromRGB(32, 16, 16),
        DialogHolder = Color3.fromRGB(24, 10, 10),
        DialogHolderLine = Color3.fromRGB(35, 15, 15),
        DialogButton = Color3.fromRGB(50, 18, 18),
        DialogButtonBorder = Color3.fromRGB(100, 35, 35),
        DialogBorder = Color3.fromRGB(90, 30, 30),
        DialogInput = Color3.fromRGB(45, 15, 15),
        DialogInputLine = Color3.fromRGB(180, 50, 50),

        Text = Color3.fromRGB(245, 245, 245),
        SubText = Color3.fromRGB(210, 180, 180),
        Hover = Color3.fromRGB(145, 35, 35),
        HoverChange = 0.07,
    }
end

function ThemeModule.StopAnimation()
    if ThemeModule._animConnection then
        ThemeModule._animConnection:Disconnect()
        ThemeModule._animConnection = nil
    end
end

function ThemeModule.StartAnimation(runService, onThemeUpdate)
    ThemeModule.StopAnimation()
    ThemeModule._animTime = 0

    ThemeModule._animConnection = runService.RenderStepped:Connect(function(delta)
        ThemeModule._animTime = ThemeModule._animTime + ((delta or 0) * 2.5)
        local pulse = (math.sin(ThemeModule._animTime) + 1) * 0.5
        local minRed, maxRed = 120, 255
        local accent = Color3.fromRGB(math.floor(minRed + (maxRed - minRed) * pulse), 0, 0)

        if onThemeUpdate then
            onThemeUpdate(ThemeModule.BuildTheme(accent))
        end
    end)
end

return ThemeModule
