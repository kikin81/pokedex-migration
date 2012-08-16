load 'evolution.rb'
require 'sqlite3'
require 'json'
require 'mongo'

dir = File.expand_path File.dirname(__FILE__)

evolution = Evolution.new()

db = SQLite3::Database.new( dir+"/pokemon-sqlite/pokedex.sqlite" )
#db = SQLite3::Database.new( "/Users/fvelazquez/Code/pokemondb/pokedex/pokedex/data/pokedex.sqlite" )
def crazy_evolution_method(evolution, db)
    jump = "\r\e[0K"
    mongodb = Mongo::Connection.new.db("pokedex")
    coll = mongodb["evolutions"]
    coll.remove
    db.results_as_hash = true
    db.execute("SELECT pokemon_species.evolves_from_species_id, pokemon_species.evolution_chain_id, pokemon_evolution.*
                FROM pokemon INNER JOIN pokemon_species ON pokemon.species_id = pokemon_species.id
                     INNER JOIN pokemon_evolution ON pokemon_evolution.evolved_species_id = pokemon_species.id
                     INNER JOIN evolution_triggers ON pokemon_evolution.evolution_trigger_id = evolution_triggers.id") do |row|
            evolution.evolutionChain = row['evolution_chain_id']
            evolution.from = row['evolves_from_species_id']
            evolution.from_name = pkm_get_name(row['evolves_from_species_id'], db)
            evolution.to_name = pkm_get_name(row['evolved_species_id'], db)
            evolution.to = row['evolved_species_id']
            evolution.how = crazy_how_method(evolution, row, db)
            doc = evolution_object(evolution)
            print jump + "inserting from #{evolution.from} to #{evolution.to}"
            id = coll.insert(doc)
        end
    puts "\n\tTotal documents saved to evolution collection => #{coll.count}"
end

def pkm_get_name(pokemonId, db)
    pokemon_name = db.get_first_value("SELECT pokemon_species_names.name
                            FROM pokemon INNER JOIN pokemon_species_names ON pokemon.species_id = pokemon_species_names.pokemon_species_id
                            WHERE pokemon_species_names.local_language_id = 9
                            AND pokemon.species_id = #{pokemonId}")
    # if we have a result
    return pokemon_name.downcase
end

def get_item_name(itemId, db)
    item_name = ""
    row = db.execute("SELECT items.identifier
                FROM items
                WHERE items.id = #{itemId}");
    item_name = row[0][0]
    item_name = item_name.sub( "-", " " ).split(" ").each{|word| word.capitalize!}.join(" ")
    return item_name
end

def get_move_name(moveId, db)
    move_name = ""
    row = db.execute("SELECT moves.identifier
                FROM moves
                WHERE moves.id = #{moveId}");
    move_name = row[0][0]
    move_name = move_name.sub( "-", " " ).split(" ").each{|word| word.capitalize!}.join(" ")
    return move_name
end

def get_location_name(location, db)
    location_name = ""
    row = db.execute("SELECT locations.identifier
                FROM locations
                WHERE locations.id = #{location}");
    location_name = row[0][0]
    location_name = location_name.sub( "-", " " ).split(" ").each{|word| word.capitalize!}.join(" ")
    return location_name
end

def crazy_how_method(evolution, row, db)
    evolution_method = ""
    case evolution_trigger = row['evolution_trigger_id']
    when 1
        evolution_method += "Level up"
    when 2
        evolution_method += "Trade"
    when 3
        evolution_method += "Use"
    when 4
        evolution_method += "Level up 20, with empty spot in party"
    end

    # By Item
    case item=row['trigger_item_id']
    when nil
    else
        evolution_method += " "
        evolution_method += get_item_name(item, db)
    end
    # Level Case
    case min_level = row['minimum_level']
    when nil
    else evolution_method += " #{min_level}"
    end
    # gender
    case gender = row['gender']
    when nil
    else
        evolution_method += " #{gender}"
    end
    # location
    case location = row['location_id']
    when nil
    else
        evolution_method += " around "
        evolution_method += get_location_name(location, db)
    end
    # held item
    case held_item = row['held_item_id']
    when nil
    else
        evolution_method += " while holding "
        evolution_method += get_item_name(held_item, db)
    end
    # time of day
    case time_of_day = row['time_of_day']
    when nil
    else
        evolution_method += " during #{time_of_day}"
    end
    # known move
    case move = row['known_move_id']
    when nil
    else
        evolution_method += " after "
        evolution_method += get_move_name(move, db)
        evolution_method += " learned"
    end
    # minimum_happiness
    case happiness = row['minimum_happiness']
    when nil
    else
        evolution_method += " Max Happiness"
    end
    # minimum_beauty
    case beauty = row['minimum_beauty']
    when nil
    else
        evolution_method += "beauty"
    end
    # stats
    case stats = row['relative_physical_stats']
    when nil
    when 1
        evolution_method += ", Attack > Defense"
    when -1
        evolution_method += ", Attack < Defense"
    when 0
        evolution_method += ", Attack = Defense"
    end
    # party species
    case party_species = row['party_species_id']
    when nil
    when 223
        evolution_method += "with Remoraid in the party"
    end
    # trade
    case trade_species = row['trade_species_id']
    when nil
    when 616
        evolution_method += " in exchange for Shelmet"
    when 588
        evolution_method += " in exchange for Karrablast"
    end
    return evolution_method
end

def evolution_object(evolution)
    evolution = {
        :evolutionChain=>evolution.evolutionChain,
        :from=>evolution.from,
        :fromName=>evolution.from_name,
        :to=>evolution.to,
        :toName=>evolution.to_name,
        :how=>evolution.how
    }
    return evolution
end

crazy_evolution_method(evolution, db)
