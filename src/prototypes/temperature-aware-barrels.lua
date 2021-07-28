local barreling_recipes = {}
local barreling_recipes_list = {}
local barreling_recipes_fluid_index = {}

local unbarreling_recipes = {}
local unbarreling_recipes_list = {}
local unbarreling_recipes_fluid_index = {}

local fluids = {}


for _, recipe in pairs(data.raw.recipe) do
	local ingredients = recipe.ingredients
	local products = recipe.results

	if ingredients and products and #ingredients == 2 and #products == 1 then
		if (ingredients[1].name == "empty-barrel" and ingredients[2].type == "fluid") or (ingredients[2].name == "empty-barrel" and ingredients[1].type == "fluid") then
			local fluid = ingredients[1]
			local position = 1

			if ingredients[2].type == "fluid" then
				fluid = ingredients[2]
				position = 2
			end
			
			local dta = {}
			dta.recipe = recipe;
			dta.fluid = fluid
			dta.position = position
			
			barreling_recipes[#barreling_recipes+1] = dta
			barreling_recipes_list[recipe.name] = #barreling_recipes
			barreling_recipes_fluid_index[fluid.name] = dta
		end
	elseif ingredients and products and #ingredients == 1 and #products == 2 then
		if (products[1].name == "empty-barrel" and products[2].type == "fluid") or (products[2].name == "empty-barrel" and products[1].type == "fluid") then
			local fluid = products[1]
			local position = 1

			if products[2].type == "fluid" then
				fluid = products[2]
				position = 2
			end
			
			local dta = {}
			dta.recipe = recipe;
			dta.fluid = fluid
			dta.position = position

			unbarreling_recipes[#unbarreling_recipes+1] = dta
			unbarreling_recipes_list[recipe.name] = #unbarreling_recipes
			unbarreling_recipes_fluid_index[fluid.name] = dta
		end
	end

    if products then
        for _, product in pairs(products) do
            if product.type == "fluid" and data.raw.fluid[product.name] then
                local temperature = 0

                if product.temperature then
                    temperature = product.temperature
                else
                    temperature = data.raw.fluid[product.name].default_temperature
                end

                if temperature then
                    if not fluids[product.name] then
                        fluids[product.name] = {}
                        fluids[product.name].temperatures = {}
                        fluids[product.name].temperatures_count = 0
                        fluids[product.name].prototype = data.raw.fluid[product.name]
                    end

                    if not fluids[product.name].temperatures[temperature] then
                        fluids[product.name].temperatures[temperature] = temperature;
                        fluids[product.name].temperatures_count = fluids[product.name].temperatures_count + 1
                    end
                end
            end
        end
    end

    if ingredients then
        for _, ingredient in pairs(ingredients) do
            if ingredient.type == "fluid" and data.raw.fluid[ingredient.name] then
                local temperature = ingredient.temperature
                local min_temperature = ingredient.minimum_temperature
                local max_temperature = ingredient.maximum_temperature

                if min_temperature and max_temperature and min_temperature == max_temperature then
                    temperature = min_temperature
				elseif ingredient.temperature then
                    temperature = ingredient.temperature
                else
                    temperature = data.raw.fluid[ingredient.name].default_temperature
                end

                if temperature then
                    if not fluids[ingredient.name] then
                        fluids[ingredient.name] = {}
                        fluids[ingredient.name].temperatures = {}
                        fluids[ingredient.name].temperatures_count = 0
                        fluids[ingredient.name].prototype = data.raw.fluid[ingredient.name]
                    end
             
                    if not fluids[ingredient.name].temperatures[temperature] then
                        fluids[ingredient.name].temperatures[temperature] = temperature;
                        fluids[ingredient.name].temperatures_count = fluids[ingredient.name].temperatures_count + 1
                    end
                end
            end
        end
    end
end

for _, fluid in pairs(fluids) do
	local fluid_name = fluid.prototype.name

	if fluid.prototype.hidden ~= true and fluid.temperatures_count > 1 then
		local barreling_recipe = barreling_recipes_fluid_index[fluid_name]
		local unbarreling_recipe = unbarreling_recipes_fluid_index[fluid_name]

		if barreling_recipe and unbarreling_recipe then
            local barreled_fluid = data.raw.item[barreling_recipe.recipe.results[1].name];

			for _, fl_temp in pairs(fluid.temperatures) do
                -- padded format with leading zeros for proper ordering
                local padded_temp = string.format("%06d", fl_temp)

                -- create fluid barrel with temperature
                local barreled_fluid_with_temp
                if fluid.prototype.default_temperature and fl_temp == fluid.prototype.default_temperature then
                    barreled_fluid_with_temp = barreled_fluid
                else
                    barreled_fluid_with_temp = table.deepcopy(barreled_fluid)
                    barreled_fluid_with_temp.name = barreled_fluid.name .. "-" .. fl_temp
                end
                
                barreled_fluid_with_temp.order = "b[" .. barreled_fluid.name .. "-" .. padded_temp .. "]"
                barreled_fluid_with_temp.localised_name = { "", { "item-name.filled-barrel", { "fluid-name." .. fluid_name }}, " (", { "format-degrees-c", fl_temp },")" }

                -- create barreling recipe with temperature
				local barreling_recipe_with_temp = table.deepcopy(barreling_recipe.recipe)
				barreling_recipe_with_temp.name = barreling_recipe.recipe.name .. "-" .. fl_temp
                barreling_recipe_with_temp.order = "b[" .. barreling_recipe.recipe.name .. "-" .. padded_temp .. "]"
                barreling_recipe_with_temp.localised_name = { "", { "recipe-name.fill-barrel", { "fluid-name." .. fluid_name }}, " (", { "format-degrees-c", fl_temp },")" }
                barreling_recipe_with_temp.ingredients[barreling_recipe.position].minimum_temperature = fl_temp
				barreling_recipe_with_temp.ingredients[barreling_recipe.position].maximum_temperature = fl_temp
                barreling_recipe_with_temp.results[1].name = barreled_fluid_with_temp.name

                -- create unbarreling recipe with temperature
                local unbarreling_recipe_with_temp = table.deepcopy(unbarreling_recipe.recipe)
				unbarreling_recipe_with_temp.name = unbarreling_recipe.recipe.name .. "-" .. fl_temp
                unbarreling_recipe_with_temp.order = "b[" .. unbarreling_recipe.recipe.name .. "-" .. padded_temp .. "]"
                unbarreling_recipe_with_temp.localised_name = { "", { "recipe-name.empty-filled-barrel", { "fluid-name." .. fluid_name }}, " (", { "format-degrees-c", fl_temp },")" }
				unbarreling_recipe_with_temp.results[unbarreling_recipe.position].temperature = fl_temp
                unbarreling_recipe_with_temp.ingredients[1].name = barreled_fluid_with_temp.name

                -- unlock recipes with Fluid handling technology
				table.insert(data.raw.technology["fluid-handling"].effects, {type = "unlock-recipe", recipe = unbarreling_recipe_with_temp.name})
				table.insert(data.raw.technology["fluid-handling"].effects, {type = "unlock-recipe", recipe = barreling_recipe_with_temp.name})

                -- extend data
				data:extend{
                    barreled_fluid_with_temp,
					barreling_recipe_with_temp,
					unbarreling_recipe_with_temp
				}
			end

            -- hide item and recipes without temperature
            -- barreled_fluid.hidden = true
			barreling_recipe.recipe.hidden = true
			unbarreling_recipe.recipe.hidden = true
		end
	end
end