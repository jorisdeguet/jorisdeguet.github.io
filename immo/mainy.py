from centris import duplex
from centris_maison import maison
from test_twilio import send_sms

newDuplexes = duplex()
newHouses = maison()

newOnes  = newDuplexes + newHouses

text = ""

if len(newOnes) == 0:
    text = "Rien de nouveau aujourd'hui\n"
else:
    chunks = [newOnes[i:i + 10] for i in range(0, len(newOnes), 10)]
    for chunk in chunks:
        url_list = '\n  \n'.join(chunk)
        send_sms(url_list)

