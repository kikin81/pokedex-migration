load 'move.rb'
require 'sqlite3'
require 'mongo'

def move_metadata(db, move, coll)
    mongodb = Mongo::Connection.new.db("pokedex")
    coll = mongodb["moves"]
    db.results_as_hash = true
    db.execute("SELECT DISTINCT moves.id, moves.identifier AS move_name, 
                    types.identifier AS type, move_damage_classes.identifier AS category, 
                    moves.power, moves.accuracy, moves.pp
                FROM moves INNER JOIN move_damage_classes ON moves.damage_class_id = move_damage_classes.id
                     INNER JOIN types ON moves.type_id = types.id
                WHERE moves.id < 10000") do |row|
            move.move_id = row['id']
            move.name = row['move_name']
            move.type=row['type']
            move.category=row['category']
            move.power=row['power']
            move.accuracy=row['accuracy']
            move.pp=row['pp']
            move.description=move_description(move, row, db)
            doc = move_object(move)
            puts doc.inspect
            puts "inserting #{move.name}"
            id = coll.insert(doc)
        end
end


def move_description(move, row, db)
    g = "Gold/Silver/Crystal"
    r = "Ruby/Sapphire/Emerald"
    f = "FireRed/LeafGreen"
    d = "Diamond/Pearl/PlatinumHeartGold/SoulSilver"
    b = "Black/White"
    moveDescription = Hash.new
    db.results_as_hash = true
    db.execute("SELECT
                    version_groups.id as group_id,
                    moves.identifier AS name, 
                    move_flavor_text.flavor_text, 
                    versions.identifier AS game_name
                FROM moves INNER JOIN move_flavor_text ON moves.id = move_flavor_text.move_id
                     INNER JOIN version_groups ON move_flavor_text.version_group_id = version_groups.id
                     INNER JOIN versions ON versions.version_group_id = version_groups.id
                WHERE moves.id = #{move.move_id}
                GROUP BY version_groups.id") do |row|
            case row['group_id']
            when 3 # g/s/c
                moveDescription[g]=row['flavor_text']
            when 5 # r/s/e
                moveDescription[r]=row['flavor_text']
            when 7 # lg/fr
                moveDescription[f]=row['flavor_text']
            when 8 # d/p/p/ss/hg
                moveDescription[d]=row['flavor_text']
            when 11 # b/w
                moveDescription[b]=row['flavor_text']
            end
        end
    move.description = moveDescription
end

def save_to_mongo()
    # instanciate new move object
    move = Move.new()
    # new db connection
    dir = File.expand_path File.dirname(__FILE__)
    db = SQLite3::Database.new( dir+"/pokemon-sqlite/pokedex.sqlite" )
    # new mongo connection
    mongodb = Mongo::Connection.new.db("pokedex")
    coll = mongodb["moves"]
    move_metadata(db, move, coll)
end

def move_object(move)
    move = {
        :moveId=> move.move_id,
        :metadata=>{
            :name=>move.name,
            :type=>move.type,
            :category=>move.category,
            :power=>move.power,
            :accuracy=>move.accuracy,
            :pp=>move.pp,
            :description=>move.description
        }
    }

    return move
end

save_to_mongo()
