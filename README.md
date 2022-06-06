# Hey there.

This is a script I had to do for a uni course.
It takes a /etc/passwd-like file with simulated data and performs a dictionary attack using the provided word lists.
A single word list can be provided via STDIN:
```
ruby hashcracker.rb < path_to_wordlist
```

Alternatively, multiple word lists can be provided by editing the `dictionaries` array in the script and running without STDIN:
```
ruby hashcracker.rb
```

In this case, it is recommended to pre-process the dictionaries, so that duplicate entries
get "cleaned up". However, pre-processing will also trim down the passwords to max 8 chars since
the simulated data's hash function only considers the initial 8 chars of the password.

Also, since the performance was really bad using a single process, I used Parallel to speed things up.
For the course's sake, I had to allow for setting parallelisation on and off, and single vs multiple
dictionaries could have been handled better, but it does what it's supposed to do.
