# Switchexpect

Call this script with username and passwords as parameters.

## Setup

chmod 0700 switchexpect.sh

## Usage

Om du tycker detta är tradigt:
  ./switchexpect.sh my-user secret-password
  eller
  ./remake.sh my-user secret-password

Gör såhär:

  alias remake='./remake.sh admin test1234'


Nu kan du köra hela klabbet bara genom att skriva "remake" <enter>

## Logfiles

Logfiles are named failed-[ssh|telnet] and the global logfile switchexpect.log

