script_name('MiningBTC Helper v3.3 Beta')
local imgui = require('mimgui')
local encoding = require('encoding')
local sampev = require("lib.samp.events")
local vkeys = require('vkeys')
local vkeys = require 'vkeys'
require 'lib.moonloader'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Настройки и состояние
local active = false
local currentStep = 1
local currentHouse = 0
local totalBTC = 0 
local maxHouses = 15
local targetTime = nil
local isWaiting = false
local btcRate = 0
local gpu_indexes = {1, 2, 3, 4, 7, 8, 9, 10, 13, 14, 15, 16, 19, 20, 21, 22, 25, 26, 27, 28}
local techPhrases = {
    u8"Инициализация потоков...",
    u8"Синхронизация с блокчейном...",
    u8"Шифрование транзакции...",
    u8"Обработка BTC-сигнала...",
    u8"Выгрузка данных в облако...",
    u8"Проверка видеокарт..."
}
local function renderGradientText(text, speed)
    local speed = speed or 2.0
    local time = os.clock() * speed
    local x_offset = 0
    
    for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        -- Рассчитываем волну для блика
        local wave = math.sin(time - (x_offset * 0.1)) * 0.5 + 0.5
        
        -- Цвета: от насыщенного оранжевого до ярко-желтого
        -- Это создаст эффект «бегущего блика» по золоту
        local r = 1.0
        local g = 0.5 + (wave * 0.4) -- Плавает от 0.5 до 0.9
        local b = 0.0
        
        imgui.TextColored(imgui.ImVec4(r, g, b, 1.0), char)
        imgui.SameLine(0, 0)
        x_offset = x_offset + imgui.CalcTextSize(char).x
    end
    imgui.NewLine()
end

-- Переменные MIMGUI
local showMenu = imgui.new.bool(false)
local showControlCenter = imgui.new.bool(false)
-- Шрифт
local imgui_font = nil
imgui.OnInitialize(function()
    local config = imgui.ImFontConfig()
    config.GlyphRanges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
    
    local fontPath = getWorkingDirectory() .. '\\font\\agora.ttf' 
    local solidPath = getWorkingDirectory() .. '\\font\\fa-solid-900.ttf' 
    local brandPath = getWorkingDirectory() .. '\\font\\fa-brands-400.ttf' -- СКАЧАЙ ЭТОТ ФАЙЛ

    if doesFileExist(fontPath) then
        -- 1. Основной шрифт
        imgui_font = imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath, 18, config) 
        
        -- Конфиг для подмешивания
        local iconConfig = imgui.ImFontConfig()
        iconConfig.MergeMode = true
        iconConfig.PixelSnapH = true
        -- РАСШИРЕННЫЙ ДИАПАЗОН (чтобы видело всё)
        local iconRanges = imgui.new.uint16_t[3]({0xf000, 0xffff, 0})

        -- 2. Подмешиваем Solid (иконки системные)
        if doesFileExist(solidPath) then
            imgui.GetIO().Fonts:AddFontFromFileTTF(solidPath, 20, iconConfig, iconRanges)
        end

        -- 3. Подмешиваем Brands (Биткоин, Телеграм и т.д.)
        if doesFileExist(brandPath) then
            imgui.GetIO().Fonts:AddFontFromFileTTF(brandPath, 20, iconConfig, iconRanges)
        end
        
        imgui.GetIO().Fonts:Build()
    end
end)

imgui.OnFrame(function() return showMenu[0] end, function(player)
    if imgui_font then imgui.PushFont(imgui_font) end 

    -- [[ 1. ЕДИНЫЙ ЗОЛОТОЙ СТИЛЬ (ПРАВИЛО ДЛЯ ВСЕХ ОКОН) ]]
    local style = imgui.GetStyle()
    style.WindowRounding, style.WindowBorderSize = 12.0, 1.5
    style.WindowPadding = imgui.ImVec2(20, 20)

    -- Открываем "Золотую Броню" (11 стилей)
    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.06, 0.06, 0.06, 0.96))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(1.0, 0.7, 0.0, 0.5))
    imgui.PushStyleColor(imgui.Col.TitleBg, imgui.ImVec4(0.1, 0.1, 0.1, 1.0))
    imgui.PushStyleColor(imgui.Col.TitleBgActive, imgui.ImVec4(0.15, 0.15, 0.15, 1.0))
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.0, 0.8, 0.0, 1.0)) -- ЗОЛОТОЙ КРЕСТИК ТУТ
    imgui.PushStyleColor(imgui.Col.ResizeGrip, imgui.ImVec4(0, 0, 0, 0)) -- СКРЫВАЕМ ТРЕУГОЛЬНИК
    imgui.PushStyleColor(imgui.Col.ResizeGripHovered, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.ResizeGripActive, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0, 0, 0, 0)) -- ПРОЗРАЧНЫЙ ФОН КРЕСТИКА
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1.0, 0.7, 0.0, 0.2))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(1.0, 0.7, 0.0, 0.4))

    -- --- ПЕРВОЕ ОКНО (HELPER) ---
    imgui.SetNextWindowPos(imgui.ImVec2(20, 350), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowSize(imgui.ImVec2(400, 0), imgui.Cond.Always)
    imgui.Begin("Mining Helper v3.3.5 Beta", showMenu, imgui.WindowFlags.NoDecoration)
        
        local startPos, winPos = imgui.GetCursorScreenPos(), imgui.GetWindowPos()
        local winWidth, draw = imgui.GetWindowWidth(), imgui.GetWindowDrawList()
        local color, radius = 0xCC00AAFF, 9

        -- ПРАВАЯ ИКОНКА ( i )
        local iX, iY = winPos.x + 350, winPos.y + 22
        draw:AddCircle(imgui.ImVec2(iX, iY), radius, color, 20, 1.3)
        imgui.SetCursorScreenPos(imgui.ImVec2(iX - 3, iY - 7))
        imgui.TextColored(imgui.ImVec4(1.0, 0.8, 0.0, 0.8), "i")
        imgui.SetCursorScreenPos(imgui.ImVec2(iX - 10, iY - 10))
        imgui.InvisibleButton("##info_btn", imgui.ImVec2(20, 20))
        if imgui.IsItemHovered() then
            imgui.BeginTooltip()
                imgui.TextColored(imgui.ImVec4(1.0, 0.8, 0.0, 1.0), u8" ТЕКУЩИЙ КУРС:")
                local drawT, pT, wT = imgui.GetWindowDrawList(), imgui.GetCursorScreenPos(), imgui.GetWindowWidth()
                drawT:AddRectFilledMultiColor(imgui.ImVec2(pT.x, pT.y + 2), imgui.ImVec2(pT.x + wT - 10, pT.y + 4), 0xFF00AAFF, 0x0000AAFF, 0x0000AAFF, 0xFF00AAFF)
                imgui.Dummy(imgui.ImVec2(0, 10))
                imgui.Text(u8"Bitcoin: ") imgui.SameLine()
                imgui.TextColored(imgui.ImVec4(0.0, 1.0, 0.5, 1.0), "$" .. btcRate)
            imgui.EndTooltip()
        end

        -- ЛЕВАЯ ИКОНКА ( ? )
        local bX, bY = winPos.x + 380, winPos.y + 22
        draw:AddCircle(imgui.ImVec2(bX, bY), radius, color, 20, 1.3)
        draw:AddLine(imgui.ImVec2(bX-5, bY-4), imgui.ImVec2(bX+5, bY-4), color, 1.5)
        draw:AddLine(imgui.ImVec2(bX-5, bY), imgui.ImVec2(bX+5, bY), color, 1.5)
        draw:AddLine(imgui.ImVec2(bX-5, bY+4), imgui.ImVec2(bX+5, bY+4), color, 1.5)
        imgui.SetCursorScreenPos(imgui.ImVec2(bX - 10, bY - 10))
        if imgui.InvisibleButton("##b_btn", imgui.ImVec2(20, 20)) then showControlCenter[0] = not showControlCenter[0] end
        if imgui.IsItemHovered() then imgui.BeginTooltip() imgui.Text(u8"Центр Управления") imgui.EndTooltip() end

        -- КОНТЕНТ ПЕРВОГО ОКНА
		imgui.SetCursorScreenPos(startPos)

		-- Используем u8 и Unicode-экранирование напрямую
		-- \uf0e7 - это молния (bolt), \uf021 - это то, что ты пытался вывести через байты
		local icon_bolt = " \239\131\167" -- Это код иконки молнии (\uf0e7) в формате UTF-8 
		renderGradientText(icon_bolt .. u8"  AURA CORE SYSTEM", 2.0)

		imgui.SameLine()
		imgui.TextDisabled(" v3.3.5")

        local p = imgui.GetCursorScreenPos()
        -- Делаем линию под заголовком тоже «живой»
        local p = imgui.GetCursorScreenPos()
        draw:AddRectFilledMultiColor(imgui.ImVec2(p.x, p.y + 5), imgui.ImVec2(p.x + winWidth - 40, p.y + 7), 0xFF00AAFF, 0x0000AAFF, 0x0000AAFF, 0xFF00AAFF)
        imgui.Dummy(imgui.ImVec2(0, 15)) 

        imgui.Text(u8"Статус: ") imgui.SameLine()
        if active then imgui.TextColored(imgui.ImVec4(0.0, 1.0, 0.0, 1.0), "ACTIVE")
        else imgui.TextColored(imgui.ImVec4(1.0, 0.2, 0.2, 1.0), "STANDBY") end
        
        imgui.Spacing()
        imgui.Text(u8(string.format("Дом: %d/%d | Карта: %d/20", currentHouse, maxHouses, currentStep)))
        imgui.Text(u8"Собрано за сессию: ") imgui.SameLine()
        imgui.TextColored(imgui.ImVec4(1.0, 0.8, 0.0, 1.0), tostring(totalBTC) .. " BTC")

        if btcRate > 0 then
            imgui.Text(u8"Примерная прибыль: ") imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(0.0, 1.0, 0.5, 1.0), "$" .. math.floor(totalBTC * btcRate))
        end

        imgui.Dummy(imgui.ImVec2(0, 10))
        imgui.Separator()
        imgui.Spacing()

        -- ТАЙМЕР И ЛОГЕР
        if targetTime and not active then
            local rem = targetTime - os.time()
            if rem > 0 then
                local h, m, s = math.floor(rem / 3600), math.floor((rem % 3600) / 60), rem % 60
                imgui.TextColored(imgui.ImVec4(0.0, 1.0, 0.5, 1.0), u8"Ожидание старта: ")
                imgui.SameLine() imgui.Text(string.format("%02u:%02u:%02u", h, m, s))
                local drawL, pL = imgui.GetWindowDrawList(), imgui.GetCursorScreenPos()
				local width = winWidth - 40
				local height = 3

				-- Настройки времени
				local speed = 1.0 -- Время на один полный перелет (А -> Б)
				local t = (os.clock() % (speed * 2)) / speed 
				local is_returning = t > 1.0 -- Летим назад?
				local p = is_returning and (t - 1.0) or t -- Прогресс текущего броска (0.0 -> 1.0)

				-- Функции "выстрела" (очень резкий старт)
				local function shoot(x) return 1 - math.pow(1 - x, 4) end

				-- Голова выстреливает первой (занимает первую половину времени)
				local head_p = shoot(math.min(1.0, p * 1.6)) 
				-- Хвост выстреливает вторым (начинает позже и догоняет)
				local tail_p = shoot(math.max(0.0, p * 1.6 - 0.6))

				-- Рассчитываем координаты
				local startX, endX
				if not is_returning then
					-- Летим ВПРАВО (А -> Б)
					startX = pL.x + (tail_p * width)
					endX = pL.x + (head_p * width)
				else
					-- Летим ВЛЕВО (Б -> А)
					startX = pL.x + (1.0 - head_p) * width
					endX = pL.x + (1.0 - tail_p) * width
				end

				-- Фон
				drawL:AddRectFilled(imgui.ImVec2(pL.x, pL.y + 2), imgui.ImVec2(pL.x + width, pL.y + 2 + height), 0x15FFFFFF, 10)

				-- Рисуем "выстреливающую" часть
				if endX > startX then
					-- Определяем, где голова для градиента (в зависимости от направления)
					local col1 = not is_returning and 0x0000AAFF or 0xFF00AAFF
					local col2 = not is_returning and 0xFF00AAFF or 0x0000AAFF
					
					drawL:AddRectFilledMultiColor(
						imgui.ImVec2(startX, pL.y + 2), 
						imgui.ImVec2(endX, pL.y + 2 + height),
						col1, col2, col2, col1
					)
				end

imgui.SetCursorPosY(imgui.GetCursorPosY() + 10)
                imgui.Dummy(imgui.ImVec2(0, 10))
            else targetTime = nil end
        elseif active then
            local idx = math.floor(os.clock() / 3.0) % (#techPhrases + 1) + 1
            local txt = (idx > #techPhrases) and u8(string.format("Узел дома #%03d успешно взломан", currentHouse)) or techPhrases[idx]
            imgui.TextColored(imgui.ImVec4(1.0, 0.8, 0.0, 1.0), txt .. string.rep(".", math.floor(os.clock() * 2) % 4))
            local pB, wB, prg = imgui.GetCursorScreenPos(), winWidth - 40, (os.clock() % 2) / 2 
            draw:AddRectFilled(imgui.ImVec2(pB.x, pB.y + 2), imgui.ImVec2(pB.x + wB, pB.y + 4), 0x22FFFFFF) 
            draw:AddRectFilled(imgui.ImVec2(pB.x + (wB * prg), pB.y + 2), imgui.ImVec2(pB.x + (wB * prg) + 20, pB.y + 4), 0xFF00AAFF) 
            imgui.Dummy(imgui.ImVec2(0, 10))
        else
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.4, 0.4, 0.4, 1.0))
            imgui.Text(u8"Система в режиме ожидания")
            imgui.PopStyleColor()
        end
    imgui.End()

    -- --- ВТОРОЕ ОКНО (CONTROL CENTER) ---
    if showControlCenter[0] then
        imgui.SetNextWindowSize(imgui.ImVec2(500, 300), imgui.Cond.FirstUseEver)
        imgui.Begin(u8"   Mining Control Center", showControlCenter, imgui.WindowFlags.NoCollapse)
            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(1.0, 0.8, 0.0, 1.0), u8" [ ПАНЕЛЬ В РАЗРАБОТКЕ ]")
            imgui.Separator()
            imgui.Spacing()
            imgui.Text(u8"Данный раздел находится на стадии отладки.")
            imgui.TextDisabled(u8"Следите за обновлениями в v3.4")
        imgui.End()
    end

    -- СБРОС ВСЕХ 11 СТИЛЕЙ
    imgui.PopStyleColor(11)
    if imgui_font then imgui.PopFont() end 
end)

function main()
    while not isSampAvailable() do wait(100) end
    
    -- Выводим строк в чат
    sampAddChatMessage("{FFD700}[MiningBTC] {FFFFFF}Скрипт v3.3 Beta загружен!", -1)
    sampAddChatMessage("{00FF00}F2 {FFFFFF}- скрыть меню | {00FF00}F3 {FFFFFF}- пауза/старт", -1)
    sampAddChatMessage("{00FF00}/fwait [часы] {FFFFFF}- запустить таймер", -1)
    sampAddChatMessage("{00FF00}/freset {FFFFFF}- сбросить прогресс и таймер", -1)

    sampRegisterChatCommand("fwait", startTimer)
    sampRegisterChatCommand("freset", function()
        currentStep, currentHouse, totalBTC, active, targetTime = 1, 0, 0, false, nil
        sampAddChatMessage("{FFD700}[MiningBTC] {FFFFFF}Прогресс и таймер сброшены.", -1)
    end)

    while true do
        wait(0)
        if isKeyJustPressed(vkeys.VK_F2) then
            showMenu[0] = not showMenu[0]
            imgui.ShowCursor = showMenu[0]
            
            if showMenu[0] then
                lua_thread.create(function()
                    sampSendChat('/phone')
                    sendcef('launchedApp|39') -- ID 39 - Курс валют в /phone
                    sampSendChat('/phone')
                end)
            end
        end
        if isKeyJustPressed(vkeys.VK_F3) then toggleMining() end
    end
end

function toggleMining()
    active = not active
    isWaiting = false
    if active then 
        sampAddChatMessage("{FFD700}[MiningBTC] {00FF00}Старт!", -1)
        sampProcessChatInput("/flashminer") 
    else
        sampAddChatMessage("{FFD700}[MiningBTC] {FF4444}Пауза.", -1)
    end
end

function startTimer(arg)
    local hours = tonumber(arg)
    if hours then
        targetTime = os.time() + (hours * 3600)
        lua_thread.create(function()
            wait(hours * 3600 * 1000)
            if not active then targetTime = nil toggleMining() end
        end)
    end
end

function processNextStep()
    lua_thread.create(function()
        isWaiting = true
        currentStep = currentStep + 1
        wait(200)
        if active then sampProcessChatInput("/flashminer") end
        wait(100)
        isWaiting = false
    end)
end

-- Логика чата
function sampev.onServerMessage(color, text)
    if not active then return end
    local cleanText = text:gsub('{......}', ''):lower()
    
    if cleanText:find("Выберите дом с майнинг") or 
       cleanText:find("минимум 1") or 
       cleanText:find("целыми частями") or
       cleanText:find("Вам был добавлен предмет") or
	   cleanText:find("Вы вывели") then
        
        if (cleanText:find("минимум 1") or cleanText:find("целыми частями")) and not isWaiting then
            processNextStep()
        end
        return false 
    end
end

-- Логика диалогов
function sampev.onShowDialog(id, style, title, button1, button2, text)
    -- ЗАЩИТА: Если текста нет или он пустой - выходим
    if not text or text == "" then return end
    
    local cleanTitle = title:gsub('{......}', '')

    -- [ ТИХИЙ ПЕРЕХВАТ КУРСА ]
    if cleanTitle:find("Курс валют") then
        local rateVal = text:match("Bitcoin %(BTC%):%s+%$([%d]+)")
        if rateVal then
            btcRate = tonumber(rateVal)
            lua_thread.create(function() 
                wait(100) 
                sampSendDialogResponse(id, 0, 0, "") 
            end)
            return false
        end
    end

    if not active then return end

    -- [ ОСТАЛЬНАЯ ЛОГИКА ]
    -- Проверь, чтобы в блоке 'видеокарт' индекс не вылетал за пределы:
    if cleanTitle:find("видеокарт") then
        lua_thread.create(function()
            wait(200) -- Увеличил задержку для стабильности
            local lines = {}
            for line in text:gmatch("[^\n]+") do table.insert(lines, line) end
            
            local gpu_idx = gpu_indexes[currentStep]
            -- ЗАЩИТА: проверяем, что индекс существует в таблице lines
            if gpu_idx and lines[gpu_idx + 1] then
                local currentLine = lines[gpu_idx + 1]
                local isOff = currentLine:find('{F78181}') or currentLine:find('Выключена')
                local btcVal = currentLine:match('|%s+%{......%}%W+%s+([%d%.]+)%s+BTC')
                
                if isOff or (btcVal and tonumber(btcVal) >= 1.0) then
                    sampSendDialogResponse(id, 1, gpu_idx, "")
                else
                    processNextStep()
                end
            else
                -- Если индекс не найден - переходим к след. дому
                currentHouse = currentHouse + 1
                currentStep = 1
                if currentHouse < maxHouses then 
                    wait(250)
                    sampProcessChatInput("/flashminer")
                else 
                    active = false 
                    sampAddChatMessage("{00FF00}[MiningBTC] Завершено!", -1)
                end
            end
        end)
        return false 
    end


    -- 3. ВЗАИМОДЕЙСТВИЕ ВНУТРИ КАРТЫ
    if cleanTitle:find("Стойка №") then
        lua_thread.create(function() 
            wait(250)
            -- Если карта выключена - запускаем
            if text:find("Запустить видеокарту") then
                sampSendDialogResponse(id, 1, 0, "") 
            -- Если есть BTC >= 1.0 - забираем
            elseif text:find("Забрать прибыль") and text:find("BTC") then
                local btcInCard = text:match("%(([%d%.]+)%s+BTC%)")
                if btcInCard and tonumber(btcInCard) >= 1.0 then
                    -- Не суммируем totalBTC здесь, чтобы не было дублей, подождем сообщения в чате
                    sampSendDialogResponse(id, 1, 1, "") 
                else
                    processNextStep()
                    sampSendDialogResponse(id, 0, 0, "")
                end
            else
                -- Если карта работает и BTC < 1.0
                processNextStep()
                sampSendDialogResponse(id, 0, 0, "")
            end
        end)
        return false 
    end

    -- 4. ПОДТВЕРЖДЕНИЕ ВЫВОДА
    if cleanTitle:find("прибыли") or cleanTitle:find("Вывод") then
        lua_thread.create(function() 
            wait(150) 
            sampSendDialogResponse(id, 1, 0, "") 
        end)
        return false 
    end
end

function sendcef(str)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, #str) 
    raknetBitStreamWriteString(bs, str)
    raknetBitStreamWriteInt32(bs, 0)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end
