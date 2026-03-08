local player_huds = {}
local timer = 0
local limit = tonumber(minetest.settings:get("mapgen_limit")) or 31000

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    player_huds[name] = {}
    player_huds[name].info = player:hud_add({
        hud_elem_type = "text", position = {x = 0.5, y = 1},
        offset = {x = 0, y = -120}, text = "Scanner wird kalibriert...", number = 0xFFFFFF, alignment = {x = 0, y = 0},
    })
    player_huds[name].coords = player:hud_add({
        hud_elem_type = "text", position = {x = 0.5, y = 1},
        offset = {x = 0, y = -140}, text = "0,0,0", number = 0xFFFFFF, alignment = {x = 0, y = 0},
    })
end)

minetest.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer < 1 then return end
    timer = 0

    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local pos = player:get_pos()
        
        -- 1. BASIS-TEMPERATUR (Breitengrad Z)
        local heat_val = 100 - (math.abs(pos.z) / limit * 100)
        local temp = (heat_val * 1.1) - 55 -- Skala -55°C bis +55°C
        
        -- 2. WASSER-ERKENNUNG (Thermodynamik-Check)
        local water_dist = nil
        -- Wir scannen bis zu 150m Tiefe nach Wasser
        for d = 0, 150 do 
            local node = minetest.get_node_or_nil({x=pos.x, y=pos.y-d, z=pos.z})
            if node and node.name == "default:water_source" then
                water_dist = d
                break
            end
        end

        -- 3. THERMISCHE KORREKTUR
        local zone = "Sedimentzone"
        local color = 0x8B4513 -- Standard Braun
        
        if water_dist then
            -- Maritime Kühlung (Stabil bis 100m, danach Abfall bis 500m)
            local cooling = 15
            if water_dist > 100 then
                cooling = math.max(0, 15 - ((water_dist - 100) * 0.04))
            end
            temp = temp - cooling
            
            color = 0x1E90FF -- Ozean Blau
            zone = (water_dist < 10) and "Ozean" or "Maritimer Luftraum"
        else
            -- LAND-LOGIK (Höhenkälte/Tiefenwärme)
            if pos.y > 0 then 
                temp = temp - (pos.y * 0.007)
            elseif pos.y < -30 then 
                temp = temp + (math.abs(pos.y) * 0.03) 
            end

            -- Zonen-Namensgebung Land
            if pos.y < -2000 then zone = "Magma-Kern" color = 0xFF0000
            elseif pos.y < -500 then zone = "Basalt-Schicht" color = 0x444444
            else
                if heat_val > 90 then zone = "Vulkanfels" color = 0x552222
                elseif heat_val > 75 then zone = "Thermalwüste" color = 0xFF4500
                elseif heat_val > 60 then zone = "Staubebene" color = 0xFFA500
                elseif heat_val > 40 then zone = "Sedimentzone" color = 0x8B4513
                elseif heat_val > 25 then zone = "Geröllfeld" color = 0xAAAAAA
                elseif heat_val > 10 then zone = "Kryozone" color = 0xADD8E6
                else zone = "Eiskappe" color = 0x0000FF end
            end
        end

        -- 4. HUD AKTUALISIERUNG
        if player_huds[name] then
            local info_str = string.format("%s | %.1f °C", zone, temp)
            player:hud_change(player_huds[name].info, "text", info_str)
            player:hud_change(player_huds[name].info, "number", color)
            
            local c_str = string.format("%d,%d,%d", math.floor(pos.x), math.floor(pos.y), math.floor(pos.z))
            player:hud_change(player_huds[name].coords, "text", c_str)
        end

        -- 5. SCHADENS-LOGIK
        if temp > 65 or temp < -50 then
            local hp = player:get_hp()
            if hp > 0 then player:set_hp(hp - 1) end
        end
    end
end)

minetest.register_on_leaveplayer(function(player)
    player_huds[player:get_player_name()] = nil
end)
