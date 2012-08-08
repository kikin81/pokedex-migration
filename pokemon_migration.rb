require 'rubygems'
require 'sqlite3'
load 'pokemon.rb'
require 'json'
require 'mongo'

Dir = File.expand_path File.dirname(__FILE__)

# set a globalID
pkmID= "1"
generationID="5"
form="1"

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

def pkm_get_height_weight(pokemonId, db, pkm)
    db.results_as_hash = true
    db.execute( "SELECT height, weight 
                 FROM pokemon
                 WHERE id = #{pokemonId}") do |row|
        pkm.height = row['height']
        pkm.weight = row['weight']
        
    end
end

def pkm_get_name(pokemonId, db, pkm)
    row = db.get_first_value("SELECT pokemon_species_names.name
                            FROM pokemon INNER JOIN pokemon_species_names ON pokemon.species_id = pokemon_species_names.pokemon_species_id
                            WHERE pokemon_species_names.local_language_id = 9
                            AND pokemon.species_id = #{pokemonId}")
    # if we have a result
    pkm.name = row.downcase
end

def pkm_get_jname(pokemonId, db, pkm)
    row = db.get_first_value("SELECT pokemon_species_names.name
                            FROM pokemon INNER JOIN pokemon_species ON pokemon.species_id = pokemon_species.id
                              INNER JOIN pokemon_species_names ON pokemon_species.id = pokemon_species_names.pokemon_species_id
                            WHERE pokemon.id=#{pokemonId} 
                            AND pokemon_species_names.local_language_id=1")
    pkm.jname = row[0][0]
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
    rows = db.execute("SELECT abilities.identifier
                        FROM pokemon INNER JOIN pokemon_abilities ON pokemon.id = pokemon_abilities.pokemon_id
                             INNER JOIN abilities ON pokemon_abilities.ability_id = abilities.id
                        WHERE pokemon.id = #{pokemonId}") do |row|
                abilities["ability_#{x}"] = row['identifier']
                x = x+1
            end
    pkm.ability = abilities

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

def pkm_get_machine_moves(pokemonId, generationId, db, pkm)
    machineMoves = Hash.new{|h, k| h[k] = []}
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
            AND move_names.local_language_id = 9") do |row|
                moveId = row['move_id']
                machineNumber = row['machine_name']
                name = row["move_name"]
                type = row["type"]
                machineMoves["#{moveId}"] << machineNumber
                machineMoves["#{moveId}"] << name
                machineMoves["#{moveId}"] << type
            end
    pkm.machine_moves=machineMoves
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
        :metadata=>{
            :name=>pkm.name,
            :jname=>pkm.jname,
            :generation=>pkm.generation,
            :height=>pkm.height,
            :weight=>pkm.weight,
            # we don't want form if they don't have
            # multiple forms
            :form=>pkm.form,
            :eggCycles=>pkm.egg_cycles,
            :femaleGenderPercent=>pkm.female_rate,
            :species=>pkm.species,
            :type=>pkm.type,
            :hp=>pkm.hp,
            :attack=>pkm.attack,
            :defense=>pkm.defense,
            :specialAttack=>pkm.special_attack,
            :specialDefence=>pkm.special_defense,
            :speed=>pkm.speed,
            :nationalId=>pkm.national_id,
            # we don't want chain if they don't evolve
            :evolutionChain=>pkm.evolutionChain,
            :dex_description=>pkm.dex_description
            
        },
        :moves=>{
            :levelMoves=>pkm.level_moves,
            :machineMoves=>pkm.machine_moves
        }
    }
    # puts JSON.pretty_generate(pokemon)
    return pokemon
    
end

def pkm_get_egg_cycles(pokemonId, db, pkm)
    row = db.get_first_value("SELECT pokemon_species.hatch_counter
            FROM pokemon INNER JOIN pokemon_species ON pokemon.species_id = pokemon_species.id
            WHERE pokemon.id = #{pokemonId}")
    pkm.egg_cycles = row+1
end

def pkm_get_form(pokemonId, db, pkm)
    form = Hash.new
    db.results_as_hash = true
    db.execute("SELECT pokemon_forms.pokemon_id, pokemon_forms.form_identifier
                FROM pokemon INNER JOIN pokemon_forms ON pokemon.id = pokemon_forms.pokemon_id
                WHERE pokemon.species_id = #{pokemonId}") do |row|
        end
end

def my_constructor(pkmID, form, db, pkm, generationID)

    pkm_set_id(pkmID,form, db, pkm)         # ID
    pkm_get_national_id(pkmID, db, pkm)
    pkm_get_height_weight(pkmID, db, pkm)   # Height/Weight
    pkm_get_name(pkmID, db, pkm)            # Name
    pkm_get_stats(pkmID, db, pkm)           # Stats
    pkm_get_type(pkmID, db, pkm)            # Type
    pkm_get_ability(pkmID, db, pkm)         # Ability
    pkm_get_species(pkmID, db, pkm)         # Species
    pkm_get_level_moves_by_generation(pkmID, generationID, db, pkm) # Level Moves
    pkm_get_machine_moves(pkmID, generationID, db, pkm)             # Machine Moves
    pkm_get_evyield(pkmID, db, pkm)         # EV Yield
    pkm_get_gender(pkmID, db, pkm)          # Gender
    pkm_get_egg_cycles(pkmID, db, pkm)      # Egg Cycles
    pkm_get_form(pkmID, db, pkm)            # Form
    pkm_get_dex_desc(pkmID, generationID, db, pkm)
end

def save_to_mongo()

    # instanciate new pokemon
    pkm = Pokemon.new()
    # new db connection
    db = SQLite3::Database.new( Dir+"/pokemon-sqlite/pokedex.sqlite" )
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
            pkmID="#{i}"
            my_constructor(pkmID, form, db, pkm, generationID)
            doc = pkm_object(pkm)
            puts "inserting #{pkm.name}"
            id = coll.insert(doc)
        end
    end
    puts "Total documents saved. #{coll.count}"
end

save_to_mongo()
