#!/bin/env ruby

# Helper function to pre-process dictionaries, to avoid repeated checks from entries being
# in multiple dictionaries, as well as multiple entries creating the same hash.
# The later might happen, since the generic hashing function used only considers the first
# 8 chars of the password.
def preprocess_dictionaries(dictionaries, overwrite = false)
    # The passwords get temporarily saved in this hash array
    passwords = {}

    dictionaries.each_with_index do |dict_path, index|
        if(index == 0)
            unless(File.exists?(dict_path + "_processed") and not overwrite)
                # Open dictionary and read all entries up to 8 chars into hashmap
                dict = File.open(dict_path, "r")

                # Process each password and add to hash array if not there yet
                dict.each do |line|
                    pass = line.chomp.slice(0, 8)
                    passwords[pass] = 0 if passwords[pass].nil?
                end

                # Save processed passwords as a new file to reference later
                dict_processed = File.open("#{dict_path}_processed", "w")
                passwords.each {|pass, value| dict_processed.write("#{pass}\n")}
                dict_processed.close()
                dict.close()
            end
        
        else # index > 0
            unless(File.exists?(dict_path + "_processed") and not overwrite)
                # The passwords will be stored in a separate hash array
                next_passwords = {}

                # Open dictionary and read all entries up to 8 chars into hashmap
                dict = File.open(dict_path, "r")

                # Process each password and add to hash array if not in previous hash yet
                dict.each do |line|
                    pass = line.chomp.slice(0, 8)
                    if passwords[pass].nil?
                        next_passwords[pass] = 0
                        passwords[pass] = 0
                    end
                end

                # Save processed passwords as a new file to reference later
                dict_processed = File.open("#{dict_path}_processed", "w")
                next_passwords.each {|pass, value| dict_processed.write("#{pass}\n")}
                dict_processed.close()
                dict.close()
            end
        end
    end
end


# Helper function to call when cracking one single username's password hash
def crack_account(user, salt, hash, dict_lines, cracked_accounts, temp_output)
    catch :found_hash do
        dict_lines.each do |pass|
            if(pass.crypt(salt) == hash)
                puts "  Matching hashed password found: >#{user}< -> >#{pass}<"
                cracked_accounts[user] = pass
                temp_output = File.open(temp_output, "a")
                temp_output.write("#{user}::||::#{pass}\n")
                temp_output.close
                throw :found_hash
            end
        end
    end
end


#########################
##  Simple-Cracker.rb  ##
#########################

# Define paths
passwd_path = "passwd_sim"
dictionaries = [
    "dicts/01-english-simple",
    "dicts/02-german-lower-small",
    "dicts/03-german-mixed-small",
    "dicts/04-german-alnum-small",
    "dicts/05-german-idioms",
    "dicts/06-turkish-mixed",
    "dicts/07-turkish-lower",
    "dicts/08-german-cap-small",
    "dicts/09-german-cap-large",
    "dicts/10-german-lower-large",
    "dicts/11-uniqpass",
    "dicts/12-rockyou",
]
out_file = "cracked/results"
cracked_accounts = {}

# Pre-process dictionaries if wanted
preprocess_dictionaries(dictionaries)

# Clean temporary output file
temp_output = File.open(out_file, "w")
temp_output.write("")
temp_output.close()

# Loop over passwd file and try to crack each user
passwd_lines = File.readlines(passwd_path)
temp_output = File.open("#{passwd_path}_temporary_cracked_file", "w")

dictionaries.each do |dict_path|
    puts "Using processed dictionary from #{dict_path}: #{dict_path}_processed"
    dict_lines = File.readlines("#{dict_path}_processed")
    dict_lines.each{|line| line.chomp!}
    passwd_lines.each_with_index do |entry, index|
        matches = entry =~ /(\w+):((.{2}).*):.*:.*:.*:.*:.*/
        user = $1
        hash = $2
        salt = $3
        puts "(#{index}/#{passwd_lines.size}) Processing user #{user} with dict #{dict_path}"
        crack_account(user, salt, hash, dict_lines, cracked_accounts, "temporary_output")
    end
end

# Save finalized output to file 
cracked_accounts.each do |user, pass|
    File.write(out_file, "#{user}::||::#{pass}\n")
end