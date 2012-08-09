require 'rubygems'
require 'sqlite3'
load 'type.rb'
require 'json'
require 'mongo'

dir = File.expand_path File.dirname(__FILE__)

type = Type.new()

db = SQLite3::Database.new( dir+"/pokemon-sqlite/pokedex.sqlite" )



def crazy_type_method(type, db)
    jump = "\r\e[0K"
    mongodb = Mongo::Connection.new.db("pokedex")
    coll = mongodb["type"]
    coll.remove
    db.results_as_hash = true
    db.execute("SELECT type_efficacy.damage_type_id, 
				type_efficacy.target_type_id, 
				type_efficacy.damage_factor, 
				types.identifier
					FROM types 
						INNER JOIN type_efficacy ON types.id = type_efficacy.damage_type_id") do |row|
            type.current_type = get_type_name(row['damage_type_id'], db)
            type.opposed_type = get_type_name(row['target_type_id'], db)
            type.damage_factor = row['damage_factor']
            doc = type_object(type)
            print jump + "inserting type record #{type.current_type} against #{type.opposed_type} -> #{type.damage_factor}"
            id = coll.insert(doc)
        end
    puts "Total documents saved to type collection => #{coll.count}"
end

def get_type_name(typeId, db)
    type_name = ""
    row = db.execute("SELECT types.identifier
                FROM types
                WHERE types.id = #{typeId}");
    type_name = row[0][0]
    #move_name = move_name.sub( "-", " " ).split(" ").each{|word| word.capitalize!}.join(" ")
    return type_name
end

def type_object(type)
    type = {
        :current_type=>type.current_type,
        :opposed_type=>type.opposed_type,
        :damage_factor=>type.damage_factor
    }
    return type
end

crazy_type_method(type, db)