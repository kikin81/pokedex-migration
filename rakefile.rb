task :default do
    FileList['migrate*.rb'].each { |file| ruby file }
end