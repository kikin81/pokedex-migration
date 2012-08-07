load 'move.rb'
require 'sqlite3'
require 'mongo'

Dir = File.expand_path File.dirname(__FILE__)
db = SQLite3::Database.new( Dir+"/pokemon-sqlite/pokedex.sqlite" )
move = Move.new()

def move_metadata(db, move)
    mongodb = Mongo::Connection.new.db("pokedex")
    coll = mongodb["moves"]
    db.results_as_hash = true
    db.execute("SELECT DISTINCT moves.id, moves.identifier AS move_name, 
                    types.identifier AS type, move_damage_classes.identifier AS category, 
                    moves.power, moves.accuracy, moves.pp
                FROM moves INNER JOIN move_damage_classes ON moves.damage_class_id = move_damage_classes.id
                     INNER JOIN types ON moves.type_id = types.id") do |row|
            move.move_id = row['id']
            move.name = row['move_name']
            move.type=row['type']
            move.category=row['category']
            move.power=row['power']
            move.accuracy=row['accuracy']
            move.pp=row['pp']
            move.description=move_description(move, row, db)
            puts move.inspect
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

move_metadata(db, move)