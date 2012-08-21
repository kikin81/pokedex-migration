require 'rubygems'
require 'sqlite3'
load 'pokemon.rb'
require 'json'
require 'mongo'
require 'csv'

def pkm_set_id(pokemonId, form, db, pkm)
    # nationalID + form + generation
    # 0000 00 0
    # bulbasaur: 0001011 0001012 0001013 0001014 0001015
end

def pkm_get_national_id(pokemonId, db, pkm)
    row = db.get_first_value("SELECT pokemon_dex_numbers.pokedex_number
                            FROM pokemon INNER JOIN pokemon_species ON pokemon.species_id = pokemon_species.id
                                 INNER JOIN pokemon_dex_numbers ON pokemon_species.id = pokemon_dex_numbers.species_id
                                 INNER JOIN pokedexes ON pokemon_dex_numbers.pokedex_id = pokedexes.id
                            WHERE pokemon.id = #{pokemonId}
                            AND pokedexes.id = 1")
    pkm.national_id = row
end

def pkm_get_egg_group(pokemonId, db, pkm)
    x = 0
    pkm.egg_group = Hash.new
    db.results_as_hash = true
    db.execute("SELECT pokemon.id, egg_group_prose.name
                FROM pokemon INNER JOIN pokemon_egg_groups ON pokemon.species_id = pokemon_egg_groups.species_id
                     INNER JOIN egg_group_prose ON pokemon_egg_groups.egg_group_id = egg_group_prose.egg_group_id
                WHERE egg_group_prose.local_language_id = 9
                AND pokemon.id = #{pokemonId}
                order by name") do |row|
            pkm.egg_group["#{x}"] = row['name'].downcase
            x +=1
        end
end

def pkm_get_height_weight(pokemonId, db, pkm)
    db.results_as_hash = true
    db.execute( "SELECT height, weight 
                 FROM pokemon
                 WHERE id = #{pokemonId}") do |row|
        pkm.height = row['height']/10.0
        pkm.weight = row['weight']/10.0
        
    end
end

def pkm_get_name(pokemonId, db, pkm)
    pokemon_name = db.get_first_value("SELECT pokemon_species_names.name
                            FROM pokemon INNER JOIN pokemon_species_names ON pokemon.species_id = pokemon_species_names.pokemon_species_id
                            WHERE pokemon_species_names.local_language_id = 9
                            AND pokemon.id = #{pokemonId}")
    # if we have a result
    pkm.name = pokemon_name
end

def pkm_slug(pkm)
    case pkm.national_id
    when 29
        pkm.slug = 'nidoran-f'
    when 32
        pkm.slug = 'nidoran-m'
    else
        if pkm.name.nil?
            puts pkm.inspect
        end
        pkm.slug = pkm.name.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    end

    if pkm.form.nil?
    else
        #pkm.slug += "-#{pkm.form}"
    end
end

def pkm_get_jname(pokemonId, db, pkm)
    pokemon_jname = db.get_first_value("SELECT pokemon_species_names.name
                            FROM pokemon INNER JOIN pokemon_species ON pokemon.species_id = pokemon_species.id
                              INNER JOIN pokemon_species_names ON pokemon_species.id = pokemon_species_names.pokemon_species_id
                            WHERE pokemon.id=#{pokemonId} 
                            AND pokemon_species_names.local_language_id=1")
    pkm.jname = pokemon_jname.downcase
end

def pkm_get_evolution_chain(pokemonId, db, pkm)
    pokemon_evolution = db.get_first_value("SELECT pokemon_species.evolution_chain_id
                            FROM pokemon INNER JOIN pokemon_species ON pokemon.species_id = pokemon_species.id
                            WHERE pokemon.id = #{pokemonId}")
    pkm.evolution_chain = pokemon_evolution
end

def pkm_get_stats(pokemonId, db, pkm)
    db.results_as_hash = true
    db.execute("SELECT stats.identifier, pokemon_stats.base_stat
                FROM pokemon
                INNER JOIN pokemon_stats ON pokemon.id = pokemon_stats.pokemon_id
                INNER JOIN stats ON pokemon_stats.stat_id = stats.id
                WHERE pokemon.id = #{pokemonId}") do |row|
        case row['identifier']
            when "hp"
                pkm.hp=row['base_stat']
            when "attack"
                pkm.attack=row['base_stat']
            when "defense"
                pkm.defense=row['base_stat']
            when "special-attack"
                pkm.special_attack=row['base_stat']
            when "special-defense"
                pkm.special_defense=row['base_stat']
            when "speed"
                pkm.speed=row['base_stat']
            else puts "I failed"
        end
    end
end

def pkm_get_type(pokemonId, db, pkm)
    x = 1
    types = Hash.new
    rows = db.execute("SELECT type_names.name
                    FROM pokemon INNER JOIN pokemon_types ON pokemon.id = pokemon_types.pokemon_id
                         INNER JOIN type_names ON pokemon_types.type_id = type_names.type_id
                    WHERE pokemon.id = #{pokemonId}
                    AND type_names.local_language_id = 9") do |row|
                    types["type_#{x}"] = row['name']
                    x = x+1
                end
    pkm.type = types

end

def pkm_get_dex_desc(pokemonId, generationID, db, pkm)
    dexDescription = Hash.new
    db.results_as_hash = true
    db.execute("SELECT DISTINCT versions.identifier, pokemon_species_flavor_text.flavor_text
                FROM pokemon INNER JOIN pokemon_species_flavor_text ON pokemon.species_id = pokemon_species_flavor_text.species_id
                     INNER JOIN versions ON pokemon_species_flavor_text.version_id = versions.id
                     INNER JOIN version_groups ON versions.version_group_id = version_groups.id
                WHERE pokemon.id = #{pokemonId}
                AND pokemon_species_flavor_text.language_id = 9
                AND version_groups.generation_id = #{generationID}") do |row|
            dexDescription[row['identifier']]=row['flavor_text']
        end
    pkm.dex_description = dexDescription
end

def pkm_get_ability(pokemonId, db, pkm)
    x = 1
    abilities = Hash.new
    rows = db.execute("SELECT pokemon_abilities.ability_id, abilities.identifier as ability_name
                        FROM pokemon INNER JOIN pokemon_abilities ON pokemon.id = pokemon_abilities.pokemon_id
                             INNER JOIN abilities ON pokemon_abilities.ability_id = abilities.id
                        WHERE pokemon.id = #{pokemonId}
                        ORDER BY ability_name") do |row|
                ability_id = row['ability_id']
                abilities["#{ability_id}"] = row['ability_name']
                x = x+1
            end
    pkm.abilities = abilities

end

def pkm_get_species(pokemonId, db, pkm)
    rows = db.execute("SELECT pokemon_species_names.genus
                        FROM pokemon_species_names
                        WHERE pokemon_species_names.pokemon_species_id = #{pokemonId}
                        and pokemon_species_names.local_language_id = 9") do |row|
                pkm.species= row['genus']
            end
end

def pkm_get_level_moves_by_generation(pokemonId, generationId, db, pkm)
    # a[0]=[3,5,7]
    levelMoves = Hash.new{|h, k| h[k] = []}
    db.results_as_hash = true
    db.execute("SELECT DISTINCT pokemon_moves.move_id, pokemon_moves.level, move_names.name, types.identifier
                FROM pokemon INNER JOIN pokemon_moves ON pokemon.id = pokemon_moves.pokemon_id
                     INNER JOIN moves ON pokemon_moves.move_id = moves.id
                     INNER JOIN types ON moves.type_id = types.id
                     INNER JOIN version_groups ON pokemon_moves.version_group_id = version_groups.id
                     INNER JOIN generations ON version_groups.generation_id = generations.id
                     INNER JOIN move_names ON pokemon_moves.move_id = move_names.move_id
                     INNER JOIN pokemon_move_methods ON pokemon_moves.pokemon_move_method_id = pokemon_move_methods.id
                WHERE pokemon_move_methods.id = 1
                AND move_names.local_language_id = 9
                AND pokemon.id = #{pokemonId}
                AND generations.id = #{generationId}
                AND version_group_id != 2
                ORDER BY pokemon_moves.level ASC") do |row|
                moveId=row['move_id']
                level=row['level']
                name=row['name']
                type=row['identifier']
                levelMoves["#{moveId}"] << level
                levelMoves["#{moveId}"] << name
                levelMoves["#{moveId}"] << type
            end
    pkm.level_moves=levelMoves
end

def pkm_get_evyield(pokemonId, db, pkm)
    evYield = Hash.new
    db.results_as_hash = true
    db.execute("SELECT stats.identifier, pokemon_stats.effort 
                FROM pokemon INNER JOIN pokemon_stats ON pokemon.id = pokemon_stats.pokemon_id
                     INNER JOIN stats ON pokemon_stats.stat_id = stats.id
                WHERE pokemon.id = #{pokemonId}
                AND effort > 0
                ") do |row|
                stat = row['identifier']
                val = row['effort']
                evYield[stat] = val
            end
    pkm.ev_yield = evYield
end

def pkm_get_hm_moves(pokemonId, generationId, db, pkm)
    hm_moves = Hash.new{|h, k| h[k] = []}
    db.results_as_hash = true
    db.execute("SELECT DISTINCT pokemon_moves.move_id, items.identifier AS machine_name, moves.identifier AS move_name, 
                types.identifier AS type
            FROM pokemon INNER JOIN pokemon_moves ON pokemon.id = pokemon_moves.pokemon_id
                 INNER JOIN moves ON pokemon_moves.move_id = moves.id
                 INNER JOIN types ON moves.type_id = types.id
                 INNER JOIN machines ON pokemon_moves.move_id = machines.move_id
                 INNER JOIN items ON machines.item_id = items.id
                 INNER JOIN move_names ON pokemon_moves.move_id = move_names.move_id
                 INNER JOIN version_groups ON pokemon_moves.version_group_id = version_groups.id
                 INNER JOIN generations ON version_groups.generation_id = generations.id
                 INNER JOIN pokemon_move_methods ON pokemon_moves.pokemon_move_method_id = pokemon_move_methods.id AND machines.version_group_id = version_groups.id
            WHERE pokemon.id = #{pokemonId}
            AND pokemon_move_methods.id = 4
            AND generations.id = #{generationId}
            AND move_names.local_language_id = 9
            AND machine_name LIKE \"hm%\"") do |row|
                moveId = row['move_id']
                machineNumber = row['machine_name'].slice(2..-1)
                name = row["move_name"]
                type = row["type"]
                hm_moves["#{moveId}"] << machineNumber
                hm_moves["#{moveId}"] << name
                hm_moves["#{moveId}"] << type
            end
    pkm.hm_moves=hm_moves
end

def pkm_get_tm_moves(pokemonId, generationId, db, pkm)
    tm_moves = Hash.new{|h, k| h[k] = []}
    db.results_as_hash = true
    db.execute("SELECT DISTINCT pokemon_moves.move_id, items.identifier AS machine_name, moves.identifier AS move_name, 
                types.identifier AS type
            FROM pokemon INNER JOIN pokemon_moves ON pokemon.id = pokemon_moves.pokemon_id
                 INNER JOIN moves ON pokemon_moves.move_id = moves.id
                 INNER JOIN types ON moves.type_id = types.id
                 INNER JOIN machines ON pokemon_moves.move_id = machines.move_id
                 INNER JOIN items ON machines.item_id = items.id
                 INNER JOIN move_names ON pokemon_moves.move_id = move_names.move_id
                 INNER JOIN version_groups ON pokemon_moves.version_group_id = version_groups.id
                 INNER JOIN generations ON version_groups.generation_id = generations.id
                 INNER JOIN pokemon_move_methods ON pokemon_moves.pokemon_move_method_id = pokemon_move_methods.id AND machines.version_group_id = version_groups.id
            WHERE pokemon.id = #{pokemonId}
            AND pokemon_move_methods.id = 4
            AND generations.id = #{generationId}
            AND move_names.local_language_id = 9
            AND machine_name LIKE \"tm%\"") do |row|
                moveId = row['move_id']
                machineNumber = row['machine_name'].slice(2..-1)
                name = row["move_name"]
                type = row["type"]
                tm_moves["#{moveId}"] << machineNumber
                tm_moves["#{moveId}"] << name
                tm_moves["#{moveId}"] << type
            end
    pkm.tm_moves=tm_moves
end

def pkm_get_tutor_moves(pokemonId, generationId, db, pkm)
    tutor_moves = Hash.new{|h, k| h[k] = []}
    db.results_as_hash = true
    db.execute("SELECT DISTINCT pokemon_moves.move_id, moves.identifier AS move_name, types.identifier AS move_type
                FROM pokemon INNER JOIN pokemon_moves ON pokemon.id = pokemon_moves.pokemon_id
                     INNER JOIN moves ON pokemon_moves.move_id = moves.id
                     INNER JOIN types ON moves.type_id = types.id
                     INNER JOIN version_groups ON version_groups.id = pokemon_moves.version_group_id
                     INNER JOIN generations ON version_groups.generation_id = generations.id
                     INNER JOIN pokemon_move_methods ON pokemon_moves.pokemon_move_method_id = pokemon_move_methods.id
                     INNER JOIN pokemon_species_names ON pokemon.species_id = pokemon_species_names.pokemon_species_id
                WHERE pokemon_move_method_id = 3
                AND generations.id =#{generationId}
                AND pokemon_species_names.local_language_id = 9
                AND pokemon.id = #{pokemonId}
                ORDER BY move_name") do |row|
                moveId = row['move_id']
                name = row["move_name"]
                type = row["move_type"]
                tutor_moves["#{moveId}"] << name
                tutor_moves["#{moveId}"] << type
            end
    pkm.tutor_moves=tutor_moves
end

def pkm_get_gender(pokemonId, db, pkm)
    row = db.get_first_value("SELECT pokemon_species.gender_rate
                FROM pokemon INNER JOIN pokemon_species ON pokemon.species_id = pokemon_species.id
                WHERE pokemon.id = #{pokemonId}")
    gender = (row >= 0 ? (row/8.0)*100.0 : "genderless")
    pkm.female_rate = gender
end

def pkm_object(pkm)
    pokemon = {
        #"pokemonId"=>pkm.pokemonId,
        :slug=>pkm.slug,
        :metadata=>{
            :name=>pkm.name,
            :jname=>pkm.jname,
            :nationalId=>pkm.national_id,
            :generation=>pkm.generation,
            :height=>pkm.height,
            :weight=>pkm.weight,
            :abilities=>pkm.abilities,
            # we don't want form if they don't have
            # multiple forms
            :form=>pkm.form,
            :eggCycles=>pkm.egg_cycles,
            :eggGroup=>pkm.egg_group,
            :femaleGenderPercent=>pkm.female_rate,
            :species=>pkm.species,
            :type=>pkm.type,
            :hp=>pkm.hp,
            :attack=>pkm.attack,
            :defense=>pkm.defense,
            :specialAttack=>pkm.special_attack,
            :specialDefense=>pkm.special_defense,
            :speed=>pkm.speed,
            # we don't want chain if they don't evolve
            :dex_description=>pkm.dex_description,
            :location=>pkm.location
        },
        :evolutionChain=>pkm.evolution_chain,
        :moves=>{
            :levelMoves=>pkm.level_moves,
            :hmMoves=>pkm.hm_moves,
            :tmMoves=>pkm.tm_moves,
            :tutor_moves=>pkm.tutor_moves
        }
    }
    return pokemon
    
end

def pkm_get_egg_cycles(pokemonId, db, pkm)
    row = db.get_first_value("SELECT pokemon_species.hatch_counter
            FROM pokemon INNER JOIN pokemon_species ON pokemon.species_id = pokemon_species.id
            WHERE pokemon.id = #{pokemonId}")
    pkm.egg_cycles = row+1
end

def pkm_get_form(pokemonId, db, pkm)
    row = db.get_first_value("SELECT pokemon_forms.form_identifier
                FROM pokemon INNER JOIN pokemon_forms ON pokemon.id = pokemon_forms.pokemon_id
                WHERE pokemon.id = #{pokemonId}")
    pkm.form = row
end

def pkm_get_location(pokemonId, gen5_locations, generationId, db, pkm)
    location = Hash.new
    if(generationId == 5 && pkm.national_id <= 649)
        # National Dex #,Location Black,Location White,Location Black 2,Location White 2
        location["black"] = gen5_locations[pkm.national_id][1]
        location["white"] = gen5_locations[pkm.national_id][2]
        location["black2"] = gen5_locations[pkm.national_id][3]
        location["white2"] = gen5_locations[pkm.national_id][4]
    else
        # pkm_get_veekun_location(pokemonId, generationId, db, pkm)
    end
    pkm.location = location
end

def my_constructor(pkmID, form, db, pkm, generationID, gen5_locations)

    pkm_set_id(pkmID,form, db, pkm)         # ID
    pkm_get_national_id(pkmID, db, pkm)     # national id
    pkm_get_form(pkmID, db, pkm)            # Form
    pkm_get_egg_group(pkmID, db, pkm)       # egg group
    pkm_get_height_weight(pkmID, db, pkm)   # Height/Weight
    pkm_get_name(pkmID, db, pkm)            # Name
    pkm_slug(pkm)                           # slug
    pkm_get_jname(pkmID, db, pkm)           # JName
    pkm_get_stats(pkmID, db, pkm)           # Stats
    pkm_get_type(pkmID, db, pkm)            # Type
    pkm_get_ability(pkmID, db, pkm)         # Ability
    pkm_get_species(pkmID, db, pkm)         # Species
    pkm_get_level_moves_by_generation(pkmID, generationID, db, pkm) # Level Moves
    pkm_get_hm_moves(pkmID, generationID, db, pkm)              # HM Moves
    pkm_get_tm_moves(pkmID, generationID, db, pkm)              # TM Moves
    pkm_get_tutor_moves(pkmID, generationID, db, pkm)           # Tutor Moves
    pkm_get_evolution_chain(pkmID, db, pkm)                 # Evolution Chain
    pkm_get_evyield(pkmID, db, pkm)         # EV Yield
    pkm_get_gender(pkmID, db, pkm)          # Gender
    pkm_get_egg_cycles(pkmID, db, pkm)      # Egg Cycles
    pkm_get_dex_desc(pkmID, generationID, db, pkm)          # Dex description
    pkm_get_location(pkmID, gen5_locations, generationID, db, pkm)
end

def save_to_mongo()
    dir = File.expand_path File.dirname(__FILE__)
    gen5_locations = CSV.read(dir+"/pokedex-locations-bw.csv")
    jump = "\r\e[0K"    # That is return to beginning of line and use the
                        # ANSI clear command "\e" or "\003"
    # instanciate new pokemon
    pkm = Pokemon.new()
    # new db connection
    db = SQLite3::Database.new( dir+"/pokemon-sqlite/pokedex.sqlite" )
    #db = SQLite3::Database.new( "/Users/fvelazquez/Code/pokemondb/pokedex/pokedex/data/pokedex.sqlite" )
    # new mongo connection
    mongodb = Mongo::Connection.new.db("pokedex")
    coll = mongodb["pokemon"]
    coll.remove
    generationID=1
    form="1"
    for i in 1..5 do
        generationID=i
        pkm.generation = generationID
        for i in 1..151 do
            pkmID=i
            my_constructor(pkmID, form, db, pkm, generationID, gen5_locations)
            doc = pkm_object(pkm)
            print jump + "inserting Generation #{generationID} #{pkm.national_id} #{pkm.name} #{pkm.jname}"
            id = coll.insert(doc)
        end
    end
    for i in 2..5 do
        generationID=i
        pkm.generation = generationID
        for i in 152..251 do
            pkmID=i
            my_constructor(pkmID, form, db, pkm, generationID, gen5_locations)
            doc = pkm_object(pkm)
            print jump + "inserting Generation #{generationID} #{pkm.national_id} #{pkm.name} #{pkm.jname}"
            id = coll.insert(doc)
        end
    end
    for i in 3..5 do
        generationID=i
        pkm.generation = generationID
        for i in 252..386 do
            pkmID=i
            my_constructor(pkmID, form, db, pkm, generationID, gen5_locations)
            doc = pkm_object(pkm)
            print jump + "inserting Generation #{generationID} #{pkm.national_id} #{pkm.name} #{pkm.jname}"
            id = coll.insert(doc)
        end
    end
    for i in 4..5 do
        generationID=i
        pkm.generation = generationID
        for i in 387..493 do
            pkmID=i
            my_constructor(pkmID, form, db, pkm, generationID, gen5_locations)
            doc = pkm_object(pkm)
            print jump + "inserting Generation #{generationID} #{pkm.national_id} #{pkm.name} #{pkm.jname}"
            id = coll.insert(doc)
        end
    end
    for i in 5..5 do
        generationID=i
        pkm.generation = generationID
        for i in 494..649 do
            pkmID=i
            my_constructor(pkmID, form, db, pkm, generationID, gen5_locations)
            doc = pkm_object(pkm)
            print jump + "inserting Generation #{generationID} #{pkm.national_id} #{pkm.name} #{pkm.jname}"
            id = coll.insert(doc)
        end
    end

    # for pokemon id 650...673
    for i in 5..5 do
        pkm.generation = 5
        for i in 650..673
            pkmID=i
            my_constructor(pkmID, form, db, pkm, generationID, gen5_locations)
            pkm_get_form(pkmID, db, pkm)
            doc = pkm_object(pkm)
            print jump + "inserting Generation #{generationID} #{pkm.national_id} #{pkm.name} #{pkm.jname}"
            id = coll.insert(doc)
        end
    end
    puts "\n\tTotal documents saved to pokemon collection => #{coll.count}"
    
    #puts "\n\tAdding our special guests..."
    #guestPkm1 = Pokemon.new()
    #guestPkm2 = Pokemon.new()

    #add_first_guest(guestPkm1)
    #add_second_guest(guestPkm2)

    #doc = pkm_object(guestPkm1)
    #puts "doc: #{doc}"
    #id = coll.insert(doc)
    #doc = pkm_object(guestPkm2)
    #puts "doc: #{doc}"
    #id = coll.insert(doc)

end

def add_first_guest(pkm)

types = Hash.new
types["type_1"] = "fire"
pkm.name = "Manish"
pkm.slug = "manish"
pkm.generation = 5
pkm.hp = 1000
pkm.attack = 255
pkm.defense = 255
pkm.special_attack = 255
pkm.special_defense = 255
pkm.speed = 255
pkm.national_id = 650
pkm.type = types
end

def add_second_guest(pkm)

types = Hash.new
types["type_1"] = "grass"
pkm.name = "Nick"
pkm.slug = "nick"
pkm.generation = 5
pkm.hp = 100
pkm.attack = 1
pkm.defense = 1
pkm.special_attack = 1
pkm.special_defense = 1
pkm.speed = 1
pkm.national_id = 651
pkm.type = types
end

save_to_mongo()
