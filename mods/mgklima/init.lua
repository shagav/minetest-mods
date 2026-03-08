local limit = tonumber(minetest.settings:get("mapgen_limit")) or 31000

minetest.clear_registered_biomes()
minetest.clear_registered_decorations()

minetest.register_on_generated(function(minp, maxp, seed)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local data = vm:get_data()
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    
    local c_dirt       = minetest.get_content_id("default:dirt")
    local c_sand       = minetest.get_content_id("default:desert_sand")
    local c_silversand = minetest.get_content_id("default:silver_sand")
    local c_snow       = minetest.get_content_id("default:snowblock")
    local c_ice        = minetest.get_content_id("default:ice")
    local c_gravel     = minetest.get_content_id("default:gravel")
    local c_desstone   = minetest.get_content_id("default:desert_stone")
    local c_stone      = minetest.get_content_id("default:stone")
    local c_water      = minetest.get_content_id("default:water_source")
    local c_air        = minetest.get_content_id("air")

    for z = minp.z, maxp.z do
        -- 1. BASIS-HITZE (Breitengrad)
        local base_heat = 100 - (math.abs(z) / limit * 100)

        for x = minp.x, maxp.x do
            -- Wir suchen zuerst, ob in diesem X/Z-Streifen Wasser an der Oberfläche ist
            local has_water_nearby = false
            for y_search = maxp.y, minp.y, -1 do
                local node_id = data[area:index(x, y_search, z)]
                if node_id == c_water then
                    has_water_nearby = true
                    break
                end
            end

            -- 2. LOKALE HITZE-KORREKTUR (Kühlung durch Wasser)
            local effective_heat = base_heat
            if has_water_nearby then
                effective_heat = base_heat - 20 -- Massive Kühlung für das Terraforming
            end

            -- 3. MATERIAL-WAHL (Basierend auf korrigierter Hitze)
            local top_node = c_dirt
            if effective_heat > 90 then top_node = c_desstone
            elseif effective_heat > 75 then top_node = c_sand
            elseif effective_heat > 60 then top_node = c_silversand
            elseif effective_heat > 40 then top_node = c_dirt
            elseif effective_heat > 25 then top_node = c_gravel
            elseif effective_heat > 10 then top_node = c_snow
            else top_node = c_ice end

            for y = maxp.y, minp.y, -1 do
                local vi = area:index(x, y, z)
                if data[vi] == c_stone then
                    local above = area:index(x, y + 1, z)
                    if y < maxp.y then
                        -- LAND: Nutzt das gekühlte Material
                        if data[above] == c_air then
                            data[vi] = top_node
                        -- OZEANGRUND: Immer Sand (wie besprochen)
                        elseif data[above] == c_water then
                            data[vi] = c_sand
                        end
                    end
                    break
                end
            end
        end
    end
    vm:set_data(data)
    vm:write_to_map()
end)

minetest.log("action", "[mgklima] Terraforming mit Ozean-Kühlung aktiv.")
