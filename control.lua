--[[ Copyright (c) 2018 Optera
 * Part of LTN Content Reader
 *
 * See LICENSE.md in the project directory for license information.
--]]

-- localize often used functions and strings
local match = string.match
local format = string.format
local match_string = "([^,]+),([^,]+)"
local btest = bit32.btest
local signal_network_id = {type="virtual", name="ltn-network-id"}
-- name to equal with utility-combinators mode
local signal_surface_index = {type="virtual", name="signal-Z"}
local content_readers = {
  ["ltn-provider-reader"] = {table_name = "ltn_provided"},
  ["ltn-requester-reader"] = {table_name = "ltn_requested"},
  ["ltn-delivery-reader"] = {table_name = "ltn_deliveries"},
}

local all_surfaces_index = -1

-- get default network from LTN
local default_network = settings.global["ltn-stop-default-network"].value
local default_surface = settings.global["ltn_content_reader_default_surface"].value
script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if not event then return end
  if event.setting == "ltn-stop-default-network" then
    default_network = settings.global["ltn-stop-default-network"].value
  end
  if event.setting == "ltn_content_reader_default_surface" then
    default_surface = settings.global["ltn_content_reader_default_surface"].value
  end
end)

-- LTN interface event functions
function OnStopsUpdated(event)
  --log("Stop Data:"..serpent.block(event.data) )
  global.ltn_stops = event.logistic_train_stops or {}
end


function OnDispatcherUpdated(event)
  -- ltn provides data per stop, aggregate over network and item
  global.ltn_provided = {}
  global.ltn_requested = {}
  global.ltn_deliveries = {}

  global.ltn_provided[all_surfaces_index] = {}
  global.ltn_requested[all_surfaces_index] = {}
  global.ltn_deliveries[all_surfaces_index] = {}

  -- event.provided_by_stop = { [stopID], { [item], count } }
  for stopID, items in pairs(event.provided_by_stop) do
    local network_id = global.ltn_stops[stopID] and global.ltn_stops[stopID].network_id
    local surface_idx = global.ltn_stops[stopID].entity.surface.index

    global.ltn_provided[surface_idx] = global.ltn_provided[surface_idx] or {}

    if network_id then
      global.ltn_provided[surface_idx][network_id] = global.ltn_provided[surface_idx][network_id] or {}
      global.ltn_provided[all_surfaces_index][network_id] = global.ltn_provided[all_surfaces_index][network_id] or {}
      for item, count in pairs(items) do
        global.ltn_provided[surface_idx][network_id][item] = (global.ltn_provided[surface_idx][network_id][item] or 0) + count
        global.ltn_provided[all_surfaces_index][network_id][item] = (global.ltn_provided[all_surfaces_index][network_id][item] or 0) + count
      end
    end
  end

  -- event.requests_by_stop = { [stopID], { [item], count } }
  for stopID, items in pairs(event.requests_by_stop) do
    local network_id = global.ltn_stops[stopID] and global.ltn_stops[stopID].network_id
    local surface_idx = global.ltn_stops[stopID].entity.surface.index

    global.ltn_requested[surface_idx] = global.ltn_requested[surface_idx] or {}

    if network_id then
      global.ltn_requested[surface_idx][network_id] = global.ltn_requested[surface_idx][network_id] or {}
      global.ltn_requested[all_surfaces_index][network_id] = global.ltn_requested[all_surfaces_index][network_id] or {}
      for item, count in pairs(items) do
        global.ltn_requested[surface_idx][network_id][item] = (global.ltn_requested[surface_idx][network_id][item] or 0) - count
        global.ltn_requested[all_surfaces_index][network_id][item] = (global.ltn_requested[all_surfaces_index][network_id][item] or 0) - count
      end
    end
  end

  -- event.deliveries = { trainID = {force, train, from, to, network_id, started, shipment = { item = count } } }
  for trainID, delivery in pairs(event.deliveries) do
    local surface_idx = global.ltn_stops[delivery.from_id].entity.surface.index

    global.ltn_deliveries[surface_idx] = global.ltn_deliveries[surface_idx] or {}

    if delivery.network_id then
      global.ltn_deliveries[surface_idx][delivery.network_id] = global.ltn_deliveries[surface_idx][delivery.network_id] or {}
      global.ltn_deliveries[all_surfaces_index][delivery.network_id] = global.ltn_deliveries[all_surfaces_index][delivery.network_id] or {}
      for item, count in pairs(delivery.shipment) do
        global.ltn_deliveries[surface_idx][delivery.network_id][item] = (global.ltn_deliveries[surface_idx][delivery.network_id][item] or 0) + count
        global.ltn_deliveries[all_surfaces_index][delivery.network_id][item] = (global.ltn_deliveries[all_surfaces_index][delivery.network_id][item] or 0) + count
      end
    end
  end

  -- event.update_interval = LTN update interval (depends on existing ltn stops and stops per tick setting
  global.update_interval = event.update_interval
end

-- spread out updating combinators
function OnTick(event)
  -- global.update_interval LTN update interval are synchronized in OnDispatcherUpdated
  local offset = event.tick % global.update_interval
  local cc_count = #global.content_combinators
  for i=cc_count - offset, 1, -1 * global.update_interval do
    -- log( "("..tostring(event.tick)..") on_tick updating "..i.."/"..cc_count )
    local combinator = global.content_combinators[i]
    if combinator.valid then
      Update_Combinator(combinator)
    else
      table.remove(global.content_combinators, i)
      if #global.content_combinators == 0 then
        script.on_event(defines.events.on_tick, nil)
      end
    end
  end
end

function Update_Combinator(combinator)
  -- get network id from combinator parameters
  local first_signal = combinator.get_control_behavior().get_signal(1)
  -- get surface id from combinator parameters
  local second_signal = combinator.get_control_behavior().get_signal(2)
  local max_signals = combinator.get_control_behavior().signals_count
  local selected_network_id = default_network
  local selected_surface_idx = all_surfaces_index

  if first_signal and first_signal.signal and first_signal.signal.name == "ltn-network-id" then
    selected_network_id = first_signal.count
  else
    log(format("Error: combinator must have ltn-network-id set at index 1. Setting network id to %s.", default_network) )
  end

  if second_signal and second_signal.signal and second_signal.signal.name == signal_surface_index.name then
    selected_surface_idx = second_signal.count
  elseif default_surface == "current" then
    selected_surface_idx = combinator.surface.index
  end

  local signals = {
    { index = 1, signal = signal_network_id, count = selected_network_id },
    { index = 2, signal = signal_surface_index, count = selected_surface_idx },
  }
  local index = 3

  -- for many signals performance is better to aggregate first instead of letting factorio do it
  local items = {}
  local reader = content_readers[combinator.name]
  if reader then
    global[reader.table_name][selected_surface_idx] = global[reader.table_name][selected_surface_idx] or {}

    for network_id, item_data in pairs(global[reader.table_name][selected_surface_idx]) do
      if btest(selected_network_id, network_id) then
        for item, count in pairs(item_data) do
          items[item] = (items[item] or 0) + count
        end
      end
    end
  end

  -- generate signals from aggregated item list
  for item, count in pairs(items) do
    local itype, iname = match(item, match_string)
    if itype and iname and (itype == "item" and game.item_prototypes[iname] or itype == "fluid" and game.fluid_prototypes[iname]) then
      if max_signals >= index then
        if count >  2147483647 then count =  2147483647 end
        if count < -2147483648 then count = -2147483648 end
        signals[#signals+1] = {index = index, signal = {type=itype, name=iname}, count = count}
        index = index+1
      else
        log("[LTN Content Reader] Error: signals in network "..selected_network_id.." exceed "..max_signals.." combinator signal slots. Not all signals will be displayed.")
        break
      end
    end
  end
  combinator.get_control_behavior().parameters = signals

end


-- add/remove event handlers
function OnEntityCreated(event)
  local entity = event.created_entity
  if content_readers[entity.name] then
    -- if not set use default network id
    local first_signal = entity.get_control_behavior().get_signal(1)
    if not (first_signal and first_signal.signal and first_signal.signal.name == "ltn-network-id") then
      entity.get_or_create_control_behavior().parameters = {{ index = 1, signal = signal_network_id, count = default_network }}
    end
    local second_signal = entity.get_control_behavior().get_signal(2)
    if not (second_signal and second_signal.signal and second_signal.signal.name == signal_surface_index.name) then
      local default_surface_idx = default_surface == "current" and entity.surface.index or all_surfaces_index

      entity.get_or_create_control_behavior().parameters = {{ index = 2, signal = signal_surface_index, count = default_surface_idx }}
    end

    table.insert(global.content_combinators, entity)

    if #global.content_combinators == 1 then
      script.on_event(defines.events.on_tick, OnTick)
    end
  end
end

function OnEntityRemoved(event)
  local entity = event.entity
  if content_readers[entity.name] then
    for i=#global.content_combinators, 1, -1 do
      if global.content_combinators[i].unit_number == entity.unit_number then
        table.remove(global.content_combinators, i)
      end
    end

    if #global.content_combinators == 0 then
			script.on_event(defines.events.on_tick, nil)
    end
  end
end

---- Initialisation  ----
do
local function init_globals()
  global.ltn_stops = global.ltn_stops or {}
  global.ltn_provided = global.ltn_provided or {}
  global.ltn_requested = global.ltn_requested or {}
  global.ltn_deliveries = global.ltn_deliveries or {}
  global.ltn_provided[all_surfaces_index] = global.ltn_provided[all_surfaces_index] or {}
  global.ltn_requested[all_surfaces_index] = global.ltn_requested[all_surfaces_index] or {}
  global.ltn_deliveries[all_surfaces_index] = global.ltn_deliveries[all_surfaces_index] or {}
  global.content_combinators = global.content_combinators or {}
  global.update_interval = global.update_interval or 60

  -- remove unused globals froms save
  global.last_update_tick = nil
  global.ltn_contents = nil
  global.stop_network_ID = nil
end

local function register_events()
  -- register events from LTN
  if remote.interfaces["logistic-train-network"] then
    script.on_event(remote.call("logistic-train-network", "on_stops_updated"), OnStopsUpdated)
    script.on_event(remote.call("logistic-train-network", "on_dispatcher_updated"), OnDispatcherUpdated)
  end

  -- register game events
  script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, OnEntityCreated)
  script.on_event({defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined, defines.events.on_entity_died}, OnEntityRemoved)
  if #global.content_combinators > 0 then
    script.on_event(defines.events.on_tick, OnTick)
  end
end


script.on_init(function()
  init_globals()
  register_events()
end)

script.on_configuration_changed(function(data)
  init_globals()
  register_events()
end)

script.on_load(function(data)
  register_events()
end)
end