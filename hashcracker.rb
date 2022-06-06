# Hey there.
#
# This is not a hash cracking tool - it's simply a script
# that I had to write for uni.
#
# Usage:
# ruby hashcracker.rb
# or
# ruby hashcracker.rb < [path_to_wordlist]
#
# You can either provide a single wordlist path via stdin,
# or you can add multiple entries to the _dictionaries_
# array.
#
# When using multiple dictionariers, these can be pre-
# processed to avoid duplicate entries and ignore any 
# passwords longer than 8 chars.
# This has to do with the hash function used for this task
# only considering the initial 8 chars.


############
# SETTINGS #
############
parallelize = true # Use Parallel gem to increase performance
preprocess = true # Clean dictionaries before using

if(parallelize)
    require 'rubygems'
    require 'parallel'
end


####################
# HELPER FUNCTIONS #
####################

# Pre-processing = removing duplicate entries + reducing entries to 8 chars long
def preprocess_dictionaries(dict_paths)
    passwords = {}

    dict_paths.each_with_index do |dict_path, index|
        puts "Processing #{dict_path}"
        dict = File.open(dict_path, "r")
        processed_dict_path = dict_path + "_processed"
        dict_processed = File.open(processed_dict_path, "w")

        # Clean current iteration
        next_passwords = {}

        # Save into hash map
        dict.each do |line|
            pass = line.chomp.slice(0, 8)
            next_passwords[pass] = 0 if passwords[pass].nil?
            passwords[pass] = 0
        end

        # Write to file
        puts "=> saving #{next_passwords.size} passwords to #{processed_dict_path}"
        next_passwords.each {|pass, value| dict_processed.write("#{pass}\n")}
        
        # Clean up for next iteration
        dict_processed.close()
        dict.close()
    end
end

# Perform the dictionary attack against the provided user's credentials
def crack_account(user, hash, wordlist, cracked_accounts, out_file)
    # Grab salt
    salt = hash[0,2]

    # Run wordlist
    wordlist.each do |pass|
        if(pass.crypt(salt) == hash)
            cracked_accounts[user] = pass
            out_file.write("#{user}|#{pass}\n")
            puts "  User >#{user}< cracked with password >#{pass}<"
            return true
        end
    end
    return false
end

# Output some useful statistics
def print_stats(out_file_path, t)
    # Timer
    t = (Time.now - t).to_f.round(4)

    # Accounts
    cracked = File.readlines(out_file_path)
    cracked.each {|line| line.chomp!}
    
    # Total number
    total_cracked = cracked.size

    # Weak passwords
    weak_count = 0
    cracked.each do |line|
        line =~ /\|(.*)/
        if($1.size < 8)
            weak_count += 1
        end
    end

    puts "Finished!"
    puts "  Took #{t} seconds"
    puts "  Cracked #{total_cracked} accounts"
    puts "  #{weak_count} users have short passwords (7 chars or less)"
end

################
# 06-passwd.rb #
################

def main

    # Start timer
    t = Time.now()

    # Define paths
    passwd_path = "passwd_sim"
    out_file_path = "results_#{Time.now.strftime("%Y%m%d%H%M%S")}"
    dictionaries = [
        # Insert dictionaries here
        "dicts/00-cracked",
        "dicts/01-english-simple",
        "dicts/02-german-lower-small",
        "dicts/07-turkish-lower",
        "dicts/08-german-cap-small",
        "dicts/09-german-cap-large",
        "dicts/10-german-lower-large",
        "dicts/11-100k",
        "dicts/12-uniqpass",
        "dicts/13-rockyou",
    ]

    # Check if the user gave us a wordlist
    manual_wordlist = false
    if not STDIN.tty?
        puts "Reading wordlist from user input"
        user_input = STDIN.read.split("\n")
        manual_wordlist = true
        puts "=> Found #{user_input.size} words in user input"
    end
    
    preprocess_dictionaries(dictionaries) if preprocess and not manual_wordlist
    
    # Empty hash map for cracked accounts
    cracked_accounts = {}
    
    # Create output file
    out_file = File.open(out_file_path, "a")
    
    # Read accounts into memory
    passwd_lines = File.readlines(passwd_path)
    
    # Iterate over each account and throw words at it from user input
    if(manual_wordlist and not parallelize)
        passwd_lines.each_with_index do |entry, index|
            matches = entry =~ /(\w+):((.{2}).*):.*:.*:.*:.*:.*/
            if(matches)
                user = $1
                hash = $2
                unless cracked_accounts[user]
                    puts "(#{index + 1}/#{passwd_lines.size}) Processing user #{user}..."
                    crack_account(user, hash, user_input, cracked_accounts, out_file)
                end
            end
        end
    end
    
    # Parallelize each account and throw words at it from user input
    if(manual_wordlist and parallelize)
        Parallel.each_with_index(passwd_lines) do |entry, index|
            matches = entry =~ /(\w+):((.{2}).*):.*:.*:.*:.*:.*/
            if(matches)
                user = $1
                hash = $2
                unless cracked_accounts[user]
                    puts "(#{index + 1}/#{passwd_lines.size}) Processing user #{user}..."
                    crack_account(user, hash, user_input, cracked_accounts, out_file)
                end
            end
        end
    end
    
    # Iterate over each account and throw dictionaries at it
    if(not manual_wordlist and not parallelize)
        dictionaries.each_with_index do |dict_path, index|
            puts "Using processed #{dict_path} (#{index + 1}/#{dictionaries.size})"
            dict_lines = File.readlines("#{dict_path}_processed")
            dict_lines.each {|line| line.chomp!}
            passwd_lines.each_with_index do |entry, index|
                matches = entry =~ /(\w+):((.{2}).*):.*:.*:.*:.*:.*/
                if(matches)
                    user = $1
                    hash = $2
                    unless cracked_accounts[user]
                        puts "(#{index + 1}/#{passwd_lines.size}) Processing user #{user}..."
                        crack_account(user, hash, dict_lines, cracked_accounts, out_file)
                    end
                end
            end
        end
    end
    
    # Parallelize each account and throw dictionaries at it
    if(not manual_wordlist and parallelize)
        dictionaries.each_with_index do |dict_path, index|
            puts "Using processed #{dict_path} (#{index + 1}/#{dictionaries.size})"
            dict_lines = File.readlines("#{dict_path}_processed")
            dict_lines.each {|line| line.chomp!}
            Parallel.each_with_index(passwd_lines) do |entry, index|
                matches = entry =~ /(\w+):((.{2}).*):.*:.*:.*:.*:.*/
                if(matches)
                    user = $1
                    hash = $2
                    unless cracked_accounts[user]
                        puts "(#{index + 1}/#{passwd_lines.size}) Processing user #{user}..."
                        crack_account(user, hash, dict_lines, cracked_accounts, out_file)
                    end
                end
            end
        end
    end
    
    # Cleanup and stats
    out_file.close()
    print_stats(out_file_path, t)
end
main
    
