#define STARTUP_STAGE 1
#define MAIN_STAGE 2
#define WIND_DOWN_STAGE 3
#define END_STAGE 4

//Used for all kinds of weather, ex. lavaland ash storms.
SUBSYSTEM_DEF(weather)
	name = "Weather"
	flags = SS_BACKGROUND
	wait = 10
	runlevels = RUNLEVEL_GAME
	var/list/processing = list()
	var/list/eligible_zlevels = list()
	var/list/next_hit_by_zlevel = list() //Used by barometers to know when the next storm is coming
	var/weather_on_start = FALSE

/datum/controller/subsystem/weather/fire()
	// process active weather
	for(var/V in processing)
		var/datum/weather/W = V
		if(W.aesthetic || W.stage != MAIN_STAGE)
			continue
		if(!W.turfs_impacted && W.affects_turfs)
			W.turfs_impacted = TRUE
			for(var/i in W.impacted_areas)
				var/area/A = i
				for(var/t in A.contents)
					var/turf/T = t
					if(W.can_weather_act_turf(T))
						W.weather_act_turf(T)
		for(var/i in GLOB.mob_living_list)
			var/mob/living/L = i
			if(W.can_weather_act(L))
				W.weather_act(L)

	// start random weather on relevant levels
	for(var/z in eligible_zlevels)
		var/possible_weather = eligible_zlevels[z]
		var/datum/weather/W = pickweight(possible_weather)
		if(weather_on_start)
			run_weather(W, list(text2num(z)))
			eligible_zlevels -= z
		else
			eligible_zlevels -= z
		var/randTime = rand(15000, 18000)
		addtimer(CALLBACK(src, .proc/make_eligible, z, possible_weather), randTime + initial(W.weather_duration_upper), TIMER_UNIQUE) //Around 25-30 minutes between weathers
		next_hit_by_zlevel["[z]"] = world.time + randTime + initial(W.telegraph_duration)
	if(!weather_on_start)
		weather_on_start = TRUE

/datum/controller/subsystem/weather/Initialize(start_timeofday)
	for(var/V in subtypesof(/datum/weather))
		var/datum/weather/W = V
		var/probability = initial(W.probability)
		var/target_trait = initial(W.target_trait)

		// any weather with a probability set may occur at random
		if (probability)
			for(var/z in SSmapping.levels_by_trait(target_trait))
				if(z == 3) // Ignore sewers
					continue
				LAZYINITLIST(eligible_zlevels["[z]"])
				eligible_zlevels["[z]"][W] = probability
	return ..()

/datum/controller/subsystem/weather/proc/run_weather(datum/weather/weather_datum_type, z_levels, duration)
	if (istext(weather_datum_type))
		for (var/V in subtypesof(/datum/weather))
			var/datum/weather/W = V
			if (initial(W.name) == weather_datum_type)
				weather_datum_type = V
				break
	if (!ispath(weather_datum_type, /datum/weather))
		CRASH("run_weather called with invalid weather_datum_type: [weather_datum_type || "null"]")
		return

	if (isnull(z_levels))
		z_levels = SSmapping.levels_by_trait(initial(weather_datum_type.target_trait))
	else if (isnum(z_levels))
		z_levels = list(z_levels)
	else if (!islist(z_levels))
		CRASH("run_weather called with invalid z_levels: [z_levels || "null"]")
		return

	if(duration && !isnum(duration))
		CRASH("run_weather called with invalid duration: [duration || "null"]")
		return

	var/datum/weather/W = new weather_datum_type(z_levels, duration)
	W.telegraph()

/datum/controller/subsystem/weather/proc/make_eligible(z, possible_weather)
	eligible_zlevels[z] = possible_weather
	next_hit_by_zlevel["[z]"] = null

/datum/controller/subsystem/weather/proc/get_weather(z, area/active_area)
    var/datum/weather/A
    for(var/V in processing)
        var/datum/weather/W = V
        if((z in W.impacted_z_levels) && W.area_type == active_area.type)
            A = W
            break
    return A
