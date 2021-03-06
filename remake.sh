#!/usr/bin/expect 
# Set up various other variables here ($user, $password)

if {[llength $argv] == 0} {
  send_user "\nUsage: scriptname username password\n\n"
  exit 1
}

set prompt "#"
set user [lindex $argv 0]
set password [lindex $argv 1]
set failed_telnet_logfile "failed-telnet.log"

# Skapa en fil för lagring av IP adresser vi inte kan komma in i
set failed_telnets [open ./$failed_telnet_logfile w+]
set failed_ssh [open ./failed-ssh.log w+]
set tracelog [open ./switchexpect.log w+]
set batchlog [open ./batch.log w+]


# This will read and execute all commands from commands.txt
proc run_batch { host } {
  global tracelog prompt batchlog

  if {[file size ./commands.txt] != 0} {
      puts $batchlog "---- $host batchjob ---------------------\n\r"
      send_user "Executing commands for ip $host\n\n"

      set commands [open ./commands.txt r]
      while {[gets $commands cmd] != -1} {
          send "$cmd\r"
          expect $prompt
          puts $batchlog $expect_out(buffer)
      }
      puts $batchlog "-----------------------------------------\n\r"
  }

}



set fp [open hosts.txt r]
while {[gets $fp ip] != -1} {

  # Try to connect
  spawn telnet $ip

  # Handle connection result
  expect {
    -re "Operation timed out|Unable to connect to remote host|Connection refused" {
        puts $failed_telnets $ip
        flush $failed_telnets
    }

    "Password: " {
        send "$password\r"
	expect $prompt
        puts $tracelog "$ip telnet OK"
        run_batch $ip
    }

    -re "Username:|ubnt login:" {
        send "$user\r"

        expect "Password:" {
            send "$password\r"
        }

        expect {
            $prompt {
                run_batch $ip
                send "exit\r"
                #puts $tracelog "$ip telnet command exection done"
            }

            -re "Login incorrect|Login invalid" {
                puts $failed_telnets $ip
                flush $failed_telnets
            }
        }

    }
    timeout {
      puts $failed_telnets $ip
      #puts $tracelog "$ip telnet timeout"
      flush $failed_telnets
    }
  }

}

# Stäng filen vi loopat igenom
close $fp

# Stäng resultatfilen
close $failed_telnets


# Check if the result from telnet tests above logged
# any ip addresses that we need to test with SSH against
if {[file size $failed_telnet_logfile] == 0} {
    #puts $tracelog "Done: No hosts to test with SSH"
    puts "Done: No hosts to test with SSH"
    exit
}

puts "Testar med SSH\r"


# SSH method
set fp [open $failed_telnet_logfile r]
while {[gets $fp ip] != -1} {

  send_user "\rSSH till $ip\r"

  # Try to connect
  spawn -noecho /usr/bin/ssh -o StrictHostKeyChecking=no $user@$ip

  expect {

      "Host is down" {
         puts $tracelog "$ip SSH: Host is down"
      }

      timeout {
        puts $tracelog "$ip SSH: Failed with timeout"
        puts $failed_ssh $ip
        flush $failed_ssh
      }

      $prompt {
         puts $tracelog "$ip SSH Login OK"
         run_batch $ip
         send "exit\r"
      }
  
      -re "Password|password" {
  
        puts "Fick lösenordsfråga\r"
        send "$password\r"
  
         expect {
             $prompt {
                puts $tracelog "$ip SSH Login OK"
                run_batch $ip
                send "exit\r"
             }
             -re "denied|Login incorrect|Connection closed" {
               puts $tracelog "$ip SSH: Failed"
               puts $failed_ssh $ip
               flush $failed_ssh
             }
       
             -re "Password|password" {
               puts "Fick ny lösenordsfråga\r"
               puts $tracelog "$ip SSH: Failed password"
               flush $failed_ssh
             }
            timeout {
               puts $failed_ssh $ip
               puts $tracelog "$ip SSH: Failed with timeout 2"
               flush $failed_ssh
             }
       
         }
  
      }
  
    }

}

# Stäng filen vi loopat igenom
close $fp

# Stäng resultatfilen
close $failed_ssh

# Stäng generella loggfilen
close $tracelog
