# script pour trouver les doubles d'images
# but supprimer les images en doubles dans une librairie Photos
# un paramètre le dossier à scanner / nettoyer

import os
from filecmp import cmp
import sys
import hashlib


def computeHashForFile(filename):
    with open(filename, 'rb') as f:
        sha1 = hashlib.sha1()
        BUF_SIZE = 65536
        while True:
            data = f.read(BUF_SIZE)
            if not data:
                break
            sha1.update(data)
        hash = sha1.hexdigest()
        return hash

for root, dirs, files in os.walk("/Users/jorisdeguet/Downloads/"):
    hashes = {}

    sha1 = hashlib.sha1()
    for file in files:
        try :
            filename = os.path.join(root, file)
            hash = computeHashForFile(filename)
            if (hash in hashes):
                print("==================================================== ")
                print("duplicate found: ", file," ==== ", hashes[hash])
                print("file 1 SHA1 : {0}".format(hash))
                print("file 1 path : "+ file)
                print("file 2 SHA1 : {0}".format(computeHashForFile(hashes[hash])))
                print("file 2 path : " + hashes[hash])
                comparaison = cmp(filename, hashes[hash])
                print(comparaison)
                
            hashes[hash] = filename
        except:
            print("error: ", filename)
print('yo')
