# Change directory to appropriate place for makecert.exe. Install Windows SDK for this.
# For Windows 10: C:\Program Files (x86)\Windows Kits\10\bin\x64\makecert.exe
.\makecert.exe -n "CN=Development Root" -pe -ss Root -sr LocalMachine -sky exchange -m 120 -a sha1 -len 2048 -r
.\makecert.exe -n "CN=servicebus.contoso.com" -pe -ss My -sr LocalMachine -sky exchange -m 120 -in "Development Root" -is Root -ir LocalMachine -a sha256 -eku 1.3.6.1.5.5.7.3.1
.\makecert.exe -n "CN=Development Document Encryption" -pe -ss My -sr LocalMachine -sky exchange -m 120 -in "Development Root" -is Root -ir LocalMachine -a sha256 -eku 1.3.6.1.4.1.311.80.1
